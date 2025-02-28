#!/bin/bash

set -e

./TASM.EXE -b -85 vm1.asm vm1.com
awk -f opcodes.awk vm1.lst > testbench/vm1_opcodes.h
make -C testbench
testbench/i8080_test

