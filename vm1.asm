        .org $100

        ; test load op16
        ;di
        ;xra a
        ;out $10
        
        ;jmp test_storew_2_nomsg

        ;call putsi \ .db "pdp11 on 8080 svofski 2025", 10, 13, "$"

; load DE from REGISTER mem, addr in HL
#define LOAD_DE_FROM_HL_REG           mov e, m \ inx h \ mov d, m
#define STORE_BC_TO_HL_REG            mov m, c \ inx h \ mov m, b
#define STORE_C_TO_HL_REG             mov m, c
#define STORE_DE_TO_HL_REG            mov m, e \ inx h \ mov m, d
#define STORE_DE_TO_HL_REG_REVERSE    mov m, d \ dcx h \ mov m, e
#define STORE_BC_TO_HL_REG_REVERSE    mov m, b \ dcx h \ mov m, c
#define LOAD_BC_FROM_HL_REG           mov c, m \ inx h \ mov b, m
#define STORE_E_TO_HL_REG             mov m, e

#ifdef WITH_KVAZ

#define LOAD_DE_FROM_HL     call kvazreadDEeven
#define LOAD_BC_FROM_HL     push d \ call kvazreadDEeven \ mov b, d \ mov c, e \ pop d \ inx h
#define LOAD_E_FROM_HL      call kvazreadDE
#define STORE_BC_TO_HL      call kvazwriteBCeven \ inx h
#define STORE_C_TO_HL       call kvazwriteC
#define STORE_A_TO_HL       mov c, a \ call kvazwriteC
#define STORE_DE_TO_HL      call kvazwriteDEeven \ inx h
#define STORE_E_TO_HL       call kvazwriteE

#define STORE_BC_TO_HL_REVERSE  dcx h \ call kvazwriteBCeven
#define STORE_DE_TO_HL_REVERSE  dcx h \ call kvazwriteDEeven

; de = de + guest[hl], hl = hl + 1
#define ADD_FROM_HL_TO_DE   push b \ mov b, d \ mov c, e \ call kvazreadDE \ xchg \ dad b \ xchg \ inx h \ pop b
  
#else

; not kvaz

; load DE from GUEST mem, addr in HL
#define LOAD_DE_FROM_HL     mov e, m \ inx h \ mov d, m
#define LOAD_BC_FROM_HL     mov c, m \ inx h \ mov b, m
#define LOAD_E_FROM_HL mov e, m
#define STORE_BC_TO_HL mov m, c \ inx h \ mov m, b

#define STORE_C_TO_HL mov m, c
#define STORE_A_TO_HL mov m, a
#define STORE_DE_TO_HL mov m, e \ inx h \ mov m, d
#define STORE_E_TO_HL  mov m, e
#define STORE_BC_TO_HL_REVERSE mov m, b \ dcx h \ mov m, c
#define STORE_DE_TO_HL_REVERSE mov m, d \ dcx h \ mov m, e

; de = de + guest[hl], hl = hl + 1
#define ADD_FROM_HL_TO_DE \ mov a, m \ add e \ mov e, a \ inx h \ mov a, m \ adc d \ mov d, a

#endif


#define ALIGN_WORD .org ( $ + 01H) & 0FFFEH ; align word
#define ALIGN_16   .org ( $ + 0FH) & 0FFF0H ; align 16

; Processor Status Word (PSW) bits
#define PSW_C           1      ; Carry
#define PSW_V           2      ; Arithmetic overflow
#define PSW_Z           4      ; Zero result
#define PSW_N           8      ; Negative result
#define PSW_T           16     ; Trap/Debug
#define PSW_P           0200   ; Priority
#define PSW_HALT        0400   ; Halt

#define RQ_EMT    1
#define RQ_TRAP   2
#define RQ_BPT    4
#define RQ_IOT    8
#define RQ_RPLY   16
#define RQ_HALT   32
#define RQ_RSVD   64  ; nonexistent instruction
        
#ifdef NOOOOOO
        lxi d, $1234
        call assert_de_equals
        .dw $1234

        mvi e, $34
        call assert_e_equals \ .db $34

        call setreg \ .dw r3 \ .dw $1234
        call assert_reg_equals \ .dw r3 \ .dw $1234

        ;call putsi \ .db 10, 13, "SETMEM->", 10, 13, '$'
        call setmem \.dw $1000 \ .dw $beef
        ;call putsi \ .db 10, 13, "MEM_EQUALS->", 10, 13, '$'
        call assert_mem_equals \ .dw $1000 \ .dw $beef
        ;call putsi \ .db 10, 13, "FFFUUU->", 10, 13, '$'
#endif

        ; install rst1
        mvi a, $c3
        sta 8
        lxi h, rst1_handler
        shld 8+1

#ifdef TESTBENCH
        ; install fake call5
        mvi a, $c9
        sta 5
#else
        call load_file
#endif
        ;jmp test_mov_1
        ;jmp test_opcodes

#ifdef TEST_SERIOUSLY
        jmp test_from_000200
#endif

#ifdef TEST_ADDRMODES
        jmp test_addrmodes
#endif


#ifdef TEST_OPCODES
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

#endif

#ifdef TEST_SERIOUSLY
test_from_000200:
        call vm1_reset
        ;lxi h, 200q
        lxi h, rom_start_addr   ; 200q for 791401, 140000q for 013-basic
        shld r7
        jmp tm1_loop
#endif

test_mov_1:
#ifdef WITH_KVAZ
        ; copy the test to guest ram, same addresses
        lxi h, test_mov1_pgm
        mvi a, 64   ; 64 words ought to be enough for everybody

tm1_memcpy:
        push psw

          mov c, m
          inx h
          mov b, m
          dcx h
          call kvazwriteBC

          mvi m, 0
          inx h
          mvi m, 0
          inx h

        pop psw
        dcr a
        jnz tm1_memcpy
        
#endif


        call vm1_reset
        lxi h, test_mov1_pgm
        shld r7
tm1_loop:
        call vm1_exec

        ; process interruptsies
        lxi h, intflg
        xra a
        ora m
        jz tm1_loop_end

        mvi a, RQ_EMT
        ana m
        jz vm1int_emt_not
        ; emt 
        mvi a, ~RQ_EMT    ; clear RQ_EMT flag
        ana m
        mov m, a
        lxi h, 30q
        jmp tm1_loop_enter_interrupt
vm1int_emt_not:
        mvi a, RQ_TRAP
        ana m
        jz vm1int_trap_not
        ; it's a trap
        mvi a, ~RQ_TRAP   ; clear RQ_TRAP flag
        ana m
        mov m, a
        lxi h, 34q
        jmp tm1_loop_enter_interrupt
vm1int_trap_not:
        mvi a, RQ_RPLY
        ana m
        jz vm1int_rply_not

        ; rply/trap to 4
        mvi a, ~RQ_RPLY   ; clear RQ_RPLY flag
        ana m
        mov m, a
        lxi h, 4q
        jmp tm1_loop_enter_interrupt
vm1int_rply_not:
        mvi a, RQ_RSVD
        ana m
        jz vm1int_rsvd_not
        ; reserved insn, trap to 10
        mvi a, ~RQ_RSVD
        ana m
        mov m, a
        lxi h, 10q
        jmp tm1_loop_enter_interrupt
vm1int_rsvd_not:
        mvi a, RQ_IOT
        ana m
        jz vm1int_iot_not
        mvi a, ~RQ_IOT
        ana m
        mov m, a
        lxi h, 20q
        jmp tm1_loop_enter_interrupt
vm1int_iot_not:
        hlt
        jmp $   ; impossible, stop

tm1_loop_enter_interrupt:
        lxi d, tm1_loop_end
        push d
        jmp opx_interrupt
tm1_loop_end:
        lhld vm1_opcode
        mov a, h
        ora l
        jnz tm1_loop
        hlt


        ;ALIGN_16
        .org 1000q
test_mov1_pgm:
#ifdef TEST_MOV
        .dw 012700q, 1    ; mov #1, r0
        .dw 012702q, 2    ; mov #2, r2
        .dw 012737q, 0123456q, 00000004q ; mov #123456, @#4
        .dw 016202q, 2    ; mov 2(r2),r2
        .dw 010001q       ; mov r0, r1
        .dw 010200q       ; mov r2, r0
        .dw 012705q       ; mov #125125, r5
        .dw 125125q       ;
        .dw 000305q       ; swab r5
        ;
        .dw 012737q       ; mov #125125, @#160 ; (=0x70)
        .dw 125125q
        .dw 000160q
        .dw 000337q       ; swab @#160
        .dw 000160q
        .dw 013704q       ; mov @#160, r4
        .dw 000160q

        ;
        .dw 012701q       ; mov #160, r1
        .dw 000160q       ; 
        .dw 010121q       ; mov r1, (r1)+
        .dw 010121q       ; mov r1, (r1)+
        .dw 010121q       ; mov r1, (r1)+
        .dw 010121q       ; mov r1, (r1)+
        .dw 014102q       ; mov -(r1), r2
        .dw 014103q       ; mov -(r1), r3
        .dw 014104q       ; mov -(r1), r4
        .dw 014105q       ; mov -(r1), r5
#endif
;
;        ;.dw 014747q       ; mov -(r7), -(r7)
;

#ifdef TEST_MOVB
        ; write "pqrs" to 0x70, read back bytes
        ; exp: 000002 000160 000163 000162 000161 000160 000000 006520
        .dw 012701q       ; mov #160, r1
        .dw 000160q       ; 
        .dw 110121q       ; movb r1, (r1)+
        .dw 110121q       ; movb r1, (r1)+
        .dw 110121q       ; movb r1, (r1)+
        .dw 110121q       ; movb r1, (r1)+
        .dw 114102q       ; movb -(r1),r2
        .dw 114103q       ; movb -(r1),r3
        .dw 114104q       ; movb -(r1),r4
        .dw 114105q       ; movb -(r1),r5
#endif

#ifdef TEST_MOVB2
        .dw 112702q; movb #260, r2      ; attention to sign extend
        .dw 000260q
        .dw 112702q; movb #160, r2
        .dw 000160q
        .dw 112722q ; movb #1, (r2)+
        .dw 000001q ; 
        .dw 112722q ; movb #2, (r2)+
        .dw 000002q ;                   ; @000160 = 001001
        .dw 112742q ; movb #3, -(r2)
        .dw 000003q ;
        .dw 112742q ; movb #4, -(r2)
        .dw 000004q ;
#endif

#ifdef TEST_JMP
        ; jmp
        .dw 000167q       ; jmp feck
        .dw 000002q
        .dw 000000q       ; bad halt
        .dw 010700q       ; mov r7, r0
        .dw 000120q       ; jmp (r0)+
        .dw 000120q       ; jmp (r0)+
        .dw 000120q       ; jmp (r0)+
        .dw 000120q       ; jmp (r0)+
#endif

#ifdef TEST_JSR
        ; jsr
        .dw 012706q       ;       mov #400, r6
        .dw 000400q       ;
        .dw 012705q
        .dw 123456q
        .dw 004567q       ;       jsr r5, feck
        .dw 000006q
        .dw 004767q       ;       jsr r7, duck
        .dw 000004q
        .dw 000000q       ;       halt
        .dw 000205q       ; feck: rts r5
        .dw 000207q       ; duck: rts r7
#endif


#ifdef TEST_FLAGSR
        .dw 000257q       ; CCC clear all
        .dw 000261q ;  SEC          
        .dw 000257q       ; CCC clear all
        .dw 000262q ;  SEV          
        .dw 000257q       ; CCC clear all
        .dw 000263q ;  SEC:SEV      
        .dw 000257q       ; CCC clear all
        .dw 000264q ;  SEZ          
        .dw 000257q       ; CCC clear all
        .dw 000265q ;  SEC:SEZ      
        .dw 000257q       ; CCC clear all
        .dw 000266q ;  SEV:SEZ      
        .dw 000257q       ; CCC clear all
        .dw 000267q ;  SEC:SEV:SEZ  
        .dw 000257q       ; CCC clear all
        .dw 000270q ;  SEN          
        .dw 000257q       ; CCC clear all
        .dw 000271q ;  SEN:SEC      
        .dw 000257q       ; CCC clear all
        .dw 000272q ;  SEN:SEV      
        .dw 000257q       ; CCC clear all
        .dw 000273q ;  SEN:SEC:SEV  
        .dw 000257q       ; CCC clear all
        .dw 000274q ;  SEN:SEZ      
        .dw 000257q       ; CCC clear all
        .dw 000275q ;  SEN:SEC:SEZ  
        .dw 000257q       ; CCC clear all
        .dw 000276q ;  SEN:SEV:SEZ  
        .dw 000257q       ; CCC clear all

        .dw 000277q ;  SCC          
        .dw 000241q ;  CLC         
        .dw 000277q ;  SCC          
        .dw 000242q ;  CLV         
        .dw 000277q ;  SCC          
        .dw 000243q ;  CLC:CLV     
        .dw 000277q ;  SCC          
        .dw 000244q ;  CLZ         
        .dw 000277q ;  SCC          
        .dw 000245q ;  CLC:CLZ     
        .dw 000277q ;  SCC          
        .dw 000246q ;  CLV:CLZ
        .dw 000277q ;  SCC          
        .dw 000247q ;  CLC:CLV:CLZ
        .dw 000277q ;  SCC          
        .dw 000250q ;  CLN         
        .dw 000277q ;  SCC          
        .dw 000251q ;  CLN:CLC     
        .dw 000277q ;  SCC          
        .dw 000252q ;  CLN:CLV     
        .dw 000277q ;  SCC          
        .dw 000253q ;  CLN:CLC:CLV 
        .dw 000277q ;  SCC          
        .dw 000254q ;  CLN:CLZ     
        .dw 000277q ;  SCC          
        .dw 000255q ;  CLN:CLC:CLZ 
        .dw 000277q ;  SCC          
        .dw 000256q ;  CLN:CLV:CLZ 
        .dw 000277q ;  SCC          
        .dw 000257q ;  CCC         
#endif

#ifdef TEST_CLR
        .dw 012701q ; mov #177777, r1
        .dw 177777q ; 
        .dw 010100q ; mov r1, r0
        .dw 105001q ; clrb r1
        .dw 005001q ; clr r1
        .dw 012702q ; mov #160, r2
        .dw 000160q ; 
        .dw 010022q ; mov r0, (r2)+
        .dw 010022q ; mov r0, (r2)+
        .dw 005042q ; clr -(r2)
        .dw 005042q ; clr -(r2)

        .dw 112722q ; movb #1, (r2)+
        .dw 000001q ; 
        .dw 112722q ; movb #2, (r2)+
        .dw 000002q ; 
        .dw 105042q ; clrb -(r2)
        .dw 105042q ; clrb -(r2)
#endif

#ifdef TEST_COM
        .dw 112702q ; movb #160, r2
        .dw 000160q ; 
        .dw 005102q ; com r2            r2 -> 177617
        .dw 012703q ; mov #177777, r3
        .dw 177777q ; 
        .dw 105103q ; comb r3           r3 -> 177400
#endif

#ifdef TEST_INC
        .dw 005001q ;     clr r1
        .dw 005201q ;     inc r1
        .dw 005301q ;     dec r1
        .dw 005301q ;     dec r1
        .dw 012701q ;     mov #77777, r1
        .dw 077777q ;     
        .dw 005201q ;     inc r1
        .dw 012701q ;     mov #1, r1
        .dw 000001q ;     
        .dw 005301q ;     dec r1
        .dw 005301q ;     dec r1
        .dw 012701q ;     mov #100000, r1
        .dw 100000q ;     
        .dw 005301q ;     dec r1
#endif

#ifdef TEST_INCB
        .dw 105001q ;     clrb r1
        .dw 105201q ;     incb r1
        .dw 105301q ;     decb r1
        .dw 105301q ;     decb r1
        .dw 112701q ;     movb #177, r1
        .dw 000177q ;     
        .dw 105201q ;     incb r1
        .dw 112701q ;     movb #1, r1
        .dw 000001q ;     
        .dw 105301q ;     decb r1
        .dw 105301q ;     decb r1
        .dw 112701q ;     movb #200, r1
        .dw 000200q ;     
        .dw 105301q ;     decb r1
#endif

#ifdef TEST_NEG
        .dw 012700q ; mov #1, r0
        .dw 000001q ; 
        .dw 005400q ; neg r0    r0->177777
        .dw 105400q ; negb r0   r0->177401
#endif

#ifdef TEST_BR
        ; br
        .dw 000401q       ; br bob
        .dw 000401q       ; mike: br dob
        .dw 000776q       ; bob: br mike
#endif

#ifdef TEST_BRCOND
        .dw 000401q ;        br t0
        .dw 000000q ;  bob:  halt
        .dw 000257q ;  t0:   ccc ; bne: br if Z=0
        .dw 000244q ;        clz
        .dw 001001q ;        bne t1
        .dw 000773q ;        br bob
        .dw 000257q ;  t1:   ccc ; beq: br if Z=1
        .dw 000264q ;        sez
        .dw 001401q ;        beq t2
        .dw 000767q ;        br bob
        .dw 000257q ;  t2:   ccc; bpl: br if N=0
        .dw 100001q ;        bpl t3
        .dw 000764q ;        br bob
        .dw 000257q ;  t3:   ccc; bmi: br if N=1
        .dw 000270q ;        sen
        .dw 100401q ;        bmi t4
        .dw 000760q ;        br bob
        .dw 000257q ;  t4:   ccc; bvc: br if V=0
        .dw 102001q ;        bvc t5
        .dw 000755q ;        br bob
        .dw 000257q ;  t5:   ccc; bvs: br if V=1
        .dw 000262q ;        sev
        .dw 102401q ;        bvs t6
        .dw 000751q ;        br bob
        .dw 000257q ;  t6:   ccc; bhis/bcc: br if C=0
        .dw 103000q ;        bhis t7
        .dw 000257q ;  t7:   ccc; blo/bcs: br if C=1
        .dw 000261q ;        sec
        .dw 103400q ;        blo t8
        .dw 000257q ;  t8:   ccc; bge: br if N ^ V = 0
        .dw 002001q ;        bge t8a
        .dw 000741q ;        br bob
        .dw 000262q ;  t8a:  sev
        .dw 000270q ;        sen
        .dw 002001q ;        bge t9
        .dw 000735q ;        br bob
        .dw 000257q ;  t9:   ccc; blt: br if N ^ V = 1
        .dw 000270q ;        sen
        .dw 002401q ;        blt t9a
        .dw 000731q ;        br bob
        .dw 000257q ;  t9a:  ccc
        .dw 000262q ;        sev
        .dw 002401q ;        blt t10
        .dw 000725q ;        br bob
        .dw 000257q ;  t10:  ccc; ble: br if Z | (N ^ V) = 1
        .dw 000264q ;        sez
        .dw 003401q ;        ble t10a
        .dw 000721q ;        br bob
        .dw 000257q ;  t10a: ccc
        .dw 000270q ;        sen
        .dw 003401q ;        ble t10b
        .dw 000715q ;        br bob
        .dw 000262q ;  t10b: sev
        .dw 003713q ;        ble bob ; will be wrong
        .dw 000250q ;        cln
        .dw 003401q ;        ble t11
        .dw 000710q ;        br bob
        .dw 000257q ;  t11:  ccc; bhi: C | Z = 0
        .dw 000261q ;        sec
        .dw 101305q ;        bhi bob
        .dw 000257q ;        ccc
        .dw 000264q ;        sez
        .dw 101302q ;        bhi bob
        .dw 000257q ;        ccc
        .dw 000277q ;        scc
        .dw 000241q ;        clc
        .dw 000244q ;        clz
        .dw 101001q ;        bhi t12
        .dw 000674q ;        br bob
        .dw 000257q ;  t12:  ccc; blos: C | Z = 1
        .dw 101672q ;        blos bob
        .dw 000261q ;        sec
        .dw 101401q ;        blos t12a
        .dw 000667q ;        br bob
        .dw 000257q ;  t12a: ccc
        .dw 000264q ;        sez
        .dw 101401q ;        blos t13a
        .dw 000663q ;        br bob
        .dw 000400q ;  t13a: br good
        .dw 000000q ;  good: halt        ; PC=240

#endif

#ifdef TEST_SOB
        .dw 012700q ;        mov #2, r0
        .dw 000002q
        .dw 077001q ; lup:   sob r0, lup
#endif

#ifdef TEST_ROR
        .dw 012705q ; mov #123456, r5
        .dw 123465q ; 
        .dw 006005q ; ror r5
        .dw 006105q ; rol r5
        .dw 006205q ; asr r5
        .dw 006305q ; asl r5
        .dw 000257q ; ccc
        .dw 012704q ; mov #100000, r4
        .dw 100000q ; 
        .dw 006104q ; rol r4
        .dw 006004q ; ror r4
        .dw 006304q ; asl r4
        .dw 006204q ; asr r4
#endif

#ifdef TEST_RORB
        .dw 012705q ; mov #123652, r5
        .dw 123653q ; 
        .dw 106005q ; rorb r5 
        .dw 106105q ; rolb r5 
        .dw 106205q ; asrb r5 
        .dw 106305q ; aslb r5
        .dw 000257q ; ccc
        .dw 012704q ; mov #100200, r4
        .dw 100200q ; 
        .dw 106104q ; rolb r4
        .dw 106004q ; rorb r4
        .dw 106304q ; aslb r4
        .dw 106204q ; asrb r4
#endif

#ifdef TEST_ADD
        .dw 060020q 
        .dw 012705q ;
        .dw 000001q ;
        .dw 062705q ;
        .dw 077777q ; -> V

        .dw 012705q ;
        .dw 177777q ;
        .dw 062705q ;
        .dw 100000q ; -> VC
#endif

#ifdef TEST_SUB
        .dw 012705q ; mov #-1, r5
        .dw 177777q ; 
        .dw 162705q ; sub #-32768., r5
        .dw 100000q ; 
        .dw 162705q ; sub #-3, r5
        .dw 177775q ; 
#endif

#ifdef TEST_CMP
        .dw 012700q ; MOV     #5, R0 ; Case 1: Equal values
        .dw 000005q ;                                                                  
        .dw 012701q ; MOV     #5, R1
        .dw 000005q ;                                                                  
        .dw 020100q ; CMP     R1, R0          ; 5 - 5: Expect: Z=1, N=0, V=0, C=0
        .dw 012700q ; MOV     #3, R0 ; Case 2: src > dst (positive result)
        .dw 000003q ;                                                                  
        .dw 012701q ; MOV     #5, R1
        .dw 000005q ;                                                                  
        .dw 020100q ; CMP     R1, R0          ; 5 - 3 = +2: Expect: Z=0, N=0, V=0, C=0
        .dw 012700q ; MOV     #7, R0 ; Case 3: src < dst (negative result)
        .dw 000007q ;                                                                  
        .dw 012701q ; MOV     #2, R1
        .dw 000002q ; 
        .dw 020100q ; CMP     R1, R0          ; 2 - 7 = -5: Expect: Z=0, N=1, V=0, C=1
        .dw 022727q ; CMP     #77777,#-1      ; -> N.VC
        .dw 077777q 
        .dw 177777q
#endif

#ifdef TEST_CMPB
        .dw 122727q ; CMPB     #5, #5          ; 5 - 5: Expect: Z=1, N=0, V=0, C=0
        .dw 000005q ; 
        .dw 000005q ; 
        .dw 122727q ; CMPB     #5, #3          ; 5 - 3 = +2: Expect: Z=0, N=0, V=0, C=0
        .dw 000005q ; 
        .dw 000003q ; 
        .dw 122727q ; CMPB     #2, #7          ; 2 - 7 = -5: Expect: Z=0, N=1, V=0, C=1
        .dw 000002q ; 
        .dw 000007q ; 
        .dw 122727q ; CMPB    #177,#377        ; -> N.VC
        .dw 000177q ; 
        .dw 000377q ; 
#endif

#ifdef TEST_MARK
        .dw 012706q       ;       mov #400, r6
        .dw 000400q       ;
        .dw 012705q       ;       mov #123456, r5
        .dw 123456q
        .dw 010546q       ;       mov r5, -(sp)
        .dw 012746q       ;       mov #1, -(sp)
        .dw 000001q       ;       
        .dw 012746q       ;       mov #2, -(sp)
        .dw 000002q       
        .dw 012746q       ;       mov #3, -(sp)
        .dw 000003q
        .dw 012746q       ;       mov #MARK3, -(sp)
        .dw 006403q
        .dw 010605q       ;       mov sp, r5
        .dw 004767q       ;       jsr pc, babor
        .dw 000002q     
        .dw 000000q       ;       halt
        .dw 000205q       ;babor: rts r5
#endif

#ifdef TEST_SXT
        .dw 012700q       ;       mov #-100000, r0
        .dw 100000q     
        .dw 006700q       ;       sxt r0    -> -1
        .dw 005200q       ;       inc r0
        .dw 005200q       ;       inc r0
        .dw 006700q       ;       sxt r0    ->  0
#endif

#ifdef TEST_BIT
        .dw 005000q       ;       clr r0
        .dw 052700q       ;       bis #000200, r0
        .dw 000200q       ;       
        .dw 052700q       ;       bis #100000, r0
        .dw 100000q       ;       
        .dw 042700q       ;       bic #100000, r0
        .dw 100000q       ;       
        .dw 032700q       ;       bit #000100, r0
        .dw 000100q       ;       
        .dw 032700q       ;       bit #000200, r0
        .dw 000200q       ;       
        .dw 042700q       ;       bic #000200, r0
        .dw 000200q       ;     
#endif

#ifdef TEST_BITB
        .dw 005000q       ;       clr r0
        .dw 152700q       ;       bisb #000100, r0
        .dw 000100q       ;       
        .dw 152700q       ;       bisb #100200, r0
        .dw 100200q       ;       
        .dw 142700q       ;       bicb #100200, r0
        .dw 100200q       ;       
        .dw 132700q       ;       bitb #000200, r0
        .dw 000200q       ;       
        .dw 132700q       ;       bitb #000100, r0
        .dw 000100q       ;       
        .dw 142700q       ;       bicb #000100, r0
        .dw 000100q       ;
#endif

#ifdef TEST_RTI
        .dw 012706q       ;       mov #400, sp
        .dw 000400q
        .dw 012737q       ;       mov #handlur, @#4
        .dw 001030q       
        .dw 000004q       
        .dw 012737q       ;       mov #5, @#6   ; trap flags .Z.C
        .dw 000005q       
        .dw 000006q       
        .dw 106427q       ;       mtps #012  ; set N.V.
        .dw 000012q
        .dw 000100q       ;       jmp r0    ; trap to 4!
        .dw 000000q       ;       halt
        .dw 000002q       ;       rti
#endif

#ifdef TEST_TRAP
        .dw 012706q       ;       mov #400, sp
        .dw 000400q
        .dw 012737q       ;       mov #handlur, @#34    ; tarp
        .dw 001026q       
        .dw 000034q       
        .dw 012737q       ;       mov #handlur, @#30    ; emt
        .dw 001026q       
        .dw 000030q       
        .dw 104400q       ;       trap !
        .dw 104000q       ;       emt !
        .dw 000000q
        .dw 000002q       ;       rti
#endif

#ifdef TEST_ADC
        .dw 000257q       ;       ccc
        .dw 005500q       ;       adc r0
        .dw 000261q       ;       sec
        .dw 005500q       ;       adc r0
        .dw 012700q       ;       mov #77777, r0
        .dw 077777q       ;       
        .dw 000261q       ;       sec
        .dw 005500q       ;       adc r0
        .dw 012700q       ;       mov #-1, r0
        .dw 177777q       ;       
        .dw 000261q       ;       sec
        .dw 005500q       ;       adc r0
#endif

#ifdef TEST_ADCB
        .dw 000257q       ;       ccc
        .dw 105500q       ;       adcb r0
        .dw 000261q       ;       sec
        .dw 105500q       ;       adcb r0
        .dw 112700q       ;       movb #177, r0
        .dw 000177q       ;       
        .dw 000261q       ;       sec
        .dw 105500q       ;       adcb r0
        .dw 012700q       ;       mov #377, r0
        .dw 000377q       ;       
        .dw 000261q       ;       sec
        .dw 105500q       ;       adcb r0
#endif

#ifdef TEST_SBC
        .dw 000257q       ;       ccc
        .dw 005600q       ;       sbc r0
        .dw 005200q       ;       inc r0
        .dw 000261q       ;       sec
        .dw 005600q       ;       sbc r0
        .dw 000261q       ;       sec
        .dw 005600q       ;       sbc r0
        .dw 005000q       ;       clr r0
        .dw 000261q       ;       sec
        .dw 006000q       ;       ror r0
        .dw 000261q       ;       sec
        .dw 005600q       ;       sbc r0
#endif

#ifdef TEST_SBCB
        .dw 012700q       ;       mov #170000, r0
        .dw 170000q       ;       
        .dw 000257q       ;       ccc
        .dw 105600q       ;       sbcb r0
        .dw 105200q       ;       incb r0
        .dw 000261q       ;       sec
        .dw 105600q       ;       sbcb r0
        .dw 000261q       ;       sec
        .dw 105600q       ;       sbcb r0
        .dw 105000q       ;       clrb r0
        .dw 000261q       ;       sec
        .dw 106000q       ;       rorb r0
        .dw 000257q       ;       ccc
        .dw 000261q       ;       sec
        .dw 105600q       ;       sbcb r0
#endif

#ifdef TEST_TST
        .dw 005700q       ;       tst r0
        .dw 005300q       ;       dec r0
        .dw 000257q       ;       ccc
        .dw 005700q       ;       tst r0
        .dw 005000q       ;       clr r0
        .dw 000257q       ;       ccc
        .dw 105700q       ;       tstb r0
        .dw 105300q       ;       decb r0
        .dw 000257q       ;       ccc
        .dw 105700q       ;       tstb r0
#endif

#ifdef TEST_TX
        .dw 012700q
        .dw 177564q
        .dw 111001q
        .dw 105710q
        .dw 100376q
#endif

#ifdef TEST_TX2
        .dw 112702q
        .dw 000040q
        .dw 012700q
        .dw 177564q
        .dw 012701q
        .dw 177566q
        .dw 111005q
        .dw 105710q
        .dw 100376q
        .dw 110211q
        .dw 105202q
        .dw 100373q
#endif

#ifdef TEST_TX3
        .dw 012702q
        .dw 001034q
        .dw 012700q
        .dw 177564q
        .dw 012701q
        .dw 177566q
        .dw 111005q
        .dw 105710q
        .dw 100376q
        .dw 112203q
        .dw 001402q
        .dw 110311q
        .dw 100372q
        .dw 000000q
        .db "This is a test string", 10, 13, 0
#endif

        ; missing tests
        ; tst, tstb
        ;
        ; rtt not impl
        ; halt, wait, rti, bpt, iot, reset, rtt
        ; mfps 1067dd, mtps 1064ss
        ; emt, trap, rti -- kinda sorta ok

        .dw 000000q       ; halt
        .dw 177777q       ; TERMINAT *


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
        .dw 000100q ; JMP 0177700        
        .dw 000200q ; RTS 0177770
        ;.xw 000230q ; SPL           - not on vm1
        .dw 000240q ; CCOND 0177760     ; nop is "clear nothing", also see "snop" 
        ;.xw 000241q ; CCOND 0177760
        ;.xw 000242q ; CCOND 0177760
        ;.xw 000243q ; CCOND 0177760
        ;.xw 000244q ; CCOND 0177760
        ;.xw 000245q ; CCOND 0177760
        ;.xw 000246q ; CCOND 0177760
        ;.xw 000247q ; CCOND 0177760
        ;.xw 000250q ; CCOND 0177760
        ;.xw 000251q ; CCOND 0177760
        ;.xw 000252q ; CCOND 0177760
        ;.xw 000253q ; CCOND 0177760
        ;.xw 000254q ; CCOND 0177760
        ;.xw 000255q ; CCOND 0177760
        ;.xw 000256q ; CCOND 0177760
        ;.xw 000257q ; CCOND 0177760
        .dw 000260q ; SCOND 0177760
        ;.xw 000261q ; SCOND 0177760
        ;.xw 000262q ; SCOND 0177760
        ;.xw 000263q ; SCOND 0177760
        ;.xw 000264q ; SCOND 0177760
        ;.xw 000265q ; SCOND 0177760
        ;.xw 000266q ; SCOND 0177760
        ;.xw 000267q ; SCOND 0177760
        ;.xw 000270q ; SCOND 0177760
        ;.xw 000271q ; SCOND 0177760
        ;.xw 000272q ; SCOND 0177760
        ;.xw 000273q ; SCOND 0177760
        ;.xw 000274q ; SCOND 0177760
        ;.xw 000275q ; SCOND 0177760
        ;.xw 000276q ; SCOND 0177760
        ;.xw 000277q ; SCOND 0177760
        .dw 000300q ; SWAB 0177700
        .dw 000400q ; BR   0177400
        .dw 001000q ; BNE  0177400
        .dw 001400q ; BEQ  0177400
        .dw 002000q ; BGE  0177400
        .dw 002400q ; BLT  0177400
        .dw 003000q ; BGT  0177400
        .dw 003400q ; BLE  0177400
        .dw 004000q ; JSR  0177000
        .dw 005000q ; CLR  0177700         
        .dw 005100q ; COM  0177700
        .dw 005200q ; INC  0177700        
        .dw 005300q ; DEC  0177700         
        .dw 005400q ; NEG  0177700         
        .dw 005500q ; ADC  0177700
        .dw 005600q ; SBC  0177700
        .dw 005700q ; TST  0177700
        .dw 006000q ; ROR 0177700
        .dw 006100q ; ROL 0177700
        .dw 006200q ; ASR 0177700         
        .dw 006300q ; ASL 0177700         
        .dw 006400q ; MARK 0177700
        .dw 006500q ; MFPI
        .dw 006600q ; MTPI
        .dw 006700q ; SXT 0177700
        .dw 010000q ; MOV 0170000
        .dw 020000q ; CMP 0170000
        .dw 030000q ; BIT 0170000
        .dw 040000q ; BIC 0170000
        .dw 050000q ; BIS 0170000
        .dw 060000q ; ADD 0170000
        ;.xw 070000q ; MUL       -- not in vm1
        ;.xw 071000q ; DIV       -- not in vm1
        ;.xw 072000q ; ASH       -- not in vm1
        ;.xw 073000q ; ASHC      -- not in vm1
        .dw 074000q ; XOR 0074000
        ;.xw 075000q ; FADD      -- not in vm1
        ;.xw 075010q ; FSUB      -- not in vm1
        ;.xw 075020q ; FMUL      -- not in vm1
        ;.xw 075030q ; FDIV      -- not in vm1
        .dw 077000q ; SOB  0177000
        .dw 100000q ; BPL  0177400
        .dw 100400q ; BMI  0177400   
        .dw 101000q ; BHI  0177400   
        .dw 101400q ; BLOS 0177400    
        .dw 102000q ; BVC  0177400   
        .dw 102400q ; BVS  0177400   
        .dw 103000q ; BCC  0177400   
        .dw 103400q ; BCS  0177400   
        .dw 104000q ; EMT  0177400
        .dw 104400q ; TRAP 0177400
        .dw 105000q ; CLRB 0177700   
        .dw 105100q ; COMB 0177700    
        .dw 105200q ; INCB 0177700 
        .dw 105300q ; DECB 0177700 
        .dw 105400q ; NEGB 0177700
        .dw 105500q ; ADCB 0177700
        .dw 105600q ; SBCB 0177700
        .dw 105700q ; TSTB 0177700
        .dw 106000q ; RORB 0177700
        .dw 106100q ; ROLB 0177700
        .dw 106200q ; ASRB 0177700
        .dw 106300q ; ASLB 0177700
        .dw 106400q ; MTPS 0177700
        .dw 106500q ; MFPD
        .dw 106600q ; MTPD
        .dw 106700q ; MFPS 0177700
        .dw 110000q ; MOVB 0170000
        .dw 120000q ; CMPB 0170000
        .dw 130000q ; BITB 0170000
        .dw 140000q ; BICB 0170000
        .dw 150000q ; BISB 0170000
        .dw 160000q ; SUB 0170000
        .dw 177777q ; TERMINAT *

; test rst1
rst1_handler:
        lhld vm1_opcode
        call hl_to_hexstr

        lxi d, hexstr
        mvi c, 9
        call 5
  
        call putsi \ .db " opcode not implemented", 10, 13, '$'
        pop h

        ;; trap to 10

        ;lxi h, intflg
        ;mvi a, RQ_RSVD
        ;ora m
        ;mov m, a
        ;pop psw         ; drop normal return addr
        ret

setmem:
#ifdef WITH_KVAZ 
        pop h       ; return addr
        mov e, m    
        inx h
        mov d, m
        inx h       ; de <- guest addr

        mov c, m
        inx h
        mov b, m    ; bc <- value
        inx h
        xchg
        call kvazwriteBC
        xchg
        pchl
#endif
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

assert_mem_equals:
#ifdef WITH_KVAZ
        pop h
        shld assert_adr
        mov e, m \ inx h \ mov d, m \ inx h  ; de <- addr

        push h
          xchg \ call kvazreadDE               ; de <- guest[addr]
        pop h
        
        mov a, e
        cmp m
        inx h
        jnz assert_mem_trap
        mov a, d
        inx h
        jnz assert_mem_trap
        pchl
        ; de = guest mem value under test
assert_mem_trap:
        push d
          lhld assert_adr
          dcx h \ dcx h \ dcx h \ call hl_to_hexstr
          call putsi \ .db "assert at $"
          lxi d, hexstr \ mvi c, 9 \ call 5
        pop h 
        call hl_to_hexstr
        call putsi \ .db " act=$"
        lxi d, hexstr \ mvi c, 9 \ call 5

        jmp assert_reg_trap_exp


#endif
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
assert_reg_trap_exp:
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
#ifdef #WITH_KVAZ
        di
        lxi h, 0
        dad sp
        shld clearmem_sp
        mvi a, kvazbank
        out kvazport
        lxi sp, 0
        lxi h, $caca
        lxi d, 0
clearmem_loop:
        push h
        dcx d
        mov a, d
        ora e
        jnz clearmem_loop

        xra a
        out kvazport

clearmem_sp .equ $+1
        lxi sp, 0
        ei
#endif
        lxi h, $1000
        lxi b, $3000
clearmem_l0:        
        mov m, c
        inx h
        mov a, h
        cmp b
        jnz clearmem_l0
        ret

;#ifndef TESTBENCH
        .include "loader.asm"
;#endif
        
        ;
        ;
        ; EMULATOR CORE
        ;
        ;

        .org $4000

vm1_reset:
        lxi h, regfile
        mvi c, regfile_end - regfile
        xra a
vm1_reset_l1:
        mov m, a \ inx h
        dcr c
        jnz vm1_reset_l1

        lxi h, 0340q
        shld rpsw
        
        ret

        

vm1_exec:
        lhld r7
        LOAD_DE_FROM_HL ; de = opcode, hl += 1
        inx h \ inx h
        shld r7         ; r7 += 2
        mov h, d
        mov l, e        ; keep opcode in de, copy to hl
        shld vm1_opcode
        mov a, h
        ani $f0         ; sel by upper 4 bits
        mov l, a
        mvi h, vm1_opcode1_tbl >> 8
        pchl

vm1_opcode:     .dw 0
vm1_addrmode:   .db 0

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

        jmp mov_setaluf_and_store

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
        jmp movb_setaluf_and_store
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
        cpi 240q \ jz opc_ccond
        cpi 250q \ jz opc_ccond
        cpi 260q \ jz opc_scond
        cpi 270q \ jz opc_scond
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
        cpi 4 \ jz opc_mtps
        cpi 5 \ jz opc_mfpd
        cpi 6 \ jz opc_mtpd
        cpi 7 \ jz opc_mfps
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
        ;                     dcx h to get data/reg addr
load_dd16:        
        ; select addr mode
        mvi a, 070q
        ana l
        sta vm1_addrmode
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
        sta vm1_addrmode
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

        ; value in C -> dst (BC for sign extended 8-bits)
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
rpsw:   .dw 0

intflg: .db 0

regfile_end .equ $

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
        STORE_DE_TO_HL_REG_REVERSE    ; -> 442
        
        ; restore d
        dcx d
        dcx d                 ; de <- 440, checked

        xchg                  ; hl <- R before increment
        LOAD_DE_FROM_HL       ; de <- [hl]  [440]=1526
        
        xchg
        LOAD_DE_FROM_HL       ; de <- [1526], hl = 1527
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
        ;
        ; normal 110
        ;   X = [[R7]], R7 += 2, EA = X + reg
        ;
        ; jmp n
        ;   X = [[R7]], R7 += 2, EA = X + [R7]
        ; de = &reg
ldwmode6:
        push d                ; &reg
          lhld r7
          LOAD_DE_FROM_HL     ; de <- guest[r7] == im16
          inx h \ inx h
          shld r7             ; r7 += 2
        pop h                 ; hl = &reg
        LOAD_BC_FROM_HL_REG   ; bc <- reg (updated if r7)
        xchg                  ; hl <- im16
        dad b                 ; hl = R + im16
        ; bc = 442q, confirmed
        LOAD_DE_FROM_HL       ; de = guest[hl], addr = hl - 1
        ; de = guest[1546] = 012767 = $15f7
        ret

        .org load16 + (32*7)
        ; @X(R)
ldwmode7:
        push d                ; &reg
          lhld r7
          LOAD_DE_FROM_HL     ; de <- guest[r7] == im16
          inx h \ inx h
          shld r7             ; r7 += 2
        pop h                 ; hl = &reg
        LOAD_BC_FROM_HL_REG   ; bc <- reg (updated if r7)
        ; bc = 442q, confirmed

        xchg                  ; hl <- im16
        dad b                 ; hl = R + im16

        LOAD_DE_FROM_HL       ; de = guest[hl], addr = hl - 1

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
        LOAD_DE_FROM_HL_REG ; load register
        push d  ; push EA addr
          push h  ; save reg addr + 1
            ; R += 1, but R6 and R7 += 2
            inx d
            ; r6, r7 the increment is always 2
              mvi a, r5 & 255
              cmp l   ; &r5 - l
              jp $+4
              inx d
              ; ---- 

          pop h ; h <- reg addr + 1
          STORE_DE_TO_HL_REG_REVERSE
        pop h
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
        ; r6, r7 the decrement is always 2
          mvi a, r5 & 255
          cmp l   ; &r5 - l
          jp $+4
          dcx d
          ; --- 
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
        push d
          lhld r7
          LOAD_DE_FROM_HL         ; hidden inx h
          inx h \ inx h           ; = pc + 2
          shld r7
        pop h
        LOAD_BC_FROM_HL_REG
        xchg 
        dad b                   ; hl = R + im16
        LOAD_E_FROM_HL
        ret

        .org load8 + (32*7)
        ; @X(R)
ldbmode7:
        call ldwmode6
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
        STORE_BC_TO_HL
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
        ; de = reg, hl = &reg
        push b
          push h ; reg addr
            lhld r7
            LOAD_BC_FROM_HL       ; bc <- guest[pc]
            inx h
            shld r7               ; r7 ++ 2
          pop h                   ; h = &reg
          LOAD_DE_FROM_HL_REG     ; de = reg (updated if r7)
          xchg                    ; hl = reg
          dad b                   ; hl = reg + bc, EA
        pop b
        STORE_BC_TO_HL
        ret

        .org store16 + (32*7)
stwmode7:
        ; guest[guest[guest[pc] + reg]] <- bc
        ; de = reg, hl = &reg
        push b
          push h ; reg addr
            lhld r7
            LOAD_BC_FROM_HL       ; bc <- guest[pc]
            inx h
            shld r7               ; r7 ++ 2
          pop h                   ; h = &reg
          LOAD_DE_FROM_HL_REG     ; de = reg (updated if r7)
          xchg                    ; hl = reg
          dad b                   ; hl = reg + bc, EA
          LOAD_DE_FROM_HL
          xchg
        pop b
        STORE_BC_TO_HL
        ret


        .org ( $ + 0FFH) & 0FF00H ; align 256
store8:
stbmode0: ; reg16[dst].lsb = C
        ; for movb, store sign-extended value in reg
        lda vm1_opcode+1
        ani $f0
        cpi $90   ; opcode = MOVB 11ssdd
        jz stbmode0_with_sex
        STORE_C_TO_HL_REG
        ret
stbmode0_with_sex:
        STORE_BC_TO_HL_REG   ; store sign extended byte to reg
        ret
        
        .org store8 + (32*1)
stbmode1: ; *reg16[dst] = BC
        xchg
        STORE_C_TO_HL
        ret

        .org store8 + (32*2)
stbmode2: ; *reg16[dst] = C, reg16[dst] += 1
        xchg                  ; hl = reg16[dst], de = &reg16[dst]
        STORE_C_TO_HL
        xchg
        inx d                 ; R += 1

        mvi a, r5 & 255
        cmp l
        jp $+4
        inx d               ; R += 2 for SP, PC

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
        push b
          push h ; reg addr
            lhld r7
            LOAD_BC_FROM_HL       ; bc <- guest[pc]
            inx h
            shld r7               ; r7 ++ 2
          pop h                   ; h = &reg
          LOAD_DE_FROM_HL_REG     ; de = reg (updated if r7)
          xchg                    ; hl = reg
          dad b                   ; hl = reg + bc, EA
        pop b
        STORE_C_TO_HL
        ret


        .org store8 + (32*7)
stbmode7:
        ; guest[guest[guest[pc] + reg]] <- c
        push b
          push h ; reg addr
            lhld r7
            LOAD_BC_FROM_HL       ; bc <- guest[pc] = offset/addr
            inx h
            shld r7               ; r7 ++ 2
          pop h                   ; h = &reg
          LOAD_DE_FROM_HL_REG     ; de = reg (updated if r7)
          xchg                    ; hl = reg
          dad b                   ; hl = reg + bc = reg + offset
          LOAD_DE_FROM_HL         
          xchg                    ; hl = guest[hl]
        pop b
        STORE_C_TO_HL
        ret

        ;
        ; OPCODE IMPLEMENTATION
        ;
opc_nop:  
        ret

        ; cln..ccc  250..257
opc_ccond: 
        lxi h, rpsw
        mvi a, 15
        ana e       ; 4 lsb of opcode == flags to clear
        cma
        ana m
        mov m, a
        ret

        ; sen..scc  260..277
opc_scond:
        lxi h, rpsw
        mvi a, 15   ; 4 lsb of opcode == flags to set
        ana e
        ora m
        mov m, a
        ret

_store_bc_hl_addrmode:
        lda vm1_addrmode
        ora a
        jz _sbcha_reg
        STORE_BC_TO_HL
        ret
_sbcha_reg:
        STORE_BC_TO_HL_REG
        ret

_store_c_hl_addrmode:
        lda vm1_addrmode
        ora a
        jz scha_reg
        STORE_C_TO_HL
        ret
scha_reg:
        STORE_C_TO_HL_REG
        ret

_store_de_hl_addrmode:
        lda vm1_addrmode
        ora a
        jz sdeha_reg
        STORE_DE_TO_HL
        ret
sdeha_reg:
        STORE_DE_TO_HL_REG
        ret

_store_e_hl_addrmode:
        lda vm1_addrmode
        ora a
        jz seha_reg
        STORE_E_TO_HL
        ret
seha_reg:
        STORE_E_TO_HL_REG
        ret


opc_swab: 
        xchg
        call load_dd16   ; load DD -> de
        ;dcx h            ; hl -> op, vm1_addrmode selects addr space
        mov c, d
        mov b, e

        call _store_bc_hl_addrmode

swab_aluf:
        ; aluf NZ, V=0, C = 0
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a

        xra a
        ora c
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a

        xra a
        ora c
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a

        ret
        
opc_rts:  
        ; de = opcode 00020R
        ; r7 = R
        mvi a, 7
        ana e
        add a
        mov l, a
        mvi h, regfile >> 8
        LOAD_DE_FROM_HL_REG
        xchg      ; de = &reg + 1, hl = reg
        shld r7   ; r7 = reg
        
        ; R = [r6]
        lhld r6
        LOAD_BC_FROM_HL ; bc = [r6]
        inx h
        shld r6   ; r6 += 2
        xchg
        STORE_BC_TO_HL_REG_REVERSE  ; R = bc
        ret

opc_rtt:  
        nop
opc_rti:  
        lhld r6
        LOAD_DE_FROM_HL   ; pop pc -> bc
        inx h \ inx h     ; sp += 2
        ; --
        xchg
        shld r7
        xchg
        ; -- 
        LOAD_DE_FROM_HL   ; pop psw -> de
        inx h \ inx h     ; sp += 2
        shld r6           ; save sp
        ; -- preserve halt flag
        lda rpsw+1
        ani ~(PSW_HALT >> 8)
        ora d
        mov d, a          ; new psw with HALT flag
        xchg
        shld rpsw
        ret

opc_br:   
        nop       ; secondary entry point for the testbench to differentiate from the main opcode
opc_br_int:
        mvi d, 0
        mov a, e
        add a       ; c (extend)
        mov e, a
        jnc $+5
        mvi d, -1
        lhld r7
        dad d
        shld r7
        ret

opc_bne:
        ; Z = 0
        lda rpsw
        ani PSW_Z
        jz opc_br_int
        ret
opc_beq:
        ; Z = 1
        lda rpsw
        ani PSW_Z
        jnz opc_br_int
        ret
opc_bge:
        ; N ^ V = 0 
        lda rpsw
        ani PSW_N + PSW_V    ; pe -> ge
        jpe opc_br_int
        ret
opc_blt:
        ; N ^ V = 1
        lda rpsw
        ani PSW_N + PSW_V
        jpo opc_br_int
        ret
opc_bgt:
        ; Z | (N ^ V) = 0  
        lxi h, rpsw
        mvi a,  PSW_N + PSW_V
        ana m
        rpo   ; N ^ V = 1 -> no
        mvi a, PSW_Z
        ana m
        rnz
        jmp opc_br_int
opc_ble:    ; Z | (N ^ V) = 1
        lxi h, rpsw
        mvi a, PSW_N + PSW_V
        ana m
        jpo opc_br_int  ; N ^ V = 1 -> yes
        mvi a, PSW_Z
        ana m
        jnz opc_br_int
        ret
opc_bpl:
        lda rpsw
        ani PSW_N
        jz opc_br_int
        ret
opc_bmi:
        lda rpsw
        ani PSW_N
        jnz opc_br_int
        ret
opc_bhi:
        ; higher than, C | Z = 0
        lda rpsw
        ani PSW_C | PSW_Z
        jz opc_br_int
        ret
opc_blos:
        ; lower than or same as, C | Z = 1
        lda rpsw
        ani PSW_C | PSW_Z
        jnz opc_br_int
        ret
opc_bvc:
        ; overflow clear
        lda rpsw
        ani PSW_V
        jz opc_br_int
        ret
opc_bvs:
        ; overflow set
        lda rpsw
        ani PSW_V
        jnz opc_br_int
        ret
opc_bcc:
        ; C = 0
        lda rpsw
        ani PSW_C
        jz opc_br_int
        ret
opc_bcs:
        ; C = 1
        lda rpsw
        ani PSW_C
        jnz opc_br_int
        ret

opc_jmp:  
        ; 0001dd
        mvi a, 70q
        ana e
        jz jmp_trap
        xchg
        call load_dd16  
        ;dcx h             ; ignore the operand, use its addr as new pc value
        shld r7
        ret
jmp_trap:
        ; impossibru addressing mode
        lxi h, intflg
        mvi a, RQ_RPLY
        ora m
        mov m, a
        ret

opc_jsr:   
        ; de = opcode: 004RDD 
        ; DD like in jump
        ;   temp <- EA
        ;   R6 -= 2
        ;   (R6) = R
        ;   R = R7
        ;   R7 = temp
        
        xchg
        push h
          call load_dd16
          ;dcx h ; h = new address
          xchg  ; de = EA
        pop h ; hl = opcode
        push d ; save EA
          dad h
          dad h
          mvi a, 7
          ana h
          ral
          mov l, a
          mvi h, regfile >> 8
          LOAD_BC_FROM_HL_REG  ; bc = R
          dcx h
          xchg ; save reg addr in d

          lhld r6 \ dcx h \ dcx h \ shld r6     ; R6 -= 2
          STORE_BC_TO_HL                        ; (R6) = R
          
          lhld r7
          xchg ; hl = reg addr, de = r7
          STORE_DE_TO_HL_REG                    ; R = R7
        pop h
        shld r7
        ret

opc_clr:   
        xchg
        lxi b, 0
        call store_dd16
clr_aluf_and_ret:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        ori PSW_Z
        mov m, a
        ret

opc_clrb:
        xchg
        lxi b, 0
        call store_dd8
        jmp clr_aluf_and_ret

opc_com:   
        xchg
        call load_dd16
        ;dcx h
        mov a, d
        cma
        mov b, a
        mov a, e
        cma
        mov c, a
        call _store_bc_hl_addrmode

        ; aluf NZ, V=0, C=1
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        ori PSW_C
        mov m, a

        mov a, b
        ora c
        jnz com_nosetz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
com_nosetz:
        xra a
        ora b
        rp
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_comb:
        xchg
        call load_dd8
        mov a, e
        cma
        ;STORE_A_TO_HL
        mov c, a
        call _store_c_hl_addrmode
        ; aluf NZ, V=0, C=1
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        ori PSW_C
        mov m, a

        xra a
        ora c
        jnz comb_nosetz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
comb_nosetz:
        rp
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_inc:   
        xchg
        call load_dd16
        ;dcx h
        inx d
        ;STORE_DE_TO_HL
        call _store_de_hl_addrmode

        ; aluf NZV
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a
        
        xra a
        ora d
        jp inc_testz
        ;
        mvi a, PSW_N
        ora m
        mov m, a
        ; V flag dst == 0100000
        mov a, e
        ora a
        rnz
        mvi a, $80
        cmp d
        rnz
        mvi a, PSW_V
        ora m
        mov m, a
        ret
inc_testz:
        ora e
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret

opc_dec:   
        xchg
        call load_dd16
        ;dcx h
        dcx d
        ;STORE_DE_TO_HL
        call _store_de_hl_addrmode

        ; aluf NZV
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a

        xra a
        ora d
        jm dec_n
        ora e
        jz dec_z
        inr e
        rnz
        mvi a, $7f
        cmp d
        rnz
        mvi a, PSW_V ; V flag dst == 077777
        ora m
        mov m, a
        ret
dec_n:  mvi a, PSW_N
        ora m
        mov m, a
        ret
dec_z:  mvi a, PSW_Z
        ora m
        mov m, a
        ret


opc_neg:   
        xchg
        call load_dd16
        ;dcx h

        mov a, d
        cma
        mov d, a
        mov a, e
        cma
        mov e, a

        inx d
        call _store_de_hl_addrmode

        ; aluf NZ, V = 0x8000, C = !Z
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a

        mov a, d
        ora e
        mvi a, PSW_Z
        jz $+5
        mvi a, PSW_C
        ora m
        mov m, a

        xra a
        ora d
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a

        ; V flag dst == 0100000
        xra a
        ora e
        rnz
        mvi a, $80
        cmp d
        rnz
        mvi a, PSW_V
        ora m
        mov m, a

        ret

opc_adc:   
        ; 0055dd adc dd: dst <- dst + c
        xchg
        call load_dd16
        ;dcx h           ; hl = &dst, de = dst

        mvi b, 0
        lda rpsw
        rar
        jnc adc_no_cin

        inx d           ; hl = dst + cin (1)
        call _store_de_hl_addrmode

        xra a
        ora e
        jnz adc_no_cin  ; result lsb != 0, definitely nothing special
        mvi a, $80
        cmp d
        jz adc_v
        ; cout if dst == 0
        xra a
        ora d
        jnz adc_no_cin ; not 0, fekov
        mvi b, PSW_C
        jmp adc_no_cin
adc_v:  mvi b, PSW_V
adc_no_cin:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        ora b
        mov m, a
_adc_zn:        
        mov a, d
        ora e
        jnz _adc_n
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
_adc_n:
        xra a
        ora d
        rp
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_sbc:   
        ; 0056dd: sbc dd: dst <- dst - C
        xchg
        call load_dd16
        ;dcx h           ; hl = &dst, de = dst

        mvi b, 0

        lda rpsw
        rar
        jnc adc_no_cin

        ; dst = dst - 1, if dst == 0, cout = 1
        mov a, d
        ora e
        jnz $+5
        mvi b, PSW_C

        dcx d           ; dst <- dst - Cin (1)
        call _store_de_hl_addrmode

        xra a
        ora b
        jnz adc_no_cin  ; can't be Cout and V together

        ; V = dst == $7fff
        dcr a ; a <- $ff
        cmp e
        jnz adc_no_cin
        rar   ; a <- $7f
        cmp d
        jnz adc_no_cin
        mvi b, PSW_V
        jmp adc_no_cin

opc_tst:   
        xchg
        call load_dd16
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a

        xra a
        ora d
        jm _tst_n
        ora e
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
_tst_n:
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_tstb:
        xchg
        call load_dd8
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a

        xra a
        ora e
        jm _tstb_n
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
_tstb_n:
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_ror:   
        ; 0060dd ROR dd
        xchg
        call load_dd16
        ;dcx h

        mov c, e    ; remember lsb for carry aluf
        
        ; load carry
        lda rpsw
        rar 

        mov a, d
        rar       ; with carry from PSW_C
        mov d, a
        mov a, e
        rar
        mov e, a
        ;STORE_DE_TO_HL
        call _store_de_hl_addrmode

        ; aluf NZVC
ror_aluf:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a
        ; C
        mov a, c
        rar           ; saved lsb of source -- test low bit
        mvi a, PSW_C
        jc $+4
        xra a
        ora m
        mov m, a
        jmp rol_nzv

opc_rol:   
        ; 0061dd ROL dd
        xchg
        call load_dd16
        ;dcx h


        mov b, d ; remember msb

        xchg
        dad h

        ; carry in from PSW_C
        lda rpsw
        ani 1
        ora l
        mov l, a

        xchg
        call _store_de_hl_addrmode
rol_aluf:
        ; aluf NZVC
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a
        ; C
        xra a
        ora b ; saved msb of source -- test high bit
        mvi a, PSW_C
        jm $+4
        xra a
        ora m
        mov m, a
        ; set NZV flags after rotation
        ; hl = &rpsw, PSW_C already set, de = result
rol_nzv:  
        ; Z
        mov a, d
        ora e
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a
        ; N
        xra a
        ora d
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a
        ; V = N != C
        mvi a, PSW_N | PSW_C
        ana m
        rpe     ; parity even ~ N == C
        mvi a, PSW_V
        ora m
        mov m, a
        ret
        
opc_asr:   
        ; 0062dd ASR dd
        xchg
        call load_dd16
        ;dcx h
        mov c, e    ; remember lsb for ror_aluf
        mvi a, $80
        ana d       ; remember msb for sign extend
        mov b, a    ; b = sign bit

        mov a, d
        rar
        mov d, a
        mov a, e
        rar
        mov e, a

        mov a, d    ; put sign bit in place
        ora b
        mov d, a
        ;STORE_DE_TO_HL
        call _store_de_hl_addrmode
        jmp ror_aluf

opc_asl:   
        ; 0063dd
        xchg
        call load_dd16
        ;dcx h
        mov b, d ; remember msb for rol_aluf
        xchg
        dad h

        xchg
        ;STORE_DE_TO_HL
        call _store_de_hl_addrmode
        jmp rol_aluf

opc_rorb:
        ; 1060dd RORB dd
        xchg
        call load_dd8   ; -> e, hl = byte addr
        ; load carry
        lda rpsw
        rar
        mov a, e        ; e keeps the original
        rar
        mov d, a        ; d is rotated, for flags

        ;STORE_A_TO_HL
        mov c, a
        call _store_c_hl_addrmode
        
        ; aluf NZVC
rorb_aluf:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a
        ; C
        mov a, e ; original
        rar
        mvi a, PSW_C
        jc $+4
        xra a
        ora m
        mov m, a
        jmp rolb_znv
opc_rolb:
        ; 1061dd ROLB dd
        xchg
        call load_dd8  ; -> e, hl = byte addr
        ; load carry
        lda rpsw
        rar
        mov a, e        ; keep the original in e
        ral
        mov d, a        ; d is rotated value, for flags

        ;STORE_A_TO_HL
        mov c, a
        call _store_c_hl_addrmode

        ; aluf NZVC
rolb_aluf:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a
        ; C
        mov a, e ; original
        ral
        mvi a, PSW_C
        jc $+4
        xra a
        ora m
        mov m, a

        ; h = &rpsw, PSW_C already set
        ; d = byte value
rolb_znv:
        ; Z
        mov a, d
        ora a
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a
        ; N
        xra a
        ora d
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a
        ; V = N != C
        mvi a, PSW_N | PSW_C
        ana m
        rpe ; parity even ~ N == C
        mvi a, PSW_V
        ora m
        mov m, a
        ret
opc_asrb:
        ; 1062dd ASRB dd
        xchg
        call load_dd8 ; -> e, hl = byte addr
        mvi a, $80
        ana e
        mov d, a  ; d = saved sign bit
        mov a, e  ; e keeps the original value
        rar
        ora d     ; asr a
        mov d, a  ; d is rotated, for flags
        ;STORE_A_TO_HL
        mov c, a
        call _store_c_hl_addrmode

        jmp rorb_aluf

opc_aslb:
        xchg
        call load_dd8
        mov a, e
        add a
        mov d, a ; for flags
        ;STORE_A_TO_HL
        mov c, a
        call _store_c_hl_addrmode

        jmp rolb_aluf

opc_mark:   
        ; 0064nn -- do unspeakable things
        lhld r5
        push h
          mvi a, $3f
          ana e
          mov e, a
          mvi d, 0
          lhld r7
          dad d
          dad d       ; i = hl = r7 + 2 * nn

          LOAD_DE_FROM_HL
          inx h \ inx h ; hl = r7 + 2 * nn + 2
          shld r6     ; R6 = ...
          xchg
          shld r5     ; R5 = mem[i]
        pop h
        shld r7     ; PC = R5 (before)
        ret

opc_mfpi:   
        ; not in vm1
        rst 1
opc_mtpi:
        ; not in vm1
        rst 1
opc_sxt:   
        ; 0067dd sxt dd: dd = N ? -1 : 0
        ; de = opcode, keep it there
        lxi h, rpsw
        mvi a, PSW_N
        ana m
        mvi a, $ff
        jnz $+4
        xra a
        mov b, a
        mov c, a

        mvi a, ~(PSW_V | PSW_Z)
        ana m
        mov m, a

        mov a, b
        ora c
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a

        xchg
        jmp store_dd16

opc_bit:
;        ; debug BREAK ------ - -   -
;        lda r7
;        cpi (10506q & 377q)
;        jnz notthat
;        lda r7+1
;        cpi (10506q >> 8)
;        jnz notthat
;        ;hlt
;        mvi a, $76 ; hlt
;        sta killswitch
;notthat:
;        ; -  --  ----   -------------------
;killswitch:   nop

        ; 03ssdd bit ss, dd: src & dst, N=msb, Z=z, V=0, C not touched
        xchg
        push h
          call load_ss16
          mov b, d        ; bc <- src
          mov c, e
        pop h

        push b
          call load_dd16    ; de <- dst
        pop b
        mov a, b
        ana d
        mov b, a
        mov a, c
        ana e
        mov c, a          ; bc = src & dst

        ; BIT-like set flags based on result in BC
bit_aluf: 
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a

        xra a
        ora b
        jm bit_n
        ora c
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret

bit_n:  mvi a, PSW_N
        ora m
        mov m, a
        ret
        
opc_bic:
        ; 04ssdd bic ss, dd: dst <- dst & ~src, N=msb, Z=z, V=0, C not touched
        xchg
        push h
          call load_ss16
          mov b, d
          mov c, e        ; bc <- src
        pop h
        push b
          call load_dd16    ; de <- dst, hl = dst+1
        pop b
        mov a, c
        cma
        ana e
        mov c, a

        mov a, b
        cma
        ana d
        mov b, a          ; bc <- dst & ~src

        ;dcx h
        call _store_bc_hl_addrmode
        jmp bit_aluf

opc_bis:
        ; 05ssdd bis ss, dd: dst <- dst | src, N=msb, Z=z, V=0, C no touchy
        xchg
        push h
          call load_ss16
          mov b, d
          mov c, e
        pop h
        push b
          call load_dd16
        pop b
        mov a, c
        ora e
        mov c, a
        mov a, b
        ora d
        mov b, a

        ;dcx h
        call _store_bc_hl_addrmode
        jmp bit_aluf

opc_bitb:
        ; 13ssdd bitb ss, dd: src & dst, N=msb, Z=z, V=0, C no touchy
        xchg
        push h
          call load_ss8
          mov c, e        ; <- src
        pop h
        push b
          call load_dd8
        pop b
        mov a, c
        ana e
        mov c, a          ; c = src & dst
bitb_aluf:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a

        xra a
        ora c
        jm bitb_n
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
bitb_n: mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_bicb:
        ; 14ssdd bicb ss, dd: dst <- dst & ~src, N=msb, Z=z, V=0, C no touchy
        xchg
        push h
          call load_ss8
          mov c, e
        pop h
        push b
          call load_dd8
        pop b
        mov a, c
        cma
        ana e
        mov c, a      ; c <- dst & ~src
        call _store_c_hl_addrmode
        jmp bitb_aluf

opc_bisb:
        ; 15ssdd bisb ss, dd: dst <- dst | src, N=msb, Z=z, V=0, C no touchy
        xchg
        push h
          call load_ss8
          mov c, e
        pop h
        push b
          call load_dd8
        pop b
        mov a, c
        ora e
        mov c, a      ; c <- dst & ~src
        call _store_c_hl_addrmode
        jmp bitb_aluf

opc_add:
        xchg
        push h
          call load_ss16
          mov b, d
          mov c, e
        pop h
        push b
          call load_dd16
          ;dcx h
        pop b
        ; bc = src, de = dst, hl = &dst
        
        push h
          mov h, d
          mov l, e
          dad b         ; hl = src|bc + dst|de

          mvi c, 0    ; flags tmp storage
          jnc $+5
          mvi c, PSW_C
          ; overflow flag check: sign(src) == sign(dst) && sign(dst) != sign(result) 
          ;                      sign(b) == sign(d) && sign(d) != sign(h) 
          mvi a, $80
          ana b
          xra d       ; + --> sign(src) == sign(dst)
          jm _add_no_v
          mvi a, $80
          ana d
          xra h       ; - --> !=
          jp _add_no_v
          mvi a, PSW_V
          ora c
          mov c, a
_add_no_v:

          xra a
          ora h
          jp _add_maybe_z
          mvi a, PSW_N
          ora c
          mov c, a
          jmp _add_flags_done
_add_maybe_z:
          ora l
          jnz _add_flags_done
          mvi a, PSW_Z
          ora c
          mov c, a
_add_flags_done:
          xchg          ; de <- result
          
          lxi h, rpsw
          mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
          ana m
          ora c
          mov m, a

        pop h         ; hl <- &dst
        jmp _store_de_hl_addrmode


opc_sub:
        xchg
        push h
          call load_ss16
          mov b, d
          mov c, e
        pop h
        push b
          call load_dd16
          ;dcx h
        pop b
        ; bc = src, de = dst, hl = &dst
        
        push h
          mov h, d
          mov l, e

          xra a
          ora l
          sub c
          mov l, a
          mov a, h
          sbb b
          mov h, a ; hl = dst - src, C = borrow
          
          mvi c, 0
          jnc $+5
          mvi c, PSW_C
          ; simh: V = GET_SIGN_W ((src ^ src2) & (~src ^ dst));
          mov a, b
          xra d
          jp _add_no_v
          mov a, b
          cma
          xra h
          jp _add_no_v
          mvi a, PSW_V
          ora c
          mov c, a
          jmp _add_no_v


opc_cmp: 
        ; 02ssdd CMP ss, dd   src - dst -> flags
        xchg
        push h
        ;push d
          call load_ss16
          mov b, d
          mov c, e        ; bc <- src
        ;pop d
        pop h

        push b
          call load_dd16  ; de <- dst
        pop b
        

        ; src - dst (sub the other way around)
        mov a, c
        sub e
        mov c, a
        mov a, b
        sbb d
        mov e, a        ; ec = src - dst, cf=borrow 
        push psw
          lxi h, rpsw
          mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
          ana m
          mov m, a

          ; V = sign(src) != sign(dst) && sign(result) != sign(src)
          mov a, b
          xra d
          ani $80
          mov d, a

          mov a, b
          xra e
          ana d

          mvi a, PSW_V
          jm $+4
          xra a
          ora m
          mov m, a
        pop psw
        ; C = borrow from alu
        mvi a, PSW_C
        jc $+4
        xra a
        ora m
        mov m, a

        xra a
        ora e
        jm cmp_n  ; if N, Z = 0
        ora c
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret       ; if Z, N = 0
cmp_n:
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_cmpb:
        ; 12ssdd CMP ss, dd  src - dst -> flags
        xchg
        push h
          call load_ss8
          mov c, e      ; c <- src
        pop h
        push b
          call load_dd8   ; e <- dst
        pop b
        ; src - dst
        mov a, c
        sub e
        mov b, a        ; c = src, e = dst, b = src - dst, cf = borrow
        push psw
          lxi h, rpsw
          mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
          ana m
          mov m, a

          ; V = sign(src) != sign(dst) && sign(result) != sign(src)
          mov a, c
          xra e
          ani $80
          mov d, a

          mov a, b
          xra c
          ana d

          mvi a, PSW_V
          jm $+4
          xra a
          ora m
          mov m, a
        pop psw
        mvi a, PSW_C
        jc $+4
        xra a
        ora m
        mov m, a

        xra a
        ora b
        jm cmpb_n ; N -> no Z
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
cmpb_n:
        mvi a, PSW_N
        ora m
        mov m, a
        ret


opc_xor:
        ; 074rdd xor r,dd: dd <- r ^ dd
        xchg
        mvi a, 1
        ana h
        mov h, a
        push h
          call load_ss16
          mov b, d
          mov c, e
        pop h
        push b
          call load_dd16
        pop b
        mov a, b
        xra d
        mov b, a
        mov a, c
        xra e
        mov c, a

        ;dcx h
        call _store_bc_hl_addrmode
        jmp bit_aluf

opc_sob:
        ; 077Rnn opcode in de, luckily no flags affected
        mov h, d
        mov l, e
        dad h
        dad h
        mvi a, 7          ; a = R
        ana h             
        ral
        mov l, a          ; l = 2*R
        mvi h, regfile >> 8 
        LOAD_BC_FROM_HL_REG
        dcx b
        STORE_BC_TO_HL_REG_REVERSE

        mov a, b
        ora c
        rz
        
        ; offset = -2 * nn
        mvi a, $3f
        ana e
        add a ; a = 2*nn (7 bit)
        cma
        inr a
        mov e, a
        mvi d, -1
        lhld r7
        dad d
        shld r7
        ret

opc_halt: 
        mvi a, RQ_HALT
        jmp _raise_irq_a
        ;lxi h, 177716q
        ;lxi b, 4
        ;SAVE_DE_TO_HL
opc_wait: 
        rst 1
opc_bpt:  
        mvi a, RQ_BPT
        jmp _raise_irq_a
opc_iot:  
        mvi a, RQ_IOT
        jmp _raise_irq_a
opc_reset:  
        rst 1
opc_emt:
        mvi a, RQ_EMT
        jmp _raise_irq_a

opc_trap:
        mvi a, RQ_TRAP
        jmp _raise_irq_a

_raise_irq_a:
        lxi h, intflg
        ora m
        mov m, a
        ret
        

        ; a special entry point, see main cpu loop
opx_interrupt:
        push h                                ; save int vector
          lxi h, rpsw
          mov c, m
          inx h
          mov b, m    ; bc = old psw

          mvi a, ~(PSW_HALT >> 8)
          ana m
          mov m, a                            ; clear PSW_HALT

          lhld r6 \ dcx h                     ; sp -= 2
          STORE_BC_TO_HL_REVERSE              ; *sp = old psw
          dcx h
          xchg
          lhld r7
          xchg
          STORE_DE_TO_HL_REVERSE
          shld r6                             ; sp -= 2 (store)
        pop h
        ; load vector
        LOAD_DE_FROM_HL
        xchg
        shld r7
        xchg
        inx h \ inx h
        LOAD_DE_FROM_HL
        mov l, e
        mvi h, 0
        shld rpsw
        ret


opc_incb:
        xchg
        call load_dd8
        inr e
        ;STORE_E_TO_HL
        call _store_e_hl_addrmode

        ; aluf NZV
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a

        xra a 
        ora e
        jp incb_testz
        mvi a, PSW_N
        ora m
        mov m, a
        ; V flag if dst == $80
        mvi a, $80
        cmp e
        rnz
        mvi a, PSW_V
        ora m
        mov m, a
        ret
incb_testz:
        rnz
        mvi a, PSW_Z
        ora m
        mov m, a
        ret

opc_decb:
        xchg
        call load_dd8
        dcr e
        call _store_e_hl_addrmode

        ; aluf NZV
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V)
        ana m
        mov m, a

        xra a 
        ora e
        jz decb_z
        jm decb_n

        ; V flag dst == $7f
        mvi a, $7f
        cmp e
        rnz
        mvi a, PSW_V
        ora m
        mov m, a
        ret

decb_n: mvi a, PSW_N
        ora m
        mov m, a
        ret
decb_z: mvi a, PSW_Z
        ora m
        mov m, a
        ret

opc_negb:
        xchg
        call load_dd8
        mov a, e
        cma
        inr a
        mov e, a
        call _store_e_hl_addrmode

        ; aluf NZVC
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        mov m, a

        xra a 
        ora e
        mvi a, PSW_Z
        jz $+5
        mvi a, PSW_C
        ora m
        mov m, a

        xra a
        ora e
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a

        ; V flag dst == $80
        mvi a, $80
        cmp e
        rnz
        mvi a, PSW_V
        ora m
        mov m, a
        ret

opc_adcb:
        ; 1055dd adcb dd: dst <- dst + c
        xchg
        call load_dd8   ; hl = & dst, e = dst8

        mvi b, 0        ; set flags
        lda rpsw
        rar             ; PSW_C -> host.C
        jnc adcb_no_cin

        inr e           ; e = dst8 + cin (1)
        call _store_e_hl_addrmode

        xra a
        ora e
        jnz adcb_no_cout
        ; cout if dst8 == 0
        mvi b, PSW_C
        jmp adcb_no_cin
adcb_no_cout:
        mvi a, $80
        cmp e
        jnz adcb_no_cin
        ; V if dst8 == $80, sign change
        mvi b, PSW_V
adcb_no_cin:
        lxi h, rpsw
        mvi a, ~(PSW_N | PSW_Z | PSW_V | PSW_C)
        ana m
        ora b
        mov m, a

        xra a
        ora e
        jnz _adcb_n
        mvi a, PSW_Z
        ora m
        mov m, a
        ret
_adcb_n:      
        xra a
        ora e
        rp
        mvi a, PSW_N
        ora m
        mov m, a
        ret

opc_sbcb:
        ; 10056dd: sbc dd: dst8 <- dst8 - Cin
        xchg
        call load_dd8   ; hl = &dst8, e = dst

        mvi b, 0        ; set flags

        lda rpsw        ; test Cin
        rar
        jnc adcb_no_cin ; do nothing, set flags like adcb

        dcr e           ; e = dst8 - Cin
        call _store_e_hl_addrmode

        mvi a, $ff      ; 00->ff -> Cout, V = 0
        cmp e
        jnz _sbcb_tv
        mvi b, PSW_C
        jmp adcb_no_cin
_sbcb_tv: 
        rar             ; a=$7f
        cmp e
        jnz adcb_no_cin
        mvi b, PSW_V    ; dst $80->$7f, V = 1 (sign change)
        jmp adcb_no_cin

opc_mfps:
        ; 1067dd: psw -> dst
        push d
          lhld rpsw
          mov c, l
          jmp movb_setaluf_and_store

opc_mtps:
        ; 1064dd: dst -> psw
        xchg
        call load_dd16  ; de <- dd
_mtps_de:
        lxi h, rpsw + 1
        mvi a, PSW_HALT >> 8
        ana m
        jz mtps_user
mtps_halt:
        ora d
        mov m, a
        dcx h
        mov m, e
        ret
mtps_user:
        dcx h   ; msb of psw unchanged 
        mvi a, ~PSW_T
        ana e
        mov e, a
        mvi a, PSW_T
        ana m   ; keep T bit
        ora e   ; set bits from dst
        mov m, a
        ret

opc_mfpd:
        ; not in vm1
        rst 1
opc_mtpd:
        ; not in vm1
        rst 1
mov_setaluf_and_store:
        ; aluf N, Z, V = 0
        lxi h, rpsw
        mvi a, ~(PSW_Z | PSW_N | PSW_V)
        ana m
        mov m, a

        mov a, b
        ora c
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a

        xra a
        ora b
        mvi a, PSW_N
        jm $+4
        xra a
        ora m
        mov m, a

        pop h
        jmp store_dd16

movb_setaluf_and_store:
        ; aluf N, Z, V = 0  -- if dst is reg, sign extend
        lxi h, rpsw
        mvi a, ~(PSW_Z | PSW_N | PSW_V)
        ana m
        mov m, a

        mov a, c
        ora a
        mvi a, PSW_Z
        jz $+4
        xra a
        ora m
        mov m, a

        mvi b, -1 ; sign extend = -1
        mov a, c
        add a
        mvi a, PSW_N
        jc $+5
        xra a
        mov b, a  ; sign extend = 0
        ora m
        mov m, a

        pop h
        call store_dd8
        ret


#ifdef TEST_ADDRMODES

test_addrmodes:

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
        call setmem \ .dw $1236 \ .dw $1234

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
        call setmem \ .dw $1236 \ .dw $beef

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
        call setmem \ .dw $1234 \ .dw $1236
        call setmem \ .dw $1236 \ .dw $beef
        
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
        call setmem \ .dw $1234 \ .dw $beef
        
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
        call setmem \ .dw $1238 \ .dw $beef
        call setmem \ .dw $1236 \ .dw $1238
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
        call setmem \ .dw $1210, $0102 ; [1210] = 0102_big
        call setmem \ .dw 0102h+01234h, $beef

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
        call setmem \ .dw $1210 \ .dw $0102 ; [1210] = 0102_big
        call setmem \ .dw 0102h+01234h \ .dw $1236
        call setmem \ .dw $1236 \ .dw $beef
        
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
        call setmem \ .dw $1236 \ .dw $1234

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
        call setmem \ .dw $1236 \ .dw $beef

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
        call setmem \ .dw $1234 \ .dw $1238     ; byte ptr -> be
        call setmem \ .dw $1236 \ .dw $1239     ; byte ptr -> ef
        call setmem \ .dw $1238 \ .dw $beef
        
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
        call setmem \ .dw $1234 \ .dw $beef
        
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
        call setmem \ .dw $1238 \ .dw $beef     ; 1238: be 1239: ef
        call setmem \ .dw $1236 \ .dw $1238     ; 1236 -> 1238: be
        call setmem \ .dw $1234 \ .dw $1239     ; 1234 -> 1239: ef

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
        call setmem \ .dw $1210 \ .dw $0102 ; -> be
        call setmem \ .dw $1212 \ .dw $0103 ; -> ef
        call setmem \ .dw 0102h+01234h \ .dw $beef

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
        call setmem \ .dw $1210 \ .dw $0102             ; offset 1
        call setmem \ .dw $1212 \ .dw $0105             ; offset 2
        call setmem \ .dw 0102h+01234h \ .dw $1236      ; -> be
        call setmem \ .dw 0105h+01234h \ .dw $1237      ; -> ef
        call setmem \ .dw $1236 \ .dw $beef
        
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
        call assert_mem_equals \ .dw $1000 \ .dw $beef

test_storeb_1:
        call putsi \ .db 10, 13, "MODE 1 BYTE STORE: (R3)=C $"
        call clearmem
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 13q
        call store_dd8
        call assert_mem_equals \ .dw $1000 \ .dw $caef

test_storew_2:
        call putsi \ .db 10, 13, "MODE 2 WORD STORE: (R3)+=BC $"
test_storew_2_nomsg:
        call clearmem
        call setmem \ .dw $1000 \ .dw $b0be
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 23q
        call store_dd16
        call assert_mem_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002
test_storeb_2:
        call putsi \ .db 10, 13, "MODE 2 BYTE STORE: (R3)+=C $"
        call clearmem
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 23q
        call store_dd8
        call assert_mem_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1001

test_storew_3:
        call putsi \ .db 10, 13, "MODE 3 WORD STORE: @(R3)+=BC $"
        call clearmem
        call setmem \ .dw $1000 \ .dw $1004 ; 1000->1004=caca
        call setmem \ .dw $1004 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 33q
        call store_dd16
        call assert_mem_equals \ .dw $1004 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storeb_3:
        call putsi \ .db 10, 13, "MODE 3 BYTE STORE: @(R3)+=C $"
        call clearmem
        call setmem \ .dw $1000 \ .dw $1004 ; 1000->1004=caca
        call setmem \ .dw $1004 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000
        lxi b, $beef
        mvi l, 33q
        call store_dd8
        call assert_mem_equals \ .dw $1004 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storew_4:
        call putsi \ .db 10, 13, "MODE 4 WORD STORE: -(R3)=BC $" 
        call clearmem
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1002
        lxi b, $beef
        mvi l, 43q
        call store_dd16
        call assert_mem_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1000
test_storeb_4:
        call putsi \ .db 10, 13, "MODE 4 BYTE STORE: -(R3)=C $" 
        call clearmem
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1001
        lxi b, $beef
        mvi l, 43q
        call store_dd8
        call assert_mem_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1000

test_storew_5:
        call putsi \ .db 10, 13, "MODE 5 WORD STORE @-(R3)=BC $"
test_storew_5_nomsg:
        call clearmem
        call setmem \ .dw $1002 \ .dw $1000
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1004
        lxi b, $beef
        mvi l, 53q
        call store_dd16
        call assert_mem_equals \ .dw $1000 \ .dw $beef
        call assert_reg_equals \ .dw r3 \ .dw $1002
test_storeb_5:
        call putsi \ .db 10, 13, "MODE 5 BYTE STORE @-(R3)=C $"
        call clearmem
        call setmem \ .dw $1002 \ .dw $1000
        call setmem \ .dw $1000 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1004
        lxi b, $beef
        mvi l, 53q
        call store_dd8
        call assert_mem_equals \ .dw $1000 \ .dw $caef
        call assert_reg_equals \ .dw r3 \ .dw $1002

test_storew_6:
        call putsi \ .db 10, 13, "MODE 6 WORD STORE X(R3)=BC $"
test_storew_6_nomsg:
        call clearmem
        call setmem \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 points to offset at 1000
        call setmem \ .dw $1102 \ .dw $caca  ; write here
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 63q
        call store_dd16
        call assert_mem_equals \ .dw $1102 \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1002
test_storeb_6:
        call putsi \ .db 10, 13, "MODE 6 BYTE STORE X(R3)=C $"
        call clearmem
        call setmem \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 points to offset at 1000
        call setmem \ .dw $1102 \ .dw $caca  ; write here
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 63q
        call store_dd8
        call assert_mem_equals \ .dw $1102 \ .dw $caef
        call assert_reg_equals \ .dw r7 \ .dw $1002

test_storew_7:
        call putsi \ .db 10, 13, "MODE 7 WORD STORE @X(R3)=BC $"
        call setmem \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 + $102 -> addr
        call setmem \ .dw $1102 \ .dw $1104  ; pointer to caca
        call setmem \ .dw $1104 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 73q
        call store_dd16
        call assert_mem_equals \ .dw $1104 \ .dw $beef
        call assert_reg_equals \ .dw r7 \ .dw $1002

test_storeb_7:
        call putsi \ .db 10, 13, "MODE 7 BYTE STORE @X(R3)=C $"
        call setmem \ .dw $1000 \ .dw $0102  ; offset
        call setreg \ .dw r7 \ .dw $1000     ; r7 + $102 -> addr
        call setmem \ .dw $1102 \ .dw $1104  ; pointer to caca
        call setmem \ .dw $1104 \ .dw $caca
        call setreg \ .dw r3 \ .dw $1000     ; base addr
        lxi b, $beef
        mvi l, 73q
        call store_dd8
        call assert_mem_equals \ .dw $1104 \ .dw $caef
        call assert_reg_equals \ .dw r7 \ .dw $1002

        ; 


        hlt
        ; END OF TESTS
        call putsi \ .db 10, 13, "END OF TESTS", 10, 13, '$'
        rst 0


#endif ; ADDRMODES

        .include "kvzproc2.asm"

.end
