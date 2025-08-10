BDOS    .equ 5
fcb1    .equ $5c
intv    .equ 38h
dma     .equ $80

        ; BDOS functions
C_WRITE         .equ 2
C_WRITESTR      .equ 9        
F_OPEN          .equ 15          ; open file
F_CLOSE         .equ 16
F_READ          .equ 20          ; read next record
F_READRAND      .equ 33          ; read random record

msg_filenotfound:
        .db "Could not open 791401", 0dh, 0ah, "$"
msg_wtf:
        .db "Error reading 791401", 0dh, 0ah, "$"
msg_read_done:
        .db $0d, $0a, "@140000G", 0dh, 0ah, "$"
spinner:
        .db "||||////----\\\\\\\\ "
spinner_i:
        .db 0
spinner_template:
        .db " ", 27, "D$"

#ifdef BASIC
filename:
        .db "013-BASIBIN", 0
rom_start_addr .equ 140000q
rom_load_addr  .equ 140000q
#define _FILENAME_DEFINED
#endif

#ifdef TEST_791401
filename:
        .db "791401     ", 0
rom_start_addr .equ 000200q
rom_load_addr  .equ 000000q
#define _FILENAME_DEFINED
#endif

#ifdef TEST_GKAAA0
filename:
        .db "GKAAA0     ", 0
rom_start_addr .equ 000200q
rom_load_addr  .equ 000000q
#define _FILENAME_DEFINED
#endif

#ifndef _FILENAME_DEFINED
filename:
        .db "           ", 0
rom_start_addr .equ 02002q
rom_load_addr  .equ 02000q
#endif  

        .db " $"

load_file:
        lxi b, filename
        call open_fcb1
        
        jz notfound_error

        call ckvaz_init

        ; file read loop
fread_loop:        
        lxi d, fcb1
        mvi c, F_READ
        CALL_BDOS
        ora a
        jz read_ok
        dcr a
        jz read_eof
        jmp wtf_error

        ; 128 bytes loaded at $80
read_ok:
        lxi h, spinner_i
        mov a, m
        inr m
        rar \ rar
        ani $f    ; 16 animation frames
        mov e, a
        mvi d, 0
        lxi h, spinner
        dad d
        mov a, m
        sta spinner_template

        mvi c, C_WRITESTR
        lxi d, spinner_template
        CALL_BDOS

        ; copy these bytes to kvaz
        call ckvaz
        jmp fread_loop

read_eof:
        call close_fcb1

        lxi d, msg_read_done
        mvi c, C_WRITESTR
        CALL_BDOS
        ; play demo
        ret
        
wtf_error:
        lxi d, msg_wtf
        jmp error_exit
notfound_error:
        lxi d, msg_filenotfound
error_exit:        
        mvi c, 9
        jmp BDOS

ckvaz_init:
        lxi h, rom_load_addr
        shld kvaz_sp
        mvi a, 0
        sta kvaz_page
        ret

        ; copy CP/M DMA area to kvaz, advance kvaz position
ckvaz:
        DISINT
        lxi h, 0
        dad sp
        shld ctk_sp

kvaz_page .equ $ + 1
        mvi a, 0
        ori $10
        out $10

kvaz_sp .equ $ + 1
        lxi h, 0
        lxi d, $80
        dad d             ; advance sp for the next copy, check carry
        shld kvaz_sp
        sphl
        jnc ckvaz_samepage  ; no carry, same kvaz bucket
        ; advance kvaz page for the next op
        lxi h, kvaz_page
        mvi a, 4            ; stack-kvaz bucket in bits 2,3
        add m
        mov m, a

ckvaz_samepage:
        lxi h, dma + $80
        mvi c, $80 >> 1
ckvaz_L1:
        dcx h
        mov d, m
        dcx h
        mov e, m
        push d

        dcr c
        jnz ckvaz_L1

        xra a
        out $10
ctk_sp  .equ $ + 1
        lxi sp, 0
        ENAINT
        ret

open_fcb1:
        lxi d, fcb1 + 1         ; fcb1 name
cn_L1:  ldax b
        ora a
        jz fcb_ready 
        stax d
        inx b \ inx d
        jmp cn_L1
fcb_ready:
        mvi c, F_OPEN
        lxi d, fcb1
        CALL_BDOS
        inr a
        ret

close_fcb1:
        lxi d, fcb1
        mvi c, F_CLOSE
        jmp BDOS
