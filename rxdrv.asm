; RX floppy disk 

; print info about register writes
;#define HYPERDEBUG

SECTOR_SIZE         .equ 128
SECTORS_PER_TRACK   .equ 26
TRACKS              .equ 77
RX_DISK_SIZE        .equ SECTOR_SIZE * SECTORS_PER_TRACK * TRACKS

; https://gunkies.org/wiki/RX11_floppy_disk_controller

; RX11 status flags
#define RX_DONE     $0020
#define RX_ERROR    $8000
#define RX_INIT     $4000   ;; init command
#define RX_GO       $0001
#define RX_TXRQ     $0080   ;; transfer request
#define RX_INTE     $0040   ;; interrupt enable
#define RX_UNIT     $0010   ;; 0 = unit 0, 1 = unit 1 (write-only)

; RX11 commands (top 3 bits of CSR)
#define CMD_FILL    000q    ;; ignores UNITSEL
#define CMD_EMPTY   001q    ;; ignores UNITSEL
#define CMD_WRITE   002q    ;; write sector(UNITSEL)
#define CMD_READ    003q    ;; read sector(UNITSEL)
#define CMD_STAT    005q
#define CMD_WRDEL   006q
#define CMD_RDERR   007q


rxdrv_mount:
        ; copy provisional fcb2 to the real fcb2
        lxi b, 16
        lxi h, fcb2x
        lxi d, fcb2
        call memcpy

        lda fcb1+1
        cpi ' '               ; command line specifies a file?
        jz _rxdrv_m_default   ; no, use the default from imgname
        call open_prepd_fcb1  ; yes, open fcb1 in place
        jmp _rxdrv_m_1opened
_rxdrv_m_default
        lxi b, imgname
        call open_fcb1
_rxdrv_m_1opened:
        sta rxdrv_mounted  ; 0 = not mounted
        ; display file/status
        lxi h, fcb1
        mvi b, 0           ; unit 0
        call print_fcb

        ; second file
        lda fcb2+1
        cpi ' '
        jz _rxdrv_m_no2

        call open_prepd_fcb2
        sta rxdrv_mounted2
        ; display file/status
        lxi h, fcb2
        mvi b, 1          ; unit 1
        call print_fcb

_rxdrv_m_no2:
        lxi h, rxdrv_csr
        mvi a, RX_DONE
        ora m
        mov m, a
        ret

rxdrv_dismount:
        lxi h, rxdrv_mounted
        xra a
        ora m
        rz
        mvi m, 0
        jmp close_fcb1

write_rxdrv_csr:
#ifdef HYPERDEBUG
        ;;----------------------------------
        push h
        push d
        push b
        mov h, b
        mov l, c
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        CALL_BDOS
        call putsi \ .db "->rxdrv_csr", 13, 10, '$'
        pop b
        pop d
        pop h
        ;--------------------------------- 
#endif      
        mvi a, RX_INIT >> 8
        ana b
        jnz _rxdrv_init
        ; update INTE and UNIT in CSR
        lxi h, rxdrv_csr
        mvi a, ~(RX_INTE | RX_UNIT)
        ana m
        mov m, a
        mvi a, RX_INTE | RX_UNIT
        ana c
        ora m
        mov m, a
        ; clear error
        inx h
        mvi m, 0
        dcx h

        ; rxdrv_cmd = (value >> 1) & 7
        xra a
        ora c
        rar
        ani 7
        sta rxdrv_cmd
        xra a
        sta rxdrv_param_stage
        ; if (value & GO) start_command() -- but what if not GO?
        mvi a, RX_GO
        ana c
        sta rxdrv_go
        cnz rxdrv_start_command

        ; clear interrupt if not INTE, set interrupt if INTE and DONE
        lxi h, rxdrv_csr
        mvi a, RX_INTE
        ana m
        jz  _rxdrv_clr_int
        mvi a, RX_DONE
        ana m
        jnz _rxdrv_set_int
        ret

        ; data in BC
write_rxdrv_data:
#ifdef HYPERDEBUG
        ;;----------------------------------
        push h
        push d
        push b
        lda rxdrv_cmd
        mov h, a
        mov l, c
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        CALL_BDOS
        call putsi \ .db "->rxdrv_data", 13, 10, '$'
        pop b
        pop d
        pop h
        ;--------------------------------- 
#endif      
        ; receive param
        lda rxdrv_cmd
        cpi CMD_READ
        jz _rxdrv_wr_cmd_read
        cpi CMD_FILL
        jz _rxdrv_wr_cmd_fill
        cpi CMD_WRITE
        jz _rxdrv_wr_cmd_write
        ret

_rxdrv_wr_cmd_read:
        ; READ params: sector, track
        lxi h, rxdrv_param_stage
        mov a, m
        inr m
        ora a \ jz _rxdrv_set_sector  ; case 0: sector
        dcr a \ jz _rxdrv_set_track   ; case 1: track and -> _rxdrv_read_sector
        ret

_rxdrv_wr_cmd_write:
        ; WRITE params: sector, track
        lxi h, rxdrv_param_stage
        mov a, m
        inr m
        ora a \ jz _rxdrv_set_sector   ; sector
        dcr a \ jz _rxdrv_set_track_wr ; track and -> _rxdrv_write_sector
        ret
        

        ; dma[rxdrv_bufofs] = c
_rxdrv_wr_cmd_fill:
#ifdef HYPERDEBUG
        ;;----------------------------------
        push h
        push d
        push b
        lda rxdrv_bufofs
        mov l, a
        mov h, c
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        CALL_BDOS
        call putsi \ .db "->wr_cmd_fill", 13, 10, '$'
        pop b
        pop d
        pop h
        ;--------------------------------- 
#endif      
        lxi h, rxdrv_bufofs
        xra a
        ora m
        rm        ; shouldn't happen but just in case
        
        mov e, m
        mvi d, 0
        inr m         ; buf_ofs += 1, S flag = 1 when buf_ofs == 0x80
        push psw      ; remember S bit
          lxi h, dma
          dad d       ; dma + buf_ofs
          mov m, c    ; write byte to buffer
        pop psw
        jm _rxdrv_clear_txrq ; clear TXRQ and set DONE
        ret

read_rxdrv_csr:
        lhld rxdrv_csr
        xchg
        ret

read_rxdrv_data:
        lxi h, rxdrv_bufofs
        xra a
        ora m
        jm _rxdrv_nodata
        inr m
        push psw
          mov l, a
          mvi h, 0
          lxi d, dma
          dad d
          mov e, m
          mvi d, 0
        pop psw
        jm _rxdrv_clear_txrq ; last byte served (128)
        ret

_rxdrv_clear_txrq:
        lxi h, rxdrv_csr
        mvi a, ~RX_TXRQ
        ana m
        ori RX_DONE
        mov m, a
        ret

_rxdrv_nodata:
        lxi d, 0
        ret

_rxdrv_set_track:
        lxi h, rxdrv_track
        mov m, c
        lda rxdrv_go
        ora a
        jnz _rxdrv_read_sector
        ret

_rxdrv_set_track_wr:
        lxi h, rxdrv_track
        mov m, c
        lda rxdrv_go
        ora a
        jnz _rxdrv_write_sector
        ret

_rxdrv_set_sector:
        lxi h, rxdrv_sector
        mov m, c
        ret

rxdrv_start_command:
        lxi h, rxdrv_csr
        mvi a, ~RX_DONE
        ana m
        mov m, a

        lda rxdrv_cmd
        cpi CMD_READ
        jz _rxdrv_set_txreq     ; expect sector, track: set Transfer request
        cpi CMD_WRITE
        jz _rxdrv_set_txreq     ; expect sector, track

        cpi CMD_EMPTY
        jz _rxdrv_cmd_empty


        cpi CMD_FILL
        jz _rxdrv_cmd_fill    ; fill i/o buffer
        ; ?
        ret


rxdrv_init:
_rxdrv_init:
        call _rxdrv_clr_int
        xra a
        sta rxdrv_cmd
        sta rxdrv_track
        sta rxdrv_sector
        sta rxdrv_go
        sta rxdrv_bufofs
        sta rxdrv_param_stage

        lxi h, RX_DONE
        shld rxdrv_csr
        ret

_rxdrv_clr_int:
        lxi h, intflg_io
        mvi a, ~IORQ_RX
        ana m
        mov m, a
        ret

_rxdrv_set_int:
        lxi h, intflg
        mvi a, RQ_IORQ
        ora m
        mov m, a
        lxi h, intflg_io
        mvi a, IORQ_RX
        ora m
        mov m, a
        ret


_rxdrv_seterr:
        lxi h, rxdrv_csr + 1
        mvi a, RX_ERROR>>8
        ora m
        mov m, a
        jmp _rxdrv_set_done

_rxdrv_cmd_empty:
        lxi h, rxdrv_bufofs
        mvi m, 0
_rxdrv_set_txreq:
        lxi h, rxdrv_csr
        mvi a, RX_TXRQ
        ora m
        mov m, a
        ret

_rxdrv_set_done:
        lxi h, rxdrv_csr
        mvi a, RX_DONE
        ora m
        mov m, a
        mvi a, RX_INTE ; interrupt enabled?
        ana m
        rz
        jmp _rxdrv_set_int

_rxdrv_cmd_fill:
#ifdef HYPERDEBUG
        ;;----------------------------------
        push h
        push d
        push b
        lda rxdrv_track
        mov h, a
        lda rxdrv_sector
        mov l, a
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        CALL_BDOS
        call putsi \ .db "->rxdrv_cmd_fill", 13, 10, '$'
        pop b
        pop d
        pop h
        ;--------------------------------- 
#endif      
        jmp _rxdrv_cmd_empty   ; same idea

        ;lxi h, rxdrv_bufofs
        ;mvi m, 0              ; reset buffer offset
        ;lxi h, rxdrv_csr
        ;mvi a, RX_TXRQ
        ;ora m
        ;mov m, a              ; set TX bit
        ;ret

_rxdrv_check_mounted:
        lda rxdrv_csr
        ani RX_UNIT
        jz _rxdrv_cm_0
        lda rxdrv_mounted2
        ora a
        ret
_rxdrv_cm_0:
        lda rxdrv_mounted
        ora a
        ret

_rxdrv_read_sector:
        call _rxdrv_check_mounted
        jz _rxdrv_seterr

        call _rxdrv_comp_randrec
        
        ; select unit
        lda rxdrv_csr
        ani RX_UNIT
        jnz _rxdrv_rs_u1
_rxdrv_rs_u0:
        ; a decent FCB reference: http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm#Table_5-2
        shld fcb1+33  ; random access record for F_READRAND
        lxi d, fcb1
        jmp _rxdrv_rs_rrand
_rxdrv_rs_u1:
        shld fcb2+33  ; random access record for F_READRAND
        lxi d, fcb2
_rxdrv_rs_rrand:
        mvi c, F_READRAND
        CALL_BDOS
        ora a
        jnz _rxdrv_seterr

        jmp _rxdrv_set_done

_rxdrv_write_sector:
#ifdef HYPERDEBUG
        ;;----------------------------------
        push h
        push d
        push b
        lda rxdrv_track
        mov h, a
        lda rxdrv_sector
        mov l, a
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        CALL_BDOS
        call putsi \ .db "->rxdrv_write_sector", 13, 10, '$'
        pop b
        pop d
        pop h
        ;--------------------------------- 
#endif      

        call _rxdrv_check_mounted
        jz _rxdrv_seterr
        call _rxdrv_comp_randrec

        ; select unit
        lda rxdrv_csr
        ani RX_UNIT
        jnz _rxdrv_ws_u1
_rxdrv_ws_u0:
        ; a decent FCB reference: http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm#Table_5-2
        shld fcb1+33  ; random access record for F_READRAND
        lxi d, fcb1
        jmp _rxdrv_ws_rrand
_rxdrv_ws_u1:
        shld fcb2+33  ; random access record for F_READRAND
        lxi d, fcb2
_rxdrv_ws_rrand:
        mvi c, F_WRITERAND
        CALL_BDOS
        ora a
        jnz _rxdrv_seterr
        jmp _rxdrv_set_done

_rxdrv_comp_randrec:
        ; compute offset into dsk image 
        ; (rxdrv_track * SECTORS_PER_TRACK + rxdrv_sector) * SECTOR_SIZE
        ;  max 2002                                        * 128 -> 256256
        lda rxdrv_track
        lxi d, SECTORS_PER_TRACK
        call MulAHL_A_DE  ; ahl <- a * de
        lda rxdrv_sector
        dcr a ; track numbers start with 1
        mov e, a
        mvi d, 0
        dad d       ; sector number = cp/m record number
        ; extent = hl/128, record = hl % 128
        ;mov d, h
        ;mov e, l
        ret

rxdrv_csr:          .dw 0
rxdrv_cmd:          .db 0
rxdrv_track:        .db 0
rxdrv_sector:       .db 0
;rxdrv_drive:        .db 0

rxdrv_go:           .db 0
rxdrv_bufofs:       .db 0       ; sector buffer read offset during EMPTY
rxdrv_param_stage:  .db 0
rxdrv_mounted:      .db 0       ; 0 = not mounted
rxdrv_mounted2:     .db 0       ; 0 = not mounted
#define BOOT_START      02000q
#define BOOT_ENTRY      (BOOT_START + 002q)
#define BOOT_UNIT       (BOOT_START + 010q)
#define BOOT_CSR        (BOOT_START + 026q)
#define BOOT_LEN_W      ((boot_rom_end - boot_rom) / 2)

boot_rom:
        .dw 0042130q,                        ; "XD" 
        .dw 0012706q, BOOT_START,            ; MOV #boot_start, SP 
        .dw 0012700q, 0000000q,              ; MOV #unit, R0        ; unit number 
        .dw 0010003q,                        ; MOV R0, R3 
        .dw 0006303q,                        ; ASL R3 
        .dw 0006303q,                        ; ASL R3 
        .dw 0006303q,                        ; ASL R3 
        .dw 0006303q,                        ; ASL R3 
        .dw 0012701q, 0177170q,              ; MOV #RXCS, R1        ; csr 
        .dw 0032711q, 0000040q,              ; BITB #40, (R1)       ; ready? 
        .dw 0001775q,                        ; BEQ .-4 
        .dw 0052703q, 0000007q,              ; BIS #READ+GO, R3 
        .dw 0010311q,                        ; MOV R3, (R1)         ; read & go 
        .dw 0105711q,                        ; TSTB (R1)            ; xfr ready? 
        .dw 0100376q,                        ; BPL .-2 
        .dw 0012761q, 0000001q, 0000002q,    ; MOV #1, 2(R1)        ; sector 
        .dw 0105711q,                        ; TSTB (R1)            ; xfr ready? 
        .dw 0100376q,                        ; BPL .-2 
        .dw 0012761q, 0000001q, 0000002q,    ; MOV #1, 2(R1)        ; track 
        .dw 0005003q,                        ; CLR R3 
        .dw 0032711q, 0000040q,              ; BITB #40, (R1)       ; ready? 
        .dw 0001775q,                        ; BEQ .-4 
        .dw 0012711q, 0000003q,              ; MOV #EMPTY+GO, (R1)  ; empty & go 
        .dw 0105711q,                        ; TSTB (R1)            ; xfr, done? 
        .dw 0001776q,                        ; BEQ .-2 
        .dw 0100003q,                        ; BPL .+010 
        .dw 0116123q, 0000002q,              ; MOVB 2(R1), (R3)+    ; move byte 
        .dw 0000772q,                        ; BR .-012 
        .dw 0005002q,                        ; CLR R2 
        .dw 0005003q,                        ; CLR R3 
        .dw 0012704q, BOOT_START+020q,       ; MOV #START+20, R4 
        .dw 0005005q,                        ; CLR R5 
        .dw 0005007q                         ; CLR R7 
boot_rom_end:

        ; copy bootstrap to 02000 and jmp to 02002
rxdrv_load_boot:
        lxi h, boot_rom       ; copy from
        lxi d, BOOT_START     ; guest addr, boot at 02000
        mvi a, BOOT_LEN_W
_rxdrv_1:
        push psw
          mov c, m \ inx h \ mov b, m \ inx h
          xchg
          STORE_BC_TO_HL
          xchg
          inx d \ inx d
        pop psw
        dcr a
        jnz _rxdrv_1

        lxi h, BOOT_ENTRY
        shld r7
        ret
        
        ; b = unit no
        ; hl = fcb
print_fcb:
        ; unit number
        mvi a, '0'
        add b
        sta _pfcb_buf + 2
        mov a, m  ; drive no
        adi 'A'
        sta _pfcb_buf + 4 ; drive letter

        ; copy name
        inx h
        lxi d, _pfcb_buf + 6
        mvi c, 8
        call _pfcb_ncpy
_pfcb_nc2:
        mvi a, '.'
        stax d \ inx d
        ; copy ext
_pfcb_nc4:
        mvi c, 3
        call _pfcb_ncpy

        xchg
        mvi m, 13 \ inx h
        mvi m, 10 \ inx h
        mvi m, '$' \ inx h

        mvi c, C_WRITESTR
        lxi d, _pfcb_buf
        JMP_BDOS


_pfcb_ncpy:
        mov a, m
        cpi ' '
        jz _pfcb_ncpy_x
        inx h
        stax d
        inx d
        dcr c
        jnz _pfcb_ncpy
        ; skip remainder of input
_pfcb_ncpy_x:
        xra a
        ora c
        rz
_pfcb_ncpy_y:        
        inx h
        dcr c
        jnz _pfcb_ncpy_y
        ret

_pfcb_buf:
        .db "RX0=X:XXXXXXXX.XXX", 13, 10, "$"




;imgname:    .db "RT11SJ01DSK", 0
;imgname:    .db "STALK   DSK", 0
imgname:    .db RXIMAGE, 0
