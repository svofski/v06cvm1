; RX floppy disk 

; print info about register writes
; #define HYPERDEBUG

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

; RX11 commands (top 3 bits of CSR)
#define CMD_FILL    000q
#define CMD_EMPTY   001q
#define CMD_WRITE   002q
#define CMD_READ    003q
#define CMD_STAT    005q
#define CMD_WRDEL   006q
#define CMD_RDERR   007q


rxdrv_mount:
        lxi h, rxdrv_csr
        mvi a, ~RX_DONE
        ana m
        mov m, a

        lxi b, imgname
        call open_fcb1
        sta rxdrv_mounted  ; 0 = not mounted
        ora a
        rz

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
        ; update INTE flag in CSR
        lxi h, rxdrv_csr
        mvi a, ~RX_INTE
        ana m
        mov m, a
        mvi a, RX_INTE
        ana c
        ora m
        mov m, a
        ; rxdrv_cmd = (value >> 1) & 7
        xra a
        ora c
        rar
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
        dcr a \ jz _rxdrv_set_track   ; case 1: track
        ret

_rxdrv_wr_cmd_write:
        ; WRITE params: sector, track
        lxi h, rxdrv_param_stage
        mov a, m
        inr m
        ora a \ jz _rxdrv_set_sector
        dcr a \ jz _rxdrv_set_track
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

_rxdrv_read_sector:
        lda rxdrv_mounted
        ora a
        jz _rxdrv_seterr
        
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
        mov d, h
        mov e, l

        ; a decent FCB reference: http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch5.htm#Table_5-2
        shld fcb1+33  ; random access record for F_READRAND
         
        lxi d, fcb1
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

        jmp _rxdrv_set_done

rxdrv_csr:          .dw 0
rxdrv_cmd:          .db 0
rxdrv_track:        .db 0
rxdrv_sector:       .db 0
;rxdrv_drive:        .db 0

rxdrv_go:           .db 0
rxdrv_bufofs:       .db 0       ; sector buffer read offset during EMPTY
rxdrv_param_stage:  .db 0
rxdrv_mounted:      .db 0       ; 0 = not mounted

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
        



;imgname:    .db "RT11SJ01DSK", 0
;imgname:    .db "STALK   DSK", 0
imgname:    .db RXIMAGE, 0
