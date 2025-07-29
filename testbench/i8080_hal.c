// Intel 8080 (KR580VM80A) microprocessor core model
//
// Copyright (C) 2012 Alexander Demin <alexander@demin.ws>
//
// Credits
//
// Viacheslav Slavinsky, Vector-06C FPGA Replica
// http://code.google.com/p/vector06cc/
//
// Dmitry Tselikov, Bashrikia-2M and Radio-86RK on Altera DE1
// http://bashkiria-2m.narod.ru/fpga.html
//
// Ian Bartholomew, 8080/8085 CPU Exerciser
// http://www.idb.me.uk/sunhillow/8080.html
//
// Frank Cringle, The origianal exerciser for the Z80.
//
// Thanks to zx.pk.ru and nedopc.org/forum communities.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#include "i8080_hal.h"

#include "stdio.h"

#include "memory.h"

//unsigned char memory[0x10000];
Memory memory;

int i8080_hal_memory_read_word(int addr, bool stack) {
    return 
        (i8080_hal_memory_read_byte(addr + 1, stack) << 8) |
        i8080_hal_memory_read_byte(addr, stack);
}

void i8080_hal_memory_write_word(int addr, int word, bool stack) {
    i8080_hal_memory_write_byte(addr, word & 0xff, stack);
    i8080_hal_memory_write_byte(addr + 1, (word >> 8) & 0xff, stack);
}

int i8080_hal_memory_read_byte(int addr, bool stack) {
    return memory.read(addr, stack);
}

void i8080_hal_memory_write_byte(int addr, int byte, bool stack) {
    if (addr < 256) {
        // print scratchpad area writes
        fprintf(stderr, " [%04o<-%02x]", addr, byte);
    }
    //memory[addr & 0xffff] = byte;
    memory.write(addr, byte, stack);
}

 __attribute__((weak))
int i8080_hal_io_input(int port)
{
    return 0;
}

__attribute__((weak))
void i8080_hal_io_output(int port, int value)
{
    if (port == 0x10) {
        memory.control_write(value & 0377);
    }
}

void i8080_hal_iff(int on) {
    // Northing.
}

