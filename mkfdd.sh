cat <<EOF >initial.sub
A
VM1-BAS
EOF
./TASM.EXE -b -85 -DTEST_SERIOUSLY=1 -DBASIC=1 -DWITH_KVAZ=1 vm1.asm vm1-bas.com
../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1.com -i bktests/791401 -i vm1-bas.com -i bktests/013-basic.bin -i rt11sj01.dsk -o vm1.fdd
