RX_DISK=advent.dsk

cat <<EOF >initial.sub
U 0
U 0                         PDP-11/06C DEMO DISK
U 0
U 0  Standard kvaz is required. Page 0 will be overwritten by guest RAM. 
U 0  For better enjoyment, a 96MHz Vector-06c is recommended. 
U 0  
U 0  Examples:
U 0
U 0  VM1-BAS                      barebones DVK-1 with ROM BASIC
U 0
U 0  VM1RX BOOT.DSK GAMES.DSK     RT-11, RX0: (SY:) is BOOT.DSK 
U 0                                      RX1: (DK:) is GAMES.DSK
U 0                                       
U 0  Run a game:
U 0  RUN MARS
U 0
U 0  Run Lunar Lander simulation in BASIC:
U 0  RUN BASIC
U 0  OLD ROCKT1
U 0  RUN
U 0
D

EOF
./TASM.EXE -b -85 -s -DTEST_SERIOUSLY=1 -DBASIC=1 -DWITH_KVAZ=1 vm1.asm vm1-bas.com
mv vm1.lst vm1-bas.lst
mv vm1.sym vm1-bas.sym

./TASM.EXE -b -85 -s -DTEST_RXDRV=1 -DWITH_KVAZ=1 vm1.asm vm1rx.com
mv vm1.lst vm1rx.lst
mv vm1.sym vm1rx.sym

#../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1.com -i bktests/791401 -i vm1-bas.com -i vm1rx.com -i bktests/013-basic.bin -i rt11sj01.dsk -i rt11v5.dsk -o vm1.fdd

#../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1.com -i bktests/791401 -i vm1-bas.com -i vm1rx.com -i bktests/013-basic.bin -i stalk.dsk -o vm1.fdd
../fddutil/fddutil.js -r ryba.fdd -i initial.sub -i vm1-bas.com -i vm1rx.com -i bktests/013-basic.bin -i boot.dsk -i games.dsk -o vm1rx.fdd

./import_sym.py vm1rx.sym vm1rx.json
