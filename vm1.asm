        .org $100
        
        ; test load op16
        ;di
        ;xra a
        ;out $10
        
        ;jmp test_storew_2_nomsg

        ;call putsi \ .db "pdp11 on 8080 svofski 2025", 10, 13, "$"

; load DE from REGISTER mem, addr in HL
#define LOAD_DE_FROM_HL_REG mov e, m \ inx h \ mov d, m
; load DE from GUEST mem, addr in HL
#define LOAD_DE_FROM_HL mov e, m \ inx h \ mov d, m
#define LOAD_BC_FROM_HL_REG mov c, m \ inx h \ mov b, m
; load E from GUEST mem, addr in HL
#define LOAD_E_FROM_HL mov e, m
#define STORE_BC_TO_HL mov m, c \ inx h \ mov m, b
#define STORE_BC_TO_HL_REG mov m, c \ inx h \ mov m, b
#define STORE_C_TO_HL_REG  mov m, c
#define STORE_C_TO_HL mov m, c
#define STORE_DE_TO_HL mov m, e \ inx h \ mov m, d
#define STORE_DE_TO_HL_REG mov m, e \ inx h \ mov m, d
#define STORE_E_TO_HL  mov m, e
#define STORE_DE_TO_HL_REG_REVERSE mov m, d \ dcx h \ mov m, e

; de = de + guest[hl], hl = hl + 1
#define ADD_FROM_HL_TO_DE \ mov a, m \ add e \ mov e, a \ inx h \ mov a, m \ adc d \ mov d, a

#define ALIGN_WORD .org ( $ + 01H) & 0FFFEH ; align word
        
        lxi d, $1234
        call assert_de_equals
        .dw $1234

        mvi e, $34
        call assert_e_equals \ .db $34

        call setreg \ .dw r3 \ .dw $1234
        call assert_reg_equals \ .dw r3 \ .dw $1234

        ; install rst1
        mvi a, $c3
        sta 8
        lxi h, rst1_handler
        shld 8+1

        ; install fake call5
        mvi a, $c9
        sta 5

        jmp test_opcodes
        
        ; MODE 0 WORD LOAD: DE=R3
test_loadw_0:        
        call putsi \ .db 10, 13, "MODE 0 WORD LOAD: DE=R3 $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        
        mvi l, 03q      ; mode 0, load r3 as DD
        call load_dd16
        
        call assert_de_equals \ .dw $1234       ; expect DE=$1234
        
        lxi h, 000300q ; mode 0, load r3 as SS
        call load_ss16
        call assert_de_equals \ .dw $1234       ; expect DE=$1234

        ; MODE 1 WORD LOAD: DE=(R3)
test_loadw_1:
        call putsi \ .db 10, 13, "MODE 1 WORD LOAD: DE=(R3) $"
test_loadw_1_nomsg:
        call clearmem
        call setreg \ .dw r3 \ .dw $1236
        call setreg \ .dw $1236 \ .dw $1234

        lxi d, 0
        mvi l, 13q
        call load_dd16
        call assert_de_equals \ .dw $1234       ; expect DE=$1234

        lxi d, 0
        lxi h, 001300q
        call load_ss16
        call assert_de_equals \ .dw $1234       ; expect DE=$1234

        
        ; MODE 2 WORD LOAD: DE=(R3)+
test_loadw_2:
        call putsi \ .db 10, 13, "MODE 2 WORD LOAD: DE=(R3)+ $"
test_loadw_2_nomsg:        
        call clearmem
        call setreg \ .dw r3 \ .dw $1236
        call setreg \ .dw $1236 \ .dw $beef

        lxi d, 0
        mvi l, 23q
        call load_dd16
        call assert_de_equals \ .dw $beef       ; expect DE=$beef

        call assert_reg_equals \ .dw r3 \ .dw $1238
        
        call setreg \ .dw r3 \ .dw $1236
        lxi d, 0
        lxi h, 002300q
        call load_ss16
        call assert_de_equals \ .dw $beef       ; expect DE=$beef
        call assert_reg_equals \ .dw r3 \ .dw $1238

        ; MODE 3 WORD LOAD DE=@(R3)+
test_loadw_3:
        call putsi \ .db 10, 13, "MODE 3 WORD LOAD: DE=@(R3)+ $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw $1234 \ .dw $1236
        call setreg \ .dw $1236 \ .dw $beef
        
        lxi h, 003333q          ; load @(r3)+
        call load_dd16
        call assert_de_equals \ .dw $beef       ; expect DE = 0xbeef
        call assert_reg_equals\ .dw r3 \ .dw $1236

        call setreg \ .dw r3 \ .dw $1234
        lxi h, 003333q          ; load @(r3)+
        call load_ss16  
        call assert_de_equals \ .dw $beef       ; expect DE = 0xbeef
        call assert_reg_equals\ .dw r3 \ .dw $1236

        ; MODE 4 WORD LOAD DE=-(R3)
test_loadw_4:
        call putsi \ .db 10, 13, "MODE 4 WORD LOAD: DE=-(R3) $" 
        call clearmem
        call setreg \ .dw r3 \ .dw $1236
        call setreg \ .dw $1234 \ .dw $beef
        
        lxi h, 004343q
        call load_dd16
        call assert_de_equals \ .dw $beef       ; expect DE = 0xbeef
        call assert_reg_equals \ .dw r3 \ .dw $1234
        
        call setreg \ .dw r3 \ .dw $1236
        lxi h, 004343q
        call load_ss16          ; expect DE = 0xbeef
        call assert_de_equals \ .dw $beef       ; expect DE = 0xbeef
        call assert_reg_equals \ .dw r3 \ .dw $1234
        
        ; MODE 5 WORD LOAD DE=@-(R3)
test_loadw_5:
        call putsi \ .db 10, 13, "MODE 5 WORD LOAD DE=@-(R3) $"
test_loadw_5_nomsg:
        call clearmem
        call setreg \ .dw $1238 \ .dw $beef
        call setreg \ .dw $1236 \ .dw $1238
        call setreg \ .dw r3 \ .dw $1238 ; r3 = 1238, --r3: 1236, *r3 = *1236 = 1238, *1238 = beef

        lxi h, 005353q
        call load_dd16
        call assert_de_equals \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1236
        
        ; MODE 6 WORD LOAD DE=X(R3)
test_loadw_6:
        call putsi \ .db 10, 13, "MODE 6 WORD LOAD DE=X(R3) $"
test_loadw_6_nomsg:        
        call clearmem
        call setreg \ .dw r3, $1234
        call setreg \ .dw r7, $1210
        call setreg \ .dw $1210, $0102 ; [1210] = 0102_big
        call setreg \ .dw 0102h+01234h, $beef

        lxi h, 006363q
        call load_dd16
        call assert_de_equals \ .dw $beef
        call assert_reg_equals \ .dw r7, $1212 ; check pc == pc + 2

        call setreg \ .dw r7, $1210
        lxi h, 006363q
        call load_ss16
        call assert_de_equals \ .dw $beef
        call assert_reg_equals \ .dw r7, $1212 ; check pc == pc + 2
        
        ; MODE 7 WORD LOAD DE=@X(R3)
test_loadw_7:
        call putsi \ .db 10, 13, "MODE 7 WORD LOAD DE=@X(R3) $"
test_loadw_7_nomsg:
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw r7 \ .dw $1210
        call setreg \ .dw $1210 \ .dw $0102 ; [1210] = 0102_big
        call setreg \ .dw 0102h+01234h \ .dw $1236
        call setreg \ .dw $1236 \ .dw $beef
        
        lxi h, 007373q
        call load_dd16
        call assert_de_equals \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        call setreg \ .dw r7, $1210
        lxi h, 007373q
        call load_ss16
        call assert_de_equals \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        ; 
        ; 8 bit load tests
        ;

        ; MODE 0 BYTE LOAD: E=R3
test_loadb_0:        
        call putsi \ .db 10, 13, "MODE 0 BYTE LOAD: E=R3 $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        
        mvi l, 03q      ; mode 0, load r3 as DD
        call load_dd8
        
        call assert_e_equals \ .db $34       ; expect DE=$1234
        
        lxi h, 000300q ; mode 0, load r3 as SS
        call load_ss8
        call assert_e_equals \ .db $34       ; expect DE=$1234

        ; MODE 1 BYTE LOAD: DE=(R3)
test_loadb_1:
        call putsi \ .db 10, 13, "MODE 1 BYTE LOAD: E=(R3) $"
test_loadb_1_nomsg:
        call clearmem
        call setreg \ .dw r3 \ .dw $1236
        call setreg \ .dw $1236 \ .dw $1234

        lxi d, 0
        mvi l, 13q
        call load_dd8
        call assert_e_equals \ .db $34

        lxi d, 0
        lxi h, 001300q
        call load_ss8
        call assert_e_equals \ .db $34

        ; odd addr
        call setreg \ .dw r3 \ .dw $1237
        lxi d, 0
        mvi l, 13q
        call load_dd8
        call assert_e_equals \ .db $12

        lxi d, 0
        lxi h, 001300q
        call load_ss8
        call assert_e_equals \ .db $12


        ; MODE 2 BYTE LOAD: E=(R3)+
test_loadb_2:
        call putsi \ .db 10, 13, "MODE 2 BYTE LOAD: E=(R3)+ $"
test_loadb_2_nomsg:        
        call clearmem
        call setreg \ .dw $1236 \ .dw $beef

        ; retrieve as destination
        call setreg \ .dw r3 \ .dw $1236
        lxi d, 0
        mvi l, 23q
        call load_dd8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1237

        lxi d, 0
        mvi l, 23q
        call load_dd8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1238

        ;; retrieve as source
        call setreg \ .dw r3 \ .dw $1236
        lxi d, 0
        lxi h, 2300q
        call load_ss8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1237

        lxi d, 0
        lxi h, 2300q
        call load_ss8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1238

        ; MODE 3 BYTE LOAD E=@(R3)+
test_loadb_3:
        call putsi \ .db 10, 13, "MODE 3 BYTE LOAD: E=@(R3)+ $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw $1234 \ .dw $1238     ; byte ptr -> be
        call setreg \ .dw $1236 \ .dw $1239     ; byte ptr -> ef
        call setreg \ .dw $1238 \ .dw $beef
        
        ; as destination
        lxi h, 003333q          ; load @(r3)+
        call load_dd8
        call assert_e_equals \ .db $ef
        call assert_reg_equals \ .dw r3 \ .dw $1236

        lxi h, 003333q          ; load @(r3)+
        call load_dd8
        call assert_e_equals \ .db $be
        call assert_reg_equals \ .dw r3 \ .dw $1238

        ; as source
        call setreg \ .dw r3 \ .dw $1234
        lxi h, 003333q          ; load @(r3)+
        call load_ss8
        call assert_e_equals \ .db $ef
        call assert_reg_equals \ .dw r3 \ .dw $1236

        lxi h, 003333q          ; load @(r3)+
        call load_ss8
        call assert_e_equals \ .db $be
        call assert_reg_equals \ .dw r3 \ .dw $1238

        ; MODE 4 BYTE LOAD E=-(R3)
test_loadb_4:
        call putsi \ .db 10, 13, "MODE 4 BYTE LOAD: E=-(R3) $" 
        call clearmem
        call setreg \ .dw r3 \ .dw $1236
        call setreg \ .dw $1234 \ .dw $beef
        
        lxi h, 004343q
        call load_dd8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1235

        lxi h, 004343q
        call load_dd8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1234

        call setreg \ .dw r3 \ .dw $1236
        lxi h, 004343q
        call load_ss8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1235

        lxi h, 004343q
        call load_ss8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1234

        ; MODE 5 BYTE LOAD E=@-(R3)
test_loadb_5:
        call putsi \ .db 10, 13, "MODE 5 BYTE LOAD E=@-(R3) $"
test_loadb_5_nomsg:
        call clearmem
        call setreg \ .dw $1238 \ .dw $beef     ; 1238: be 1239: ef
        call setreg \ .dw $1236 \ .dw $1238     ; 1236 -> 1238: be
        call setreg \ .dw $1234 \ .dw $1239     ; 1234 -> 1239: ef

        ; as dst
        call setreg \ .dw r3 \ .dw $1238        ; r3 = 1238
        lxi h, 005353q
        call load_dd8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1236

        lxi h, 005353q
        call load_dd8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1234
        
        ; as src
        call setreg \ .dw r3 \ .dw $1238        ; r3 = 1238
        lxi h, 005353q
        call load_ss8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r3 \ .dw $1236

        lxi h, 005353q
        call load_ss8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r3 \ .dw $1234
        
        ; MODE 6 BYTE LOAD E=X(R3)
test_loadb_6:
        call putsi \ .db 10, 13, "MODE 6 BYTE LOAD E=X(R3) $"
test_loadb_6_nomsg:        
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw r7 \ .dw $1210
        call setreg \ .dw $1210 \ .dw $0102 ; -> be
        call setreg \ .dw $1212 \ .dw $0103 ; -> ef
        call setreg \ .dw 0102h+01234h \ .dw $beef

        ; as dst
        lxi h, 006363q
        call load_dd8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        lxi h, 006363q
        call load_dd8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r7 \ .dw $1214 ; check pc == pc + 2

        ; as src
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw r7 \ .dw $1210
        
        lxi h, 006363q
        call load_ss8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        lxi h, 006363q
        call load_ss8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r7 \ .dw $1214 ; check pc == pc + 2

        ; MODE 7 BYTE LOAD E=@X(R3)
test_loadb_7:
        call putsi \ .db 10, 13, "MODE 7 BYTE LOAD E=@X(R3) $"
test_loadb_7_nomsg:
        call clearmem
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw r7 \ .dw $1210
        call setreg \ .dw $1210 \ .dw $0102             ; offset 1
        call setreg \ .dw $1212 \ .dw $0105             ; offset 2
        call setreg \ .dw 0102h+01234h \ .dw $1236      ; -> be
        call setreg \ .dw 0105h+01234h \ .dw $1237      ; -> ef
        call setreg \ .dw $1236 \ .dw $beef
        
        ; as dst
        lxi h, 007373q
        call load_dd8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        lxi h, 007373q
        call load_dd8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r7 \ .dw $1214 ; check pc == pc + 2

        ; as src
        call setreg \ .dw r3 \ .dw $1234
        call setreg \ .dw r7 \ .dw $1210
        
        lxi h, 007373q
        call load_ss8
        call assert_e_equals \ .dw $ef
        call assert_reg_equals \ .dw r7 \ .dw $1212 ; check pc == pc + 2

        lxi h, 007373q
        call load_ss8
        call assert_e_equals \ .dw $be
        call assert_reg_equals \ .dw r7 \ .dw $1214 ; check pc == pc + 2


test_storew_0:
        call putsi \ .db 10, 13, "MODE 0 WORD STORE: R3=BC $"
test_storew_0_nomsg:        
        call clearmem
        call setreg \ .dw r3 \ .dw $4321
        lxi b, $beef
        mvi l, 03q
        call store_dd16

        call assert_reg_equals \ .dw r3 \ .dw $beef

test_storeb_0:
        call putsi \ .db 10, 13, "MODE 0 BYTE STORE: R3=C $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1122
        lxi b, $00ef
        mvi l, 03q
        call store_dd8
        call assert_reg_equals \ .dw r3 \ .dw $11ef

test_storew_1:
        call putsi \ .db 10, 13, "MODE 1 WORD STORE: (R3)=BC $"
        call clearmem
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 13q
        call store_dd16
        call assert_reg_equals \ .dw $1000 \ .dw $beef

test_storeb_1:
        call putsi \ .db 10, 13, "MODE 1 BYTE STORE: (R3)=C $"
        call clearmem
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 13q
        call store_dd8
        call assert_reg_equals \ .dw $1000 \ .dw $caef

test_storew_2:
        call putsi \ .db 10, 13, "MODE 2 WORD STORE: (R3)+=BC $"
test_storew_2_nomsg:
        call clearmem
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 23q
        call store_dd16
        call assert_reg_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002
test_storeb_2:
        call putsi \ .db 10, 13, "MODE 2 BYTE STORE: (R3)+=C $"
        call clearmem
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 23q
        call store_dd8
        call assert_reg_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1001

test_storew_3:
        call putsi \ .db 10, 13, "MODE 3 WORD STORE: @(R3)+=BC $"
        call clearmem
        call setreg \ .dw $1000 \ .dw $1004 ; 1000->1004=caca
        call setreg \ .dw $1004 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 33q
        call store_dd16
        call assert_reg_equals \ .dw $1004 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storeb_3:
        call putsi \ .db 10, 13, "MODE 3 BYTE STORE: @(R3)+=C $"
        call clearmem
        call setreg \ .dw $1000 \ .dw $1004 ; 1000->1004=caca
        call setreg \ .dw $1004 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 33q
        call store_dd8
        call assert_reg_equals \ .dw $1004 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storew_4:
        call putsi \ .db 10, 13, "MODE 4 WORD STORE: -(R3)=BC $" 
        call clearmem
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1002
        lxi b, $beef
        mvi l, 43q
        call store_dd16
        call assert_reg_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1000
test_storeb_4:
        call putsi \ .db 10, 13, "MODE 4 BYTE STORE: -(R3)=C $" 
        call clearmem
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1001
        lxi b, $beef
        mvi l, 43q
        call store_dd8
        call assert_reg_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1000

test_storew_5:
        call putsi \ .db 10, 13, "MODE 5 WORD STORE @-(R3)=BC $"
test_storew_5_nomsg:
        call clearmem
        call setreg \ .dw $1002 \ .dw $1000
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1004
        lxi b, $beef
        mvi l, 53q
        call store_dd16
        call assert_reg_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002
test_storeb_5:
        call putsi \ .db 10, 13, "MODE 5 BYTE STORE @-(R3)=C $"
        call clearmem
        call setreg \ .dw $1002 \ .dw $1000
        call setreg \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1004
        lxi b, $beef
        mvi l, 53q
        call store_dd8
        call assert_reg_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storew_6:
        call putsi \ .db 10, 13, "MODE 6 WORD STORE X(R3)=BC $"
test_storew_6_nomsg:
        call clearmem
        call setreg \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 points to offset at 1000
        call setreg \ .dw $1102 \ .dw $caca  ; write here
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 63q
        call store_dd16
        call assert_reg_equals \ .dw $1102 \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1002
test_storeb_6:
        call putsi \ .db 10, 13, "MODE 6 BYTE STORE X(R3)=C $"
        call clearmem
        call setreg \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 points to offset at 1000
        call setreg \ .dw $1102 \ .dw $caca  ; write here
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 63q
        call store_dd8
        call assert_reg_equals \ .dw $1102 \ .dw $caef
        call assert_reg_equals \ .dw r7 \ .dw $1002

test_storew_7:
        call putsi \ .db 10, 13, "MODE 7 WORD STORE @X(R3)=BC $"
        call setreg \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 + $102 -> addr
        call setreg \ .dw $1102 \ .dw $1104  ; pointer to caca
        call setreg \ .dw $1104 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 73q
        call store_dd16
        call assert_reg_equals \ .dw $1104 \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1002

test_storeb_7:
        call putsi \ .db 10, 13, "MODE 7 BYTE STORE @X(R3)=C $"
        call setreg \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 + $102 -> addr
        call setreg \ .dw $1102 \ .dw $1104  ; pointer to caca
        call setreg \ .dw $1104 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 73q
        call store_dd8
        call assert_reg_equals \ .dw $1104 \ .dw $caef
        call assert_reg_equals \ .dw r7 \ .dw $1002

        ; 


test_opcodes:
        lxi h, test_opcode_table

topc_loop:
        shld r7
        mov e, m
        inx h
        mov d, m
        inx h

        mov a, e
        cpi $ff
        jnz topc_l1
        mov a, d
        cpi $ff
        jz topc_done
topc_l1:
        push h
        push d
        call vm1_exec
        pop d
        pop h
        jmp topc_loop

topc_done:
hlt
        ; END OF TESTS
        call putsi \ .db 10, 13, "END OF TESTS", 10, 13, '$'
        rst 0

; test opcodes
        ALIGN_WORD 
test_opcode_table:
        .dw 000000q ; HALT          
        .dw 000001q ; WAIT          
        .dw 000002q ; RTI           
        .dw 000003q ; BPT           
        .dw 000004q ; IOT           
        .dw 000005q ; RESET         
        .dw 000006q ; RTT           
        .dw 000100q ; JMP           
        .dw 000200q ; RTS           
        ;.xw 000230q ; SPL           - not on vm1
        .dw 000240q ; NOP           
        .dw 000241q ; COND
        .dw 000242q ; COND
        .dw 000243q ; COND
        .dw 000244q ; COND
        .dw 000245q ; COND
        .dw 000246q ; COND
        .dw 000247q ; COND
        .dw 000250q ; COND
        .dw 000251q ; COND
        .dw 000252q ; COND
        .dw 000253q ; COND
        .dw 000254q ; COND
        .dw 000255q ; COND
        .dw 000256q ; COND
        .dw 000257q ; COND
        .dw 000260q ; COND
        .dw 000261q ; COND
        .dw 000262q ; COND
        .dw 000263q ; COND
        .dw 000264q ; COND
        .dw 000265q ; COND
        .dw 000266q ; COND
        .dw 000267q ; COND
        .dw 000270q ; COND
        .dw 000271q ; COND
        .dw 000272q ; COND
        .dw 000273q ; COND
        .dw 000274q ; COND
        .dw 000275q ; COND
        .dw 000276q ; COND
        .dw 000277q ; COND
        .dw 000300q ; SWAB          
        .dw 000400q ; BR            
        .dw 001000q ; BNE           
        .dw 001400q ; BEQ           
        .dw 002000q ; BGE           
        .dw 002400q ; BLT           
        .dw 003000q ; BGT           
        .dw 003400q ; BLE           
        .dw 004000q ; JSR           
        .dw 005000q ; CLR           
        .dw 005100q ; COM           
        .dw 005200q ; INC           
        .dw 005300q ; DEC           
        .dw 005400q ; NEG           
        .dw 005500q ; ADC           
        .dw 005600q ; SBC           
        .dw 005700q ; TST           
        .dw 006000q ; ROR           
        .dw 006100q ; ROL           
        .dw 006200q ; ASR           
        .dw 006300q ; ASL           
        .dw 006400q ; MARK          
        .dw 006500q ; MFPI          
        .dw 006600q ; MTPI          
        .dw 006700q ; SXT           
        .dw 010000q ; MOV           
        .dw 020000q ; CMP           
        .dw 030000q ; BIT           
        .dw 040000q ; BIC           
        .dw 050000q ; BIS           
        .dw 060000q ; ADD           
        ;.xw 070000q ; MUL       -- not in vm1
        ;.xw 071000q ; DIV       -- not in vm1
        ;.xw 072000q ; ASH       -- not in vm1
        ;.xw 073000q ; ASHC      -- not in vm1
        .dw 074000q ; XOR      
        ;.xw 075000q ; FADD      -- not in vm1
        ;.xw 075010q ; FSUB      -- not in vm1
        ;.xw 075020q ; FMUL      -- not in vm1
        ;.xw 075030q ; FDIV      -- not in vm1
        .dw 077000q ; SOB      
        .dw 100000q ; BPL      
        .dw 100400q ; BMI      
        .dw 101000q ; BHI      
        .dw 101400q ; BLOS      
        .dw 102000q ; BVC      
        .dw 102400q ; BVS      
        .dw 103000q ; BCC      
        .dw 103400q ; BCS      
        .dw 104000q ; EMT      
        .dw 104400q ; TRAP     
        .dw 105000q ; CLRB     
        .dw 105100q ; COMB     
        .dw 105200q ; INCB     
        .dw 105300q ; DECB     
        .dw 105400q ; NEGB
        .dw 105500q ; ADCB     
        .dw 105600q ; SBCB     
        .dw 105700q ; TSTB     
        .dw 106000q ; RORB     
        .dw 106100q ; ROLB     
        .dw 106200q ; ASRB     
        .dw 106300q ; ASLB     
        .dw 106500q ; MFPD     
        .dw 106600q ; MTPD     
        .dw 110000q ; MOVB     
        .dw 120000q ; CMPB     
        .dw 130000q ; BITB     
        .dw 140000q ; BICB     
        .dw 150000q ; BISB     
        .dw 160000q ; SUB      
        .dw 177777q ; TERMINAT *

; test rst1
rst1_handler:
        call putsi \ .db "opcode not implemented", 10, 13, '$'
        pop h
        ret

        ; call setreg \ .dw r3 \ .dw $1234
        ; lxi h, $3412    ; r3 = 1234_big
        ; shld r3
setreg: 
        pop h   ; reg addr
        mov e, m
        inx h
        mov d, m
        inx h

        mov a, m
        stax d \ inx d \ inx h
        mov a, m
        stax d \ inx h
        pchl

        ; print inline string literal, e.g. 
        ; call putsi \ .db "hello$"
putsi:
        pop d
        push d
        mvi c, 9
        call 5
        mvi a, '$'
        pop h
putsi_l0:        
        cmp m
        inx h
        jnz putsi_l0
        pchl
        
assert_e_equals:
        pop h
        shld assert_adr
        mov a, m
        cmp e
        jnz assert8_trap
        inx h
        pchl
assert8_trap:
        push psw 
        push d
        call putsi \ .db "assert at $"
        lhld assert_adr
        dcx h \ dcx h \ dcx h
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        call 5
        ;
        call putsi \ .db " e=$"
        pop h
        mvi h, 0
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        call 5
        
        call putsi \ .db " expected=$"
        pop psw
        mvi h, 0
        mov l, a
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        call 5
        
        rst 0

assert_de_equals:
        pop h
        shld assert_adr
        mov a, e
        cmp m
        jnz assert_trap
        inx h
        mov a, d
        cmp m
        jnz assert_trap
        inx h
        pchl
assert_trap:
        push d
        lhld assert_adr
        dcx h \ dcx h \ dcx h
        call hl_to_hexstr
        
        call putsi \ .db "assert at $"
        lxi d, hexstr
        mvi c, 9
        call 5
        
        call putsi \ .db " act=$"

        pop h
        call hl_to_hexstr
        lxi d, hexstr
        mvi c, 9
        call 5
        
        ; expected
        lhld assert_adr
        mov e, m
        inx h
        mov d, m
        xchg
        call hl_to_hexstr
        call putsi \ .db " exp=$"
        lxi d, hexstr
        mvi c, 9
        call 5
assert_trap_nl_exit:
        call putsi \ .db 10, 13, "$"
        
        rst 0

assert_reg_equals:
        pop h
        shld assert_adr
        mov e, m \ inx h \ mov d, m \ inx h

        ldax d
        cmp m
        inx h
        inx d
        jnz assert_reg_trap
        ldax d \ cmp m \ inx h
        jnz assert_reg_trap
        pchl
assert_reg_trap:
        lhld assert_adr
        push h
        dcx h \ dcx h \ dcx h \ call hl_to_hexstr
        call putsi \ .db "assert at $"
        lxi d, hexstr \ mvi c, 9 \ call 5

        pop h
        mov e, m \ inx h \ mov d, m
        xchg
        mov e, m \ inx h \ mov d, m
        xchg
        call hl_to_hexstr
        call putsi \ .db " act=$"
        lxi d, hexstr \ mvi c, 9 \ call 5

        lhld assert_adr
        inx h \ inx h
        mov e, m \ inx h \ mov d, m \ xchg
        call hl_to_hexstr
        call putsi \ .db " exp=$"
        lxi d, hexstr \ mvi c, 9 \ call 5

        jmp assert_trap_nl_exit

        
hl_to_hexstr:
        mvi a, $f0
        ana h
        rar \ rar \ rar \ rar \ call a_to_hexchar \ sta hexstr + 0
        mvi a, $0f
        ana h
        call a_to_hexchar \ sta hexstr + 1
        mvi a, $f0
        ana l
        rar \ rar \ rar \ rar \ call a_to_hexchar \ sta hexstr + 2
        mvi a, $0f
        ana l
        call a_to_hexchar \ sta hexstr + 3
        ret
        
a_to_hexchar:
	ori 0F0h
	daa
	cpi 60h
	sbi 1Fh        
        ret
        
assert_adr: .dw 0        
hexstr:  .db 0, 0, 0, 0, "$"        
        
        
        ; clear $1000..$2fff
clearmem:
        lxi h, $1000
        lxi b, $3000
clearmem_l0:        
        mov m, c
        inx h
        mov a, h
        cmp b
        jnz clearmem_l0
        ret
        
        ;
        ;
        ; EMULATOR CORE
        ;
        ;

        .org $6000

vm1_exec:
        lhld r7
        LOAD_DE_FROM_HL ; de = opcode, hl += 1
        inx h
        shld r7         ; r7 += 2
        mov h, d
        mov l, e        ; keep opcode in de, copy to hl
        shld vm1_opcode
        mov a, h
        ani $f0         ; sel by upper 4 bits
        mov l, a
        mvi h, vm1_opcode1_tbl >> 8
        pchl

vm1_opcode: .dw 0

        .org ( $ + 0FFH) & 0FF00H ; align 256
vm1_opcode1_tbl:
         
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op00:

        ; HALT    000000
        ; WAIT    000001
        ; RTI     000002
        ; BPT     000003
        ; IOT     000004
        ; RESET   000005
        ; RTT     000006

        ; JMP     0001DD  0x0040
        ; RTS     00020R  0x0080

        ; NOP     000240  0xa0
        ; CLC, CLV, CLZ, CLN, CCC               00024x, 00025x 0xa1..0xbf
        ; SEC, SEV, SEZ, SEN, SCC               00026x, 00027x
        ; 
        ; BR      000400  0x100
        ; BNE     001000  0x200
        ; BEQ     001400  0x3xx
        ; BGE     002000  0x4xx
        ; BLT     002400  0x5xx
        ; BGT     003000  0x6xx
        ; BLE     003400  0x7xx
        ; JSR     004RDD  0x800.0x9ff
        ;
        ; CLR..TST 0050DD..0057DD 0xa00..0xbff
        ; ROR..SXT 0060DD..0067DD 0xc00..0xdff
        ; 
        ; opcode in de
        xra a
        ora d
        jz vm1op0x00xx ; instructions 000000..000377

        cpi $a
        jm vm1op0_0x100_0x9ff  ; branches and jsr
        cpi $e
        jm vm1op0xa00_0xdff  ; clr..sxt
        rst 1  ; unknown opcode 
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op01: ; 01ssdd mov ss, dd
opc_mov:
        xchg  ; opcode was in de -> hl
        push h
        call load_ss16
        mov b, d
        mov c, e
        pop h
        call store_dd16
        ret
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op02:
        jmp opc_cmp
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op03:
        jmp opc_bit
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op04:
        jmp opc_bic
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op05:
        jmp opc_bis
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op06:
        jmp opc_add
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op07:
        mvi a, $fe
        ana d
        cpi $78
        jz opc_xor
        cpi $7e
        jz opc_sob
        rst 1
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op10:
        ; BPL 
        ; BMI 
        ; BHI 
        ; BLS 
        ; BVC 
        ; BVS 
        ; BCC 
        ; BCS 
        ; EMT 
        ; TRAP
        ; CLRB
        ; COMB
        ; INCB
        ; DECB
        ; CLRB
        ; ADCB
        ; SBCB
        ; TSTB
        ; RORB
        ; ROLB
        ; ASRB
        ; ASLB
        ; MFPD
        ; MTPD
        jmp vm1op10_disp

        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op11:
opc_movb:
        xchg  ; opcode was in de -> hl
        push h
        call load_ss8
        mov b, d
        mov c, e
        pop h
        call store_dd8
        ret
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op12:
        jmp opc_cmpb
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op13:
        jmp opc_bitb
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op14:
        jmp opc_bicb
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op15:
        jmp opc_bisb
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op16:
        jmp opc_sub
        .org ( $ + 0FH) & 0FFF0H ; align 16
vm1op17:
        rst 1

        ;; non-aligned opcode microcode

        ; instructions 000000..000377
        ; HALT    000000
        ; WAIT    000001
        ; RTI     000002
        ; BPT     000003
        ; IOT     000004
        ; RESET   000005
        ; RTT     000006

        ; JMP     0001DD  0x0040
        ; RTS     00020R  0x0080

        ; NOP     000240  0xa0
        ;
        ; CLC, CLV, CLZ, CLN, CCC               00024x, 00025x 0xa1..0xbf
        ; SEC, SEV, SEZ, SEN, SCC               00026x, 00027x
vm1op0x00xx:
        mov a, e
        cpi 240q  
        jz opc_nop
        ora a \ jz opc_halt
        dcr a \ jz opc_wait
        dcr a \ jz opc_rti
        dcr a \ jz opc_bpt
        dcr a \ jz opc_iot
        dcr a \ jz opc_reset
        dcr a \ jz opc_rtt
        mvi a, 370q
        ana e
        cpi 240q \ jz opc_cond
        cpi 250q \ jz opc_cond
        cpi 260q \ jz opc_cond
        cpi 270q \ jz opc_cond
        cpi 200q \ jz opc_rts
        mvi a, 300q
        ana e
        cpi 100q \ jz opc_jmp
        cpi 300q \ jz opc_swab
        rst 1

        ; branches and jsr
        ; BR      000400  0x100
        ; BNE     001000  0x200
        ; BEQ     001400  0x3xx
        ; BGE     002000  0x4xx
        ; BLT     002400  0x5xx
        ; BGT     003000  0x6xx
        ; BLE     003400  0x7xx
        ; JSR     004RDD  0x800.0x9ff
vm1op0_0x100_0x9ff:
        mvi a, $f
        ana d   ; 1..7 = br*, 8..15 = jsr
        dcr a \ jz opc_br
        dcr a \ jz opc_bne
        dcr a \ jz opc_beq
        dcr a \ jz opc_bge
        dcr a \ jz opc_blt
        dcr a \ jz opc_bgt
        dcr a \ jz opc_ble
        jmp opc_jsr
        rst 1

        ; CLR..TST 0050DD..0057DD 0xa00..0xbff
        ; ROR..SXT 0060DD..0067DD 0xc00..0xdff
        ; CLR: 0A00..0A3F << 2 = 0x28xx  ; & 0x700>>8 = 0
        ; COM: 0A40..0A7F << 2 = 0x29xx  ; & 0x700>>8 = 1
        ; INC: 0A80..0ABF << 2 = 0x2axx  ; & 0x700>>8 = 2
        ; DEC: 0AC0..0AFF << 2 = 0x2bxx  ; & 0x700>>8 = 3
        ; NEG: 0B00..0B3F << 2 = 0x2cxx  ; & 0x700>>8 = 4
        ; ADC: 0B40..0B7F << 2 = 0x2dxx  ; & 0x700>>8 = 5
        ; SBC: 0B80..0BBF << 2 = 0x2exx  ; & 0x700>>8 = 6
        ; TST: 0BC0..0BFF << 2 = 0x2fxx  ; & 0x700>>8 = 7
        ;
        ; ROR: 0C00..0C3F << 2 = 0x30xx  ;
        ; ROL
        ; ASR
        ; ASL
        ; MARK
        ; MFPI
        ; MTPI
        ; SXT
vm1op0xa00_0xdff:
        mov h, d
        mov l, e
        dad h
        dad h
        mvi a, $f0
        ana h
        cpi $30 ; ror << 2 == 0x30xx, etc
        jz vm1op0xc00_0xdff
        mvi a, 7
        ana h \ jz opc_clr
        dcr a \ jz opc_com
        dcr a \ jz opc_inc
        dcr a \ jz opc_dec
        dcr a \ jz opc_neg
        dcr a \ jz opc_adc
        dcr a \ jz opc_sbc
        dcr a \ jz opc_tst
        rst 1
vm1op0xc00_0xdff:
        mvi a, 7
        ana h \ jz opc_ror
        dcr a \ jz opc_rol
        dcr a \ jz opc_asr
        dcr a \ jz opc_asl
        dcr a \ jz opc_mark
        dcr a \ jz opc_mfpi
        dcr a \ jz opc_mtpi
        dcr a \ jz opc_sxt
        rst 1

vm1op10_disp:
        mvi a, $e
        ana d
        rar ; pick x xxx 110 x_xx xxx xxx  -> 110
        cpi 4 \ jm vm1op10_bpl_blo
        cpi 5 \ jm vm1op10_emt_trap
        cpi 6 \ jm vm1op10_clrb_tstb
        ;jmp vm1op10_rorb_mtpd
        ; RORB
        ; ROLB
        ; ASRB
        ; ASLB
        ; MFPD
        ; MTPD
vm1op10_rorb_mtpd:
        mov h, d
        mov l, e
        dad h
        dad h
        mov a, h
        ani 7
              \ jz opc_rorb
        cpi 1 \ jz opc_rolb
        cpi 2 \ jz opc_asrb
        cpi 3 \ jz opc_aslb
        cpi 5 \ jz opc_mfpd
        cpi 6 \ jz opc_mtpd
        rst 1


        ; BPL 
        ; BMI 
        ; BHI 
        ; BLS 
        ; BVC 
        ; BVS 
        ; BCC 
        ; BCS 
vm1op10_bpl_blo:
        mvi a, $f
        ana d \ jz opc_bpl
        cpi 1 \ jz opc_bmi
        cpi 2 \ jz opc_bhi
        cpi 3 \ jz opc_blos
        cpi 4 \ jz opc_bvc
        cpi 5 \ jz opc_bvs
        cpi 6 \ jz opc_bcc
        cpi 7 \ jz opc_bcs
        
        ; EMT 
        ; TRAP
vm1op10_emt_trap:
        mov h, d
        mov l, e
        dad h
        dad h   ; --> 20..23 = emt, 24..27 = trap

        mov a, h
        cpi $24
        jm opc_emt
        jmp opc_trap
        
        ; CLRB
        ; COMB
        ; INCB
        ; DECB
        ; CLRB
        ; ADCB
        ; SBCB
        ; TSTB
vm1op10_clrb_tstb:
        mov h, d
        mov l, e
        dad h
        dad h
        mov a, h
        ani 7 \ jz opc_clrb
        dcr a \ jz opc_comb
        dcr a \ jz opc_incb
        dcr a \ jz opc_decb
        dcr a \ jz opc_negb
        dcr a \ jz opc_adcb
        dcr a \ jz opc_sbcb
        dcr a \ jz opc_tstb
        rst 1

        ; hl = opcode (xxssdd)
        ; destroy everything, data in de = SS
load_ss16:
        dad h
        dad h
        mov l, h
        ; hl = opcode (xxssdd)
        ; destroy everything, data in de = DD
load_dd16:        
        ; select addr mode
        mvi a, 070q
        ana l
        ral \ ral ; addr mode * 32
        mov e, a  ; e = lsb load16[addr mode]
        mvi a, 007q
        ana l
        ral
        mov l, a  ; l = lsb reg16
        
        xchg
        mvi h, load16 >> 8
        mvi d, regfile >> 8
        pchl

        ; same as 16-bit except based on load8
load_ss8:
        dad h
        dad h
        mov l, h
load_dd8:
        mvi a, 070q
        ana l
        ral \ ral ; addr mode * 32
        mov e, a  ; e = lsb load16[addr mode]
        mvi a, 007q
        ana l
        ral
        mov l, a  ; l = lsb reg16
        
        xchg
        mvi h, load8 >> 8
        mvi d, regfile >> 8
        pchl

        ; value in BC -> dst
        ; 6-bit dst spec in L (3-bit mode | 3-bit reg)
store_dd16:
        mvi a, 070q
        ana l \ ral \ ral \ mov e, a ; e = lsb store16[addr mode]
        mvi a, 007q
        ana l \ ral \ mov l, a ; l = lsb &reg16[regnum]
        xchg
        mvi h, store16 >> 8
        mvi d, regfile >> 8
        push h  ; jump addr on stack
        xchg
        LOAD_DE_FROM_HL_REG
        dcx h
        ret ; -> stwmode0..7: de = reg16[dst], hl = &reg16[dst], bc = value

        ; value in C -> dst
        ; 6-bit dst spec in L (3-bit mode | 3-bit reg)
store_dd8:
        mvi a, 070q
        ana l \ ral \ ral \ mov e, a ; e = lsb store8[addr mode]
        mvi a, 007q
        ana l \ ral \ mov l, a ; l = lsb &reg16[regnum]
        xchg
        mvi h, store8 >> 8
        mvi d, regfile >> 8
        push h ; jump addr on stack
        xchg
        LOAD_DE_FROM_HL_REG
        dcx h
        ret ; -> stwmode0..7: de = reg16[dst], hl = &reg16[dst], bc = value
        
        
        .org ( $ + 0FFH) & 0FF00H ; align 256
regfile:        
r0:     .dw 0
r1:     .dw 0
r2:     .dw 0
r3:     .dw 0
r4:     .dw 0
r5:     .dw 0
r6:     .dw 0
r7:     .dw 0

        ; load operand16 in de
        ; 
        .org ( $ + 0FFH) & 0FF00H ; align 256
load16:
        ; R
ldwmode0:
        xchg
        LOAD_DE_FROM_HL_REG
        ret
        
        .org load16 + 32
        ; (R)
ldwmode1:  
        xchg
        LOAD_DE_FROM_HL_REG
        xchg
        LOAD_DE_FROM_HL       ; de = (reg)
        ret
        
        .org load16 + (32*2)
        ; (R)+
ldwmode2:
        xchg
        LOAD_DE_FROM_HL_REG        ; de = reg
        
        ; R += 2
        inx d \ inx d

        STORE_DE_TO_HL_REG_REVERSE
        
        ; restore d
        dcx d
        dcx d
        
        xchg
        LOAD_DE_FROM_HL
        ret
        
        .org load16 + (32*3)
        ; @(R)+
ldwmode3:
        xchg
        LOAD_DE_FROM_HL_REG
        
        ; R += 2
        inx d
        inx d
        STORE_DE_TO_HL_REG_REVERSE
        
        ; restore d
        dcx d
        dcx d
        
        xchg                  ; hl = reg
        LOAD_DE_FROM_HL       ; de = [hl]
        
        xchg
        LOAD_DE_FROM_HL
        ret
        
        .org load16 + (32*4)
        ; -(R)
ldwmode4:  
        xchg
        LOAD_DE_FROM_HL_REG
        
        ; R -= 2
        dcx d
        dcx d
        STORE_DE_TO_HL_REG_REVERSE
        
        xchg                  ; hl = reg
        LOAD_DE_FROM_HL
        ret
        
        .org load16 + (32*5)
        ; @-(R)
ldwmode5:  
        xchg
        LOAD_DE_FROM_HL_REG
        dcx d
        dcx d                 ; de -= 2
        STORE_DE_TO_HL_REG_REVERSE
        xchg                  ; hl = reg
        LOAD_DE_FROM_HL
        xchg
        LOAD_DE_FROM_HL
        ret
        
        .org load16 + (32*6)
        ; X(R) - result = [R + im16], im16 = [R7]
ldwmode6:
        xchg
        LOAD_BC_FROM_HL_REG
        lhld r7
        LOAD_DE_FROM_HL ; hidden inx h
        inx h ; pc += 2
        shld r7
        xchg 
        dad b                 ; hl = R + im16
        LOAD_DE_FROM_HL
        ret

        .org load16 + (32*7)
        ; @X(R)
ldwmode7:
        xchg
        LOAD_BC_FROM_HL_REG
        lhld r7
        LOAD_DE_FROM_HL
        inx h                 ; = pc + 2
        shld r7
        xchg 
        dad b                 ; hl = R + im16, adrs of adrs
        LOAD_DE_FROM_HL
        ; de = adrs
        xchg
        LOAD_DE_FROM_HL
        ret

        ;
        ; ------ byte load modes -------
        ;
        ; load operand8 in e
        .org ( $ + 0FFH) & 0FF00H ; align 256
load8:
        ; R
ldbmode0:
        xchg
        mov e, m              ; de = reg
        ret
        
        .org load8 + 32
        ; (R)
ldbmode1:  
        xchg
        LOAD_DE_FROM_HL_REG
        xchg
        LOAD_E_FROM_HL
        ret
        
        .org load8 + (32*2)
        ; (R)+
ldbmode2:
        xchg
        LOAD_DE_FROM_HL_REG
        
        ; R += 1
        inx d
        STORE_DE_TO_HL_REG_REVERSE
        
        ; restore d
        dcx d
        
        xchg
        LOAD_E_FROM_HL
        ret
        
        .org load8 + (32*3)
        ; @(R)+
ldbmode3:
        xchg
        LOAD_DE_FROM_HL_REG
        ; R += 2
        inx d
        inx d
        STORE_DE_TO_HL_REG_REVERSE
        
        ; restore d
        dcx d
        dcx d
        
        xchg                    ; hl = reg
        LOAD_DE_FROM_HL
        
        xchg
        LOAD_E_FROM_HL
        ret
        
        .org load8 + (32*4)
        ; -(R)
ldbmode4:  
        xchg
        LOAD_DE_FROM_HL_REG
        ; R -= 1
        dcx d
        STORE_DE_TO_HL_REG_REVERSE
        xchg                    ; hl = reg
        ;mov e, m
        LOAD_E_FROM_HL
        ret
        
        .org load8 + (32*5)
        ; @-(R)
ldbmode5:  
        xchg
        LOAD_DE_FROM_HL_REG
        dcx d
        dcx d
        STORE_DE_TO_HL_REG_REVERSE
        xchg                    ; hl = reg
        LOAD_DE_FROM_HL
        xchg
        LOAD_E_FROM_HL
        ret
        
        .org load8 + (32*6)
        ; X(R) - result = [R + im16], im16 = [R7]
ldbmode6:
        xchg
        LOAD_BC_FROM_HL_REG
        lhld r7
        LOAD_DE_FROM_HL         ; hidden inx h
        inx h                   ; = pc + 2
        shld r7
        xchg 
        dad b                   ; hl = R + im16
        LOAD_E_FROM_HL
        ret
        

        .org load8 + (32*7)
        ; @X(R)
ldbmode7:
        xchg
        LOAD_BC_FROM_HL_REG
        lhld r7
        LOAD_DE_FROM_HL
        inx h ; pc += 2
        shld r7
        xchg 
        dad b                   ; hl = R + im16, adrs of adrs
        LOAD_DE_FROM_HL
        ; de = adrs
        xchg
        LOAD_E_FROM_HL
        ret
        
        ; DE = &reg16[dstreg]
        ; BC = value
        .org ( $ + 0FFH) & 0FF00H ; align 256
store16:
stwmode0: ; reg16[dst] = BC
        STORE_BC_TO_HL_REG
        ret
        .org store16 + (32*1)
stwmode1: ; *reg16[dst] = BC
        xchg
        STORE_BC_TO_HL_REG
        ret

        .org store16 + (32*2)
stwmode2: ; *reg16[dst] = BC, reg16[dst] += 2
        xchg                  ; hl = reg16[dst]
        STORE_BC_TO_HL
        inx h
        xchg                  ; hl = &reg16[dst], de = reg16[dst] + 2
        STORE_DE_TO_HL_REG
        ret

        .org store16 + (32*3)
stwmode3: ; **reg16[dst] = BC, reg16[dst] += 2
        inx d \ inx d         ; de = reg16[dst] + 2
        STORE_DE_TO_HL_REG    ; reg16[dst] = reg16[dst] + 2
        dcx d \ dcx d \ xchg  ; hl = old reg16[dst]
        LOAD_DE_FROM_HL
        xchg                  ; hl = *reg16[dst]
        STORE_BC_TO_HL
        ret

        .org store16 + (32*4)
stwmode4:
        ; reg16[dst] -= 2, *reg16[dst] = BC
        dcx d \ dcx d         ; de = reg16[dst] - 2
        STORE_DE_TO_HL_REG    ; reg16[dst] -= 2
        xchg
        STORE_BC_TO_HL
        ret

        .org store16 + (32*5)
stwmode5:
        ; reg16[dst] -= 2, **reg16[dst] = BC
        dcx d \ dcx d         ; de -= 2
        STORE_DE_TO_HL_REG    ; reg16[dst] -= 2
        xchg                  ; hl = reg16[dst] (addr of addr)
        LOAD_DE_FROM_HL
        xchg                  ; hl = *reg16[dst] (addr)
        STORE_BC_TO_HL        ; **reg16[dst] = bc
        ret

        .org store16 + (32*6)
stwmode6:
        ; *(reg16[dst] + *r7) = BC
        lhld r7
        ADD_FROM_HL_TO_DE
        xchg                  ; de = r7 + 1
        STORE_BC_TO_HL
        inx d                 ; r7 += 2
        xchg
        shld r7
        ret

        .org store16 + (32*7)
stwmode7:
        ;; **(reg16[dst] + *r7) = BC
        lhld r7
        ADD_FROM_HL_TO_DE     ; hl += 1
        inx h                 ; = r7 + 2
        shld r7
        xchg
        LOAD_DE_FROM_HL
        xchg
        STORE_BC_TO_HL
        ret


        .org ( $ + 0FFH) & 0FF00H ; align 256
store8:
stbmode0: ; reg16[dst].lsb = C
        STORE_C_TO_HL_REG
        ret
        .org store8 + (32*1)
stbmode1: ; *reg16[dst] = BC
        xchg
        mov m, c
        ret

        .org store8 + (32*2)
stbmode2: ; *reg16[dst] = C, reg16[dst] += 1
        xchg                  ; hl = reg16[dst], de = &reg16[dst]
        STORE_C_TO_HL
        xchg
        inx d
        STORE_DE_TO_HL_REG
        ret

        .org store8 + (32*3)
stbmode3: ; **reg16[dst] = C, reg16[dst] += 2
        inx d \ inx d
        STORE_DE_TO_HL_REG    ; reg16[dst] = reg16[dst] + 2
        dcx d \ dcx d \ xchg  ; hl = old reg16[dst]
        LOAD_DE_FROM_HL
        xchg                  ; hl = *reg16[dst]
        STORE_C_TO_HL         ; **reg16[dst] = C
        ret

        .org store8 + (32*4)
stbmode4:
        ; reg16[dst] -= 1, *reg16[dst] = BC
        dcx d                 ; de = reg16[dst] - 1
        STORE_DE_TO_HL_REG    ; reg16[dst] -= 1
        xchg
        STORE_C_TO_HL
        ret

        .org store8 + (32*5)
stbmode5:
        ; reg16[dst] -= 2, **reg16[dst] = BC
        dcx d \ dcx d         ; de -= 2
        STORE_DE_TO_HL_REG    ; reg16[dst] -= 2
        xchg                  ; hl = reg16[dst] (addr of addr)
        LOAD_DE_FROM_HL
        xchg                  ; hl = *reg16[dst] (addr)
        STORE_C_TO_HL         ; **reg16[dst] = bc
        ret

        .org store8 + (32*6)
stbmode6:
        ; *(reg16[dst] + *r7) = BC
        lhld r7
        ADD_FROM_HL_TO_DE
        xchg                  ; de = r7 + 1
        STORE_C_TO_HL
        inx d                 ; r7 += 2
        xchg
        shld r7
        ret

        .org store8 + (32*7)
stbmode7:
        lhld r7
        ADD_FROM_HL_TO_DE
        inx h                 ; = r7 + 2
        shld r7
        xchg
        LOAD_DE_FROM_HL
        xchg
        STORE_C_TO_HL
        ret

        ;
        ; OPCODE IMPLEMENTATION
        ;
opc_nop:  
        ret
opc_cond: 
        rst 1
opc_swab: 
        rst 1
opc_halt: 
        rst 1
opc_wait: 
        rst 1
opc_rti:  
        rst 1
opc_bpt:  
        rst 1
opc_iot:  
        rst 1
opc_reset:  
        rst 1
opc_rtt:  
        rst 1
opc_rts:  
        rst 1
opc_jmp:  
        rst 1

opc_br:   
        rst 1
opc_bne:   
        rst 1
opc_beq:   
        rst 1
opc_bge:   
        rst 1
opc_blt:   
        rst 1
opc_bgt:   
        rst 1
opc_ble:   
        rst 1
opc_jsr:   
        rst 1

opc_clr:   
        rst 1
opc_com:   
        rst 1
opc_inc:   
        rst 1
opc_dec:   
        rst 1
opc_neg:   
        rst 1
opc_adc:   
        rst 1
opc_sbc:   
        rst 1
opc_tst:   
        rst 1

opc_ror:   
        rst 1
opc_rol:   
        rst 1
opc_asr:   
        rst 1
opc_asl:   
        rst 1
opc_mark:   
        rst 1
opc_mfpi:   
        rst 1
opc_mtpi:   
        rst 1
opc_sxt:   
        rst 1

opc_cmp:
        rst 1
opc_bit:
        rst 1
opc_bic:
        rst 1
opc_bis:
        rst 1
opc_add:
        rst 1
opc_xor:
        rst 1
opc_sob:
        rst 1

opc_bpl:
        rst 1
opc_bmi:
        rst 1
opc_bhi:
        rst 1
opc_blos:
        rst 1
opc_bvc:
        rst 1
opc_bvs:
        rst 1
opc_bcc:
        rst 1
opc_bcs:
        rst 1
opc_emt:
        rst 1
opc_trap:
        rst 1
opc_clrb:
        rst 1
opc_comb:
        rst 1
opc_incb:
        rst 1
opc_decb:
        rst 1
opc_negb:
        rst 1
opc_adcb:
        rst 1
opc_sbcb:
        rst 1
opc_tstb:
        rst 1
opc_rorb:
        rst 1
opc_rolb:
        rst 1
opc_asrb:
        rst 1
opc_aslb:
        rst 1
opc_mfpd:
        rst 1
opc_mtpd:
        rst 1
opc_cmpb:
        rst 1
opc_bitb:
        rst 1
opc_bicb:
        rst 1
opc_bisb:
        rst 1
opc_sub:
        rst 1

.end
