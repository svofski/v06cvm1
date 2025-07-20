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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_tun.h>

#include "i8080.h"
#include "i8080_hal.h"

#include "vm1_opcodes.h"

typedef enum {
    ATTR_HOST,
    ATTR_GUEST,
} attr_mode_t;

attr_mode_t attrmode = ATTR_HOST;

void attr_host()
{
    printf("\033[0m");
}

void attr_guest()
{
    printf("\033[93m"); // light yellow
}

void attr_reg()
{
    printf("\033[96m"); // light cyan
}

void attr_psw()
{
    printf("\033[97m"); // light blue
}

void attr_diff(int differ)
{
    if (differ) {
        printf("\033[48;5;94m");
    }
    else {
        printf("\033[49m");
    }
}

extern uint16_t DisassembleInstruction(const uint16_t* pMemory, uint16_t addr, 
        char* strInstr, char* strArg);

void load_file(const char* name, unsigned char* load_to) {
    FILE* f = fopen(name, "r+b");
    int sz;
    if (!f) {
        fprintf(stderr, "Unable to open file \"%s\"\n", name);
        exit(1);
    }
    sz = 0;
    while (!feof(f)) {
        int const read = fread((void *)load_to, 1, 1024, f);
        if (read == 0) break;
        sz += read;
        load_to += read;
    }
    printf("\n*********************************\n");
    printf("File \"%s\" loaded, size %d\n", name, sz);
}

void trace_zpu(unsigned char * mem)
{
    uint16_t zpc = i8080_regs_sp();
    uint16_t zsp = i8080_regs_bc();

    printf("ZPC: %04x insn=%02x ZSP: %04x -> ", zpc, mem[zpc], zsp);
    for (int i = 0; i < 6; ++i) {
        for (int j = 0; j < 4; ++j) {
            printf("%02x", mem[zsp + i*4 + j]);
        }
        printf(" ");
    }
    printf("\n");
}


// tap_t::csr bit values
#define TAP_INIT         1
#define TAP_RX_DONE      2
#define TAP_TX_DONE      4
#define TAP_TX_START     8
#define TAP_RX_READY    16

#define UIP_CONF_BUFFER_SIZE 1024

#define RINGBUF_SIZE 65536

typedef struct {
    int fd;
    uint8_t rxbuf[RINGBUF_SIZE];
    uint8_t txbuf[UIP_CONF_BUFFER_SIZE];

    int watchdog;
    uint8_t csr;

    int rxbuf_head;
    int rxbuf_tail;
    int rxbuf_size;

    int tx_state;
    uint16_t tx_len;
    int txbuf_ofs;

    int readstate;
} tap_t;

tap_t tapdev;

void tap_send(tap_t * tap);

void dump(const char * ff, uint8_t * buf, size_t ret)
{
    printf("HOST: %s %lu bytes\n", ff, ret);
    for (int i = 0; i < ret + 16; i += 16) {
        for (int j = 0; j < 16; ++j) {
            if (i + j < ret) {
                printf("%02x%c", buf[i+j], j == 7 ? '-' : ' ');
            }
            else {
                printf("   ");
            }
        }
        printf("  ");
        for (int j = 0; j < 16; ++j) {
            if (i + j < ret) {
                int c = buf[i+j];
                printf("%c", (c >= 0x20 && c < 0x7f) ? c : '.');
            }
            else {
                printf(" ");
            }
        }
        printf("\n");
    }
}

void tap_init(tap_t * tap, const char * devtap, uint8_t * rxbuf, uint8_t * txbuf)
{
    tap->fd = open(devtap, O_RDWR);
    if (tap->fd == -1) {
        perror("tapdev: unable to open device, networking disabled");
        return;
    }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, "tap0", sizeof(ifr.ifr_name));
    ifr.ifr_name[sizeof(ifr.ifr_name)-1] = 0; /* ensure \0 termination */

    ifr.ifr_flags = IFF_TAP|IFF_NO_PI;
    if (ioctl(tap->fd, TUNSETIFF, (void *) &ifr) < 0) {
        perror("tapif_init: ioctl TUNSETIFF, networking disabled");
        close(tap->fd);
        tap->fd = -1;
        return;
    }

    tap->rxbuf_head = tap->rxbuf_tail = tap->rxbuf_size = 0;

    tap->tx_state = tap->tx_len = tap->txbuf_ofs = tap->readstate = 0;

    printf("H: succesfully opened tun/tap %s\n", devtap);
}

void tap_rx_push(tap_t * tap, uint8_t b)
{
    assert(tap->rxbuf_head < RINGBUF_SIZE);
    tap->rxbuf[tap->rxbuf_head++] = b;
    if (tap->rxbuf_head == RINGBUF_SIZE) {
        tap->rxbuf_head = 0;
    }
    ++tap->rxbuf_size;
}

uint8_t tap_rx_pop(tap_t * tap)
{
    assert(tap->rxbuf_size > 0);
    uint8_t retval = tap->rxbuf[tap->rxbuf_tail++];
    if (tap->rxbuf_tail == RINGBUF_SIZE) {
        tap->rxbuf_tail = 0;
    }
    --tap->rxbuf_size;
    return retval;
}

unsigned tap_poll(tap_t * tap)
{
    if (tap->fd == -1) return 0;

    fd_set fdset;
    struct timeval tv, now;
    int ret;

    tv.tv_sec = 0;
    tv.tv_usec = 0;

    FD_ZERO(&fdset);
    FD_SET(tap->fd, &fdset);

    ret = select(tap->fd + 1, &fdset, NULL, NULL, &tv);
    if(ret == 0) {
        return 0;
    }
    uint8_t bufak[1500];
    ret = read(tap->fd, &bufak[0], sizeof(bufak));

    if(ret == -1) {
        perror("tap_dev: tapdev_read: read");
    }

    //dump("read", bufak, ret);

    // if i sits i fits
    if (tap->rxbuf_size + 2 + ret < RINGBUF_SIZE) {
        tap_rx_push(tap, ret >> 8);
        tap_rx_push(tap, ret & 255);

        for (int i = 0; i < ret; ++i) {
            tap_rx_push(tap, bufak[i]);
        }
    }
    else {
        printf("input buffer overrun, packet dropped\n");
    }

    //printf("received packet, rxbuf size=%d\n", tap->rxbuf_size);

    return ret;
}

int bytesread = 0;

uint8_t tap_read_data(tap_t * tap)
{
    uint8_t retval = 0;
    if (tap->readstate) --tap->readstate;
    if (tap->readstate) return 0;

    if (tap->rxbuf_size > 0) {
        retval = tap_rx_pop(tap);
        ++bytesread;
        if (tap->rxbuf_size == 0) {
            //printf("\nRXBUF empty, POPPED=%d\n", bytesread);
            bytesread = 0;
        }
    }
    else {
        tap->readstate = 2;
    }
    return retval;
}

void tap_write_data(tap_t * tap, uint8_t c)
{
    if (tap->tx_state == 0) {
        tap->tx_len = c << 8;
        tap->tx_state = 1;
    }
    else if (tap->tx_state == 1) {
        tap->tx_len |= c;
        tap->txbuf_ofs = 0;
        tap->tx_state = 2;
        if (tap->tx_len > UIP_CONF_BUFFER_SIZE) {
            tap->tx_len = UIP_CONF_BUFFER_SIZE;
        }

    }
    else if (tap->tx_state == 2) {
        tap->txbuf[tap->txbuf_ofs++] = c;

        if (tap->txbuf_ofs == tap->tx_len) {
            printf("tap_write_data: sending out\n");
            tap_send(tap);
            tap->tx_len = tap->txbuf_ofs = tap->tx_state = 0;
        }
    }
}

void tap_send(tap_t * tap)
{
    int ret;

    if (tap->fd == -1) return;

    //dump("send", tap->txbuf, tap->tx_len);

    ret = write(tap->fd, &tap->txbuf[0], tap->tx_len);
    if(ret == -1) {
        perror("tap_dev: tapdev_send: write");
        exit(1);
    }
}

void tap_loop(tap_t * tap, uint64_t cycle)
{
    if (cycle % 59904 == 0) {
        tap_poll(tap);
    }
}

void i8080_hal_io_output(int port, int value)
{
    switch (port) {
        case 0x05:
            tapdev.csr |= value;
            break;
        case 0x06:
            tap_write_data(&tapdev, value);
            break;
    }
}

int i8080_hal_io_input(int port)
{
    int ret = 0;
    switch (port) {
        case 0x05:
            return tapdev.csr;
        case 0x07:
            ret = tap_read_data(&tapdev);
            //printf("[%02x]", ret);
            return ret;
    }
    return 0;
}

//#define SPEED_FACTOR 128
#define SPEED_FACTOR (1<<31)

int find_in_opcode_handlers(int pc)
{
    const int nopc = (int)(sizeof(opc_addrs)/sizeof(opc_addrs[0]));
    for (int i = 0; i < nopc; ++i) {
        if (opc_addrs[i] == pc) {
            return i;
        }
    }

    return -1;
}

int find_opcode_index(int code)
{
    const int n = (int)(sizeof(opc_codes)/sizeof(opc_codes[0]));
    //printf(": opcode=%06o\n", code);
    for (int i = 0; i < n; ++i) {
        //printf(": opc_code=%06o opc_mask=%06o  code&mask=%06o\n",
        //        opc_codes[i], opc_masks[i], code & opc_masks[i]);
        if (opc_codes[i] == (code & opc_masks[i])) {
            return i;
        }
    }

    return -1;
}

void print_regs()
{
    unsigned char* mem = i8080_hal_memory();

    static uint16_t prev_regs[9];

    attr_reg();
    for (int i = 0; i < 9; ++i) {
        if (i == 8) {
            attr_psw();
        }
        else {
            attr_reg();
        }
        uint16_t reg = mem[vm1_regfile_addr + i * 2] | (mem[vm1_regfile_addr + i * 2 + 1] << 8);
        attr_diff(reg != prev_regs[i]);
        printf("%06o ", reg);
        prev_regs[i] = reg;
    }
    attr_host();
}

uint16_t get_guest_reg(int n)
{
    unsigned char* mem = i8080_hal_memory();
    return mem[vm1_regfile_addr + n * 2] | (mem[vm1_regfile_addr + n * 2 + 1] << 8);
}

void execute_test(const char* filename, int success_check) {
    unsigned char* mem = i8080_hal_memory();
    int success = 0;

    char instr_buf[9];
    char arg_buf[33];

    memset(mem, 0, 0x10000);
    mem[5] = 0xc3;
    mem[6] = 0x00;
    mem[7] = 0xc0;

    load_file(filename, mem + 0x100);

    //tap_init(&tapdev, "/dev/net/tun", &mem[0x8000], &mem[0x9000]);
    //tap_init(&tapdev, "/dev/net/tun", &mem[0x8000], &mem[0x8000]);

    mem[5] = 0xC9;  // Inject RET at 0x0005 to handle "CALL 5".
    i8080_init();
    i8080_jump(0x100);
    uint64_t cycles = 0;

    int kukol = SPEED_FACTOR;

    while (1) {
        //tap_loop(&tapdev, cycles);

        int const pc = i8080_pc();
        if (mem[pc] == 0x76 || mem[pc] == 0xc7) {
            printf("HLT at %04X Total: %lu cycles\n", pc, cycles);

            dump("mem", mem, 256);
            return;
        }

        if (pc == vm1_exec_addr) {
            uint16_t pc = get_guest_reg(7);
            DisassembleInstruction((const uint16_t *)&mem[pc], pc, 
                    instr_buf, arg_buf);
            printf("\n%06o: %-8s%-32s", pc, instr_buf, arg_buf);

            print_regs();
        }

        int opc = find_in_opcode_handlers(pc);
        if (opc != -1) {
            int executed_opcode = mem[vm1_opcode_addr] | (mem[vm1_opcode_addr+1] << 8);
            const char * label = opc_labels[opc];

            printf("opc: %06o %-8s @%04x", executed_opcode, label, opc_addrs[opc]);

            int index = find_opcode_index(executed_opcode);
            if (index >= 0 && strcmp(label+4, opc_names[index]) == 0) {
                //printf(" OK\n");
            }
            else {
                printf(" ERROR: expected opcode %o %s, actual label: %s\n",
                        executed_opcode, opc_names[index], label);
            }

        }

        //if (mem[pc] == 0xd3) {
        //    printf("out %d = %02x\n", mem[pc+1], i8080_regs_a());
        //}

        //if (pc == 0x6db3) {
        //    printf("write HL=%04X\n", i8080_regs_hl());
        //}

        if (pc == 0x0005) {
            // handle basic BDOS calls
            if (i8080_regs_c() == 9) {  // print string
                int i;
                attr_guest();
                for (i = i8080_regs_de(); mem[i] != '$'; i += 1)
                    putchar(mem[i]);
                success = 1;
                fflush(stdout);
                attr_host();
            }
            else if (i8080_regs_c() == 2) { // putchar
                attr_guest();
                putchar((char)i8080_regs_e());
                attr_host();
                fflush(stdout);
            }
        }

        // ZPU PC trace
        //if (mem[i8080_pc()] == 0xe1) {
        //    trace_zpu(mem);
        //}

        int instr_cycles = i8080_instruction();

        cycles += instr_cycles;
        kukol -= instr_cycles;
        if (kukol <= 0) {
            kukol += SPEED_FACTOR;
            usleep(1);
        }
        //if (i8080_pc() == 0) {
        //    printf("\nJump to 0000 from %04X\n", pc);
        //    if (success_check && !success)
        //        exit(1);
        //    return;
        //}
    }


}

int main(int argc, char **argv) {
    const char * filename = "vm1.com";

    if (argc > 1) {
        filename = argv[1];
    }

    execute_test(filename, 0);
    return 0;
}
