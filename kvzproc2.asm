#define ROM_START $c000

;		.org 100h

#define kvazbank 10h
#define kvazport 10h

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
                inr h
                jz readregDE
                dcr h
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
                ;inr h
                ;jz readregDE
                ;dcr h
                mvi a, $ff
                cmp h
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
                    xra a
                    out kvazport
                    sphl                    ;SP=old SP
                    ei
                  pop h
                ;pop d
                ret

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
                mov a, h        ; 8 + 8 + 12 + 8 + 12    vs 8 + 4 + 12 + 8 + 4 + 12
                cpi $ff
                jz writeregBC
                cpi (ROM_START >> 8)
                jnc jmp_trap
                ;mvi a, $ff
                ;cmp h
                ;jz writeregBC
                ;mvi a, (ROM_START >> 8) - 1
                ;cmp h
                ;jc jmp_trap

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
                dcr h        ; restore hl!
                mvi a, 164q  ; 177564 tx control
                cmp l
                jz read_tx_control
                mvi a, 160q  ; 177560 rx control
                cmp l
                jz read_rx_control
                mvi a, 162q   ; 177562 rx data
                cmp l
                jz read_rx_data

                mvi a, 376q   ; pdp-11 PS
                cmp l
                jz read_ps177776

                jmp jmp_trap  ; nonexistent reg
writeregBC:
writeregC:
                mvi a, 166q   ; 177566 tx data
                cmp l
                jz write_tx_data
                mvi a, 164q   ; 177564 tx control
                cmp l
                jz write_tx_control
                mvi a, 160q   ; 177560 rx control
                cmp l
                jz write_rx_control
                
                mvi a, 376q   ; pdp-11 PS
                cmp l
                jz write_ps177776
                ; rx? dunno

                jmp jmp_trap

tx_control_reg: .db 0         ; 177564
tx_data_reg:    .db 0         ; 177566
rx_control_reg: .db 0         ; 177560 
rx_data_reg:    .db 0         ; 177562

read_tx_control:
                ;lda tx_control_reg
                ;mov e, a
                mvi e, 200q
                mvi d, 0
                ret
read_rx_control:
                lxi d, 0
                lda rx_control_reg
                ora a
                mov e, a
                rm        ; char awaits

                push h
                mvi c, $b ; C_STAT console status
                call 5
                lxi d, 0
                ora a
                pop h
                rz
                mvi a, $80
                sta rx_control_reg
                
                ; read the char
                ; mvi c, 1 -- this is with echo, sux
                ; call 5
                ; sta rx_data_reg
                push h
                mvi c, 6 ; raw console i/o
                mvi e, $ff
                call 5
                sta rx_data_reg

                mvi e, $80
                pop h

                ret
read_rx_data:
                push h
                lxi h, rx_data_reg
                mov e, m
                dcx h
                mvi m, 0
                mvi d, 0
                pop h
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
                mov a, c
                sta tx_data_reg
                sta txstrbuf
                mvi c, 9
                lxi d, txstrbuf
                jmp 5
txstrbuf:       .db 0, '$'
write_tx_control:
                mov a, c
                sta tx_control_reg
                ret
write_rx_control:
                mov a, e
                sta rx_control_reg
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
