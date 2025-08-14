#!/bin/bash

set -e

#TESTS="ADDRMODES MOV MOVB MOVB2 FLAGSR CLR COM INC INCB NEG BR BRCOND SOB JMP JSR ROR RORB ADD SUB CMP CMPB MARK SXT BIT BITB RTI TRAP ADC ADCB SBC SBCB TST TX TX2 TX3 SERIOUSLY"

### TESTS=RXDRV
### #TESTS=SERIOUSLY
### 
### export WITH_KVAZ=-DWITH_KVAZ=1
### export TESTBENCH=-DTESTBENCH=1
### 
### # BENCHMARK is a trap in testbench on BASIC error message
### #export BENCHMARK=-DBENCHMARK=1
### #export ROM=-DBASIC=1 
### #export ROM=-DTEST_791401=1
### #export ROM=-DTEST_GKAAA0=1
### 
### ./TASM.EXE -b -85 -s -DTEST_$TESTS=1 $WITH_KVAZ $TESTBENCH $ROM vm1.asm vm1.com |& tee tasm.log
### awk -f opcodes.awk vm1.lst > testbench/vm1_opcodes.h
### 
### set -x
### make WITH_KVAZ=$WITH_KVAZ ROM=$ROM BENCHMARK=$BENCHMARK -C testbench 
### 
### mkdir -p log
### 
### for test in $TESTS ; do
###   echo -e "\e[7mTEST: $test\e[0m"
###   ./TASM.EXE -b -85 -s -DTEST_$test=1 $WITH_KVAZ $TESTBENCH $ROM vm1.asm vm1.com >> tasm.log 2>&1
###   testbench/i8080_test | tee log/testbench-$test.txt 2>(tee log/testbench-$test-stderr.txt)
###   cat log/testbench-$test.txt
### done

function build_testbench()
{
    set -x

    test=$1
    if [ "$2" == "BASIC" ] ; then
        ROM=-DBASIC=1
    else
        ROM=-DTEST_$2=1
    fi
    WITH_KVAZ=-DWITH_KVAZ=1
    TESTBENCH=-DTESTBENCH=1

    bench_dir="./tb/$2"
    rm -rf "$bench_dir"
    mkdir -p "$bench_dir"

    echo -e "\e[7mBUILDING TEST: $test $2 -> $bench_exe\e[0m"
    ./TASM.EXE -b -85 -s -DTEST_$test=1 $WITH_KVAZ $TESTBENCH $ROM vm1.asm vm1.com
    awk -f opcodes.awk vm1.lst > testbench/vm1_opcodes.h
    make WITH_KVAZ=$WITH_KVAZ ROM=$ROM BENCHMARK=$BENCHMARK -C testbench 

    mv testbench/i8080_test "$bench_dir"
    mv vm1.com "$bench_dir"
    echo "$bench_dir/i8080_test $bench_dir/vm1.com" > run_$2.sh
    chmod +x run_$2.sh

}

build_testbench SERIOUSLY 791401
build_testbench SERIOUSLY GKAAA0
build_testbench SERIOUSLY BASIC
build_testbench RXDRV RXDRV
