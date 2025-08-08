#ifdef BASIC
#define ROM_START $c000
#endif

#define IO_MSB $f4    ; 172000 and up

;		.org 100h


;test
		lxi h,1000h
		lxi b,1234h
		call kvazwriteBC
		lxi h,1002h
		mvi c,56h
		call kvazwriteC
		lxi h,1003h
		mvi c,56h
		call kvazwriteC
		lxi h,1000h
		call kvazreadDE		
		lxi h,1002h
		call kvazreadDE		
		jmp $

kvazreadDEeven:
                mvi a, $fe
                ana l
                mov l, a

;Input: address - HL
;Output: data - DE
kvazreadDE:
                mvi a, IO_MSB
                ana h
                cpi IO_MSB
                jz readregDE
                push h
		  xchg			;DE=address
		  lxi h,0
		  dad sp			;HL=old SP
		  mvi a,kvazbank
		  di
		  out kvazport
		  xchg			;HL=address, DE=old SP
		  sphl			;SP=address
		  xchg			;HL=old SP
		  pop d			;DE=data
		  xra a
		  out kvazport
		  sphl			;SP=old SP
		  ei
                pop h
		ret

kvazreadBCeven:
                mvi a, $fe
                ana l
                mov l, a

;Input: address - HL
;Output: data - BC
; clobbers DE!!!
kvazreadBC:
                mvi a, IO_MSB
                ana h
                cpi IO_MSB
                jz readregDE

                ;push d
                  push h
                    xchg                    ;DE=address
                    lxi h,0
                    dad sp                  ;HL=old SP
                    mvi a,kvazbank
                    di
                    out kvazport
                    xchg                    ;HL=address, DE=old SP
                    sphl                    ;SP=address
                    xchg                    ;HL=old SP
                    pop b                   ;BC=data
                    pop d   ; read-ahead
                    xra a
                    out kvazport
                    sphl                    ;SP=old SP
                    ei
                  pop h
                ;pop d
                ret



#if 0
kvazinsnfetch:
          lhld r7               ; 20 + 12 + 8 + 4 + 12 + 8 + 8 + 4 + 12 = 88
          lxi d, prefetched_addr
          ldax d
          cmp l
          jnz prefetch_miss
          inx d
          ldax d
          cmp h
          jnz prefetch_miss

          ; hit
          inx h \ inx h
          shld r7
          lhld prefetched_word
          ret

prefetch_miss:
          xchg
          lxi h,0
          di
          dad sp
          mvi a,kvazbank
          out kvazport
          xchg
          sphl
          xchg
          pop d
          pop b   ; read-ahead
          xra a
          out kvazport
          sphl
          ei
        mov h, b
        mov l, c
        shld prefetched_word      ; 8 + 8 + 20; lxi \ mov \ inx \ mov  = 12 + 8 + 8 + 8

        lhld r7
        inx h \ inx h 
        shld r7
        shld prefetched_addr
        xchg   ; hl = opcode
        ret

prefetched_word:  .dw 0
prefetched_addr:  .dw 1
#endif


;kvazwriteDEeven:
;                mvi a, $fe
;                ana l
;                mov l, a
;                ; [hl] <- de
;kvazwriteDE:
;                ;push b
;                mov b, d
;                mov c, e
;                call kvazwriteBC
;                ;pop b
;                ;ret

kvazwriteDEeven:
                mov b, d
                mov c, e
kvazwriteBCeven:                  ; 8 + 4 + 8 + 8 + 4 + 12 = 
                mvi a, $fe
                ana l
                mov l, a
;Input: address - HL, data - BC
kvazwriteBC:
                mvi a, IO_MSB
                ana h
                cpi IO_MSB
                jz writeregBC
#ifdef ROM_START
                mvi a, (ROM_START >> 8) - 1
                cmp h
                jc jmp_trap
#endif
                push h
                  push d
		    xchg			;DE=address
		    lxi h,0
		    dad sp			;HL=old SP
		    mvi a,kvazbank
		    di
		    out kvazport
		    xchg			;HL=address, DE=old SP
		    sphl			;SP=address
		    xchg			;HL=old SP
		    inx sp
		    inx sp			;SP=address+2
		    push b
		    xra a
		    out kvazport
		    sphl			;SP=old SP
		    ei
                  pop d
                pop h
		ret
                

;Input: address - HL, data - C
kvazwriteC:
                inr h
                jz writeregC
                dcr h
                push d
                  push h
		    xchg			;DE=address
		    lxi h,0
		    dad sp			;HL=old SP
		    mvi a,kvazbank
		    di
		    out kvazport
		    xchg			;HL=address, DE=old SP
		    sphl			;SP=address
		    xchg			;HL=old SP
		    mov a,c
		    pop b
		    mov c,a
		    push b
		    xra a
		    out kvazport
		    sphl			;SP=old SP
		    ei
                  pop h
                pop d
		ret

                ; [hl] <- e
kvazwriteE:
                push b
                mov c, e
                call kvazwriteC
                pop b
                ret

readregDE:
                push h
                push b
                lxi b, _readregDE_return
                push b

                mov a, l
                cpi 164q  ; 177564 tx control
                jz read_tx_control
                cpi 160q  ; 177560 rx control
                jz read_rx_control
                cpi 162q   ; 177562 rx data
                jz read_rx_data

                cpi 177170q & 377q  ; RX_CSR    RX floppy status reg
                jz read_rxdrv_csr
                cpi 177172q & 377q  ; RX_DATA   RX floppy data reg
                jz read_rxdrv_data

                cpi 376q   ; pdp-11 PS
                jz read_ps177776

                jmp jmp_trap  ; nonexistent reg
_readregDE_return:
                pop b
                pop h
                ret

writeregBC:
writeregC:
                push h
                push d

                lxi d, writereg_return
                push d

                mov a, l
                cpi 166q   ; 177566 tx data
                jz write_tx_data
                cpi 164q   ; 177564 tx control
                jz write_tx_control
                cpi 160q   ; 177560 rx control
                jz write_rx_control

                cpi 177170q & 377q  ; RX_CSR    RX floppy status reg
                jz write_rxdrv_csr
                cpi 177172q & 377q  ; RX_DATA   RX floppy data reg
                jz write_rxdrv_data
                
                cpi 376q   ; pdp-11 PS
                jz write_ps177776
                ; rx? dunno

                jmp jmp_trap

writereg_return:
                pop d
                pop h
                ret

tx_control_reg: .db 0         ; 177564
tx_data_reg:    .db 0         ; 177566
rx_control_reg: .db 0         ; 177560 
rx_data_reg:    .db 0         ; 177562

RCSR_INTE       .equ 0100q  ; transmit interrupt enable, XCSR 177564, vector 64
RCSR_DONE       .equ 0200q  ; means there's a byte to pick

RCSR_VEC        .equ 000060q

rcsr_init:      lxi h, rx_control_reg
                mvi m, 0
                jmp _rcsr_clr_int

xcsr_init:      lxi h, tx_control_reg
                mvi m, 0
                jmp _xcsr_clr_int

write_rx_control:
                mvi a, RCSR_INTE
                ana c
                mov c, a
                lxi h, rx_control_reg
                mvi a, ~RCSR_INTE
                ana m
                ora c
                mov m, a              ; set RCSR_INTE 

                ; if enabled and has stuff in buffer, raise int

_rcsr_check:
                mvi c, $b ; C_STAT console status
                call 5
                lxi d, 0
                ora a
                jnz _rcsr_has         ; something in the buffer
                ret
_rcsr_has:      mvi a, RCSR_DONE      ; set DONE flag (indicating something)
                lxi h, rx_control_reg
                ora m
                mov m, a
                mvi a, RCSR_INTE
                ana m
                jnz _rcsr_set_int     ; interrupt enabled?
_rcsr_clr_int:
                lxi h, intflg_io
                mvi a, ~IORQ_RCSR
                ana m
                mov m, a
                ret
_rcsr_set_int:                        ; set rcsr interrupt
                lxi h, intflg
                mvi a, RQ_IORQ
                ora m
                mov m, a
                inx h
                mvi a, IORQ_RCSR
                ora m
                mov m, a
                ret


read_tx_control:
                mvi e, 200q
                mvi d, 0
                ret

read_rx_control:
                lxi d, 0
                lda rx_control_reg
                ora a
                mov e, a
                rm        ; char awaits

                call _rcsr_check
                lxi h, rx_control_reg
                mov e, m
                mvi d, 0
                ret

                ;push h
                ;mvi c, $b ; C_STAT console status
                ;call 5
                ;lxi d, 0
                ;ora a
                ;pop h
                ;rz
                ;mvi a, $80
                ;sta rx_control_reg
                ;
                ;; read the char
                ;; mvi c, 1 -- this is with echo, sux
                ;; call 5
                ;; sta rx_data_reg
                ;push h
                ;mvi c, 6 ; raw console i/o
                ;mvi e, $ff
                ;call 5
                ;sta rx_data_reg

                ;mvi e, $80
                ;pop h
                ;ret
read_rx_data:
                ;push h
                ;lxi h, rx_data_reg
                ;mov e, m
                ;dcx h
                ;mvi m, 0
                ;mvi d, 0
                ;pop h
                mvi c, 6 ; raw console i/o
                mvi e, $ff
                call 5
                mov e, a
                mvi d, 0
                ret
write_tx_data:
  ;;;;;
  ;hlt ; for benchmark: 
  ;;;;;                   basic 
  ;;;;; 10 FORI=1TO1000:NEXTI
  ;;;;; 20 PRINT"KU!"                 -> 06:46, DVK in b2m emu baseline: 0:4.50
  ;;;;;                   7392755
  ;;;;;                   7368509 lhld vm1 opcode in mov
  ;;;;;                   7368367 fixed movb setaluf, lhldified too
  ;;;;;                   7368331     -> 06:41        ~ 89.1 x slower
  ;;;;;                   7356193 jnc check in write
  ;;;;;                   7343641 mov/movb branchy setaluf
  ;;;;;                   ---     ror/rol/asl/asr -- 06:34
  ;;;;;                   ---     less push around load_dd16, ~ 06:34 
                mov a, c
                sta tx_data_reg
                sta txstrbuf
                mvi c, 9
                lxi d, txstrbuf
                jmp 5
txstrbuf:       .db 0, '$'

XCSR_INTE       .equ 0100q  ; transmit interrupt enable, XCSR 177564, vector 64
XCSR_VEC        .equ 000064q


console_poll:   
                lxi h, tx_control_reg
                mvi a, XCSR_INTE
                ana m
                rz
                jmp _xcsr_set_int

write_tx_control:
                ; 
                mvi a, XCSR_INTE
                ana c
                mov c, a
                lxi h, tx_control_reg
                mvi a, ~XCSR_INTE
                ana m
                ora c
                mov m, a
                
                mvi a, XCSR_INTE
                ana m
                jnz _xcsr_set_int
_xcsr_clr_int:
                lxi h, intflg_io
                mvi a, ~IORQ_XCSR
                ana m
                mov m, a
                ret
_xcsr_set_int:
                lxi h, intflg
                mvi a, RQ_IORQ
                ora m
                mov m, a
                inx h
                mvi a, IORQ_XCSR
                ora m
                mov m, a
                ret

write_ps177776:
                mov d, b
                mov e, c
                jmp _mtps_de

read_ps177776:
                ; same as mfps but without jump to store_dd8
                lda rpsw
                mov e, a
                mvi d, 0
                ret
		.end
