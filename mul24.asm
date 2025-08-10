;Умножение AHL=A*DE
MulAHL_A_DE:
	mvi c,0
	mov h,d\ mov l,e
	add a\ jc MUL1
	add a\ jc MUL2+2
	add a\ jc MUL3+2
	add a\ jc MUL4+2
	add a\ jc MUL5+2
	add a\ jc MUL6+2
	add a\ jc MUL7+2
	add a\ rc
	lxi h,0
	ret

MUL1: dad h\ adc a\ jnc MUL2+2
MUL2: dad d\ adc c\ dad h\ adc a\ jnc MUL3+2
MUL3: dad d\ adc c\ dad h\ adc a\ jnc MUL4+2
MUL4: dad d\ adc c\ dad h\ adc a\ jnc MUL5+2
MUL5: dad d\ adc c\ dad h\ adc a\ jnc MUL6+2
MUL6: dad d\ adc c\ dad h\ adc a\ jnc MUL7+2
MUL7: dad d\ adc c\ dad h\ adc a\ rnc
MUL8: dad d\ adc c
	ret