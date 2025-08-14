PDP-11/06C: PDP-11 emulated on Vector-06C
=========================================

Emulation is slow. It is recommended to enjoy it in an emulator that supports significant speeding up.

### Example configuration for emu (b2m)
Copy `Vector-06c.cfg` to `Vector-06c-ludicrous.cfg`

Replace
```
main.CPUClock=3MHz
```
with
```
main.CPUClock=96MHz
```

Higher CPU speeds may be possible, but I experienced problems with lost interrupts which made the emulation unusable in some situations.

Launch emu.exe and select Vector-06c-ludicrous configuration. 

Click on the floppy icon and load `vm1rx.fdd`. 

Press `F1`+`F2`+`F12` to boot from floppy. Follow instructions on screen.

Other emulators and hardware work as well, but they are not as fast. Press `F9` in v06x-godot or `Alt`-`End` in emu80.

# Some screens

БЭЙСИК НЦ

![lala](doc/zhdu.gif)

STALK.SAV

![stalk](doc/stalk.gif)

ADVENT.SAV

![getlamp](doc/getlamp.gif)

...

# Useful utilities

 * [ukncbtl-utils](https://github.com/nzeemin/ukncbtl-utils/) UKNCBTL emulator utilities.

 * [pdpfs](https://github.com/caldwell/pdpfs) Manipulate RT-11 Filesystems on disk images.


