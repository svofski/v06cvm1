#!/bin/bash

set -e

#TESTS="ADDRMODES MOV MOVB MOVB2 FLAGSR CLR COM INC NEG BR BRCOND SOB JMP JSR"
TESTS="JSR"

./TASM.EXE -b -85 vm1.asm vm1.com |& tee tasm.log
awk -f opcodes.awk vm1.lst > testbench/vm1_opcodes.h
make -C testbench

for test in $TESTS ; do
  echo -e "\e[7mTEST: $test\e[0m"
  ./TASM.EXE -b -85 -DTEST_$test=1 vm1.asm vm1.com >> tasm.log 2>&1
  testbench/i8080_test
done

