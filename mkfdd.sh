#cat <<EOF >initial.sub
#A
#VM1-BAS
#EOF
cat <<EOF >initial.sub
VM1RX
EOF
./TASM.EXE -b -85 -DTEST_SERIOUSLY=1 -DBASIC=1 -DWITH_KVAZ=1 vm1.asm vm1-bas.com
mv vm1.lst vm1-bas.lst
./TASM.EXE -b -85 -DTEST_RXDRV=1 -DWITH_KVAZ=1 vm1.asm vm1rx.com
mv vm1.lst vm1rx.lst
#../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1.com -i bktests/791401 -i vm1-bas.com -i vm1rx.com -i bktests/013-basic.bin -i rt11sj01.dsk -i rt11v5.dsk -o vm1.fdd
../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1.com -i bktests/791401 -i vm1-bas.com -i vm1rx.com -i bktests/013-basic.bin -i stalk.dsk -o vm1.fdd
