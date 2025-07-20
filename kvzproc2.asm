		.org 100h

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

;Input: address - HL
;Output: data - DE
kvazreadDE:
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
		ret
		
;Input: address - HL, data - BC
kvazwriteBC:
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
		ret

;Input: address - HL, data - C
kvazwriteC:
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
		ret

		.end