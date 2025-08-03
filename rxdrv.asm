; RX floppy disk 

SECTOR_SIZE         .equ 128
SECTORS_PER_TRACK   .equ 26
TRACKS              .equ 77
RX_DISK_SIZE        .equ SECTOR_SIZE * SECTORS_PER_TRACK * TRACKS

; https://gunkies.org/wiki/RX11_floppy_disk_controller

; RX11 status flags
#define RX_DONE     $0020
#define RX_ERROR    $8000
#define RX_INIT     $4000
#define RX_GO       $0001

; RX11 commands (top 3 bits of CSR)
#define CMD_FILL    000q
#define CMD_EMPTY   001q
#define CMD_WRITE   002q
#define CMD_READ    003q
#define CMD_STAT    005q
#define CMD_WRDEL   006q
#define CMD_RDERR   007q


rxdrv_mount:
        lxi b, imgname
        call open_fcb1
        sta rxdrv_mounted  ; 0 = not mounted
        ret

rxdrv_dismount:
        lxi h, rxdrv_mounted
        xra a
        ora m
        rz
        mvi m, 0
        jmp close_fcb1


write_rxdrv_csr:
        ; rxdrv_cmd = (value >> 1) & 7
        xra a
        ora c
        rar
        sta rxdrv_cmd
        xra a
        sta rxdrv_param_stage
        ; if (value & GO) start_command()
        mvi a, RX_GO
        ana c
        sta rxdrv_go
        jnz rxdrv_start_command
        ret

        ; data in BC
write_rxdrv_data:
        ; receive param
        lda rxdrv_cmd
        cpi CMD_READ
        rnz 

        ; READ gets 3 params in sequence: track, sector, (drive?)
        lxi h, rxdrv_param_stage
        mov a, m
        inr m
        ora a \ jz _rxdrv_set_sector  ; case 0: sector
        dcr a \ jz _rxdrv_set_track   ; case 1: track
        ret

read_rxdrv_csr:
        lhld rxdrv_csr
        xchg
        ret

read_rxdrv_data:
        ret

_rxdrv_set_track:
        lxi h, rxdrv_track
        mov m, c
        lda rxdrv_go
        ora a
        jnz _rxdrv_read_sector
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

        ;lxi h, rxdrv_param_stage
        ;mvi m, 0

        lda rxdrv_cmd
        cpi CMD_INIT
        jz _rxdrv_cmd_init

        cpi CMD_READ
        rz  ; expect paramsies

        cpi CMD_EMPTY
        jz _rxdrv_cmd_empty

        cpi CMD_WRITE
        jz _rxdrv_cmd_write

        cpi CMD_FILL
        jz _rxdrv_cmd_fill

_rxdrv_seterr:
        lxi h, RX_ERROR | RX_DONE
        shld rxdrv_csr
        ret


_rxdrv_cmd_init:
        lxi h, rxdrv_csr
        mvi a, RX_DONE
        ora m
        mov m, a
        ret
_rxdrv_cmd_empty:
        lxi h, rxdrv_buffer_index
        mvi m, 0
        ret
_rxdrv_cmd_write:
_rxdrv_cmd_fill:
        lxi h, rxdrv_csr
        mvi a, RX_DONE
        ora m
        mov m, a
        ret

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
        mov e, a
        mvi d, 0
        dad d       ; sector number = cp/m record number
        ; extent = hl/128, record = hl % 128
        mov d, h
        mov e, l

        ; dad h     ; h = hl/128, extent
        ; mov a, h
        ; sta fcb1+$0c    ; extent
        ; mvi a, $7f
        ; ana e           ; record num % 128
        ; sta fcb1+$20    ; record

        shld fcb1+33
         
        lxi d, fcb1
        mvi c, F_READRAND
        call BDOS
        ora a
        jnz _rxdrv_seterr
        ret
        

rxdrv_csr           .dw 0
rxdrv_cmd           .db 0
rxdrv_track:        .db 0
rxdrv_sector:       .db 0
;rxdrv_drive:        .db 0

rxdrv_go:           .db 0
rxdrv_buffer_index: .db 0
rxdrv_param_stage:  .db 0
rxdrv_mounted:      .db 0      ; 0 = not mounted


imgname:    .db "RT11SJ01DSK", 0
