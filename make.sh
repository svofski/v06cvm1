#!/bin/bash

set -e

#TESTS="ADDRMODES MOV MOVB MOVB2 FLAGSR CLR COM INC INCB NEG BR BRCOND SOB JMP JSR ROR RORB ADD SUB CMP CMPB MARK SXT BIT BITB RTI TRAP ADC ADCB SBC SBCB TST TX TX2 TX3 SERIOUSLY"
TESTS="SERIOUSLY"

export WITH_KVAZ=-DWITH_KVAZ=1

./TASM.EXE -b -85 $WITH_KVAZ vm1.asm vm1.com |& tee tasm.log
awk -f opcodes.awk vm1.lst > testbench/vm1_opcodes.h

set -x
make WITH_KVAZ=$WITH_KVAZ -C testbench 

mkdir -p log

for test in $TESTS ; do
  echo -e "\e[7mTEST: $test\e[0m"
  ./TASM.EXE -b -85 -DTEST_$test=1 $WITH_KVAZ vm1.asm vm1.com >> tasm.log 2>&1
  testbench/i8080_test | tee log/testbench-$test.txt 2>(tee log/testbench-$test-stderr.txt)
  cat log/testbench-$test.txt
done

