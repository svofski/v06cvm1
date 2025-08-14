//
// This is a testbench executing i8080 code.
// It is custom-tailored to debug PDP-11/06C PDP-11 emulator for Vector-06c
//
// Implements a partial CP/M stub and frame interrupts.
//
// Requires vm1_opcodes.h, which is automatically generated from TASM symbols
// by opcodes.awk
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <termios.h>

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

#include "vm1_opcodes.h"    // see opcodes.awk

FILE * trace = NULL;        // set to stderr to trace every pdp-11 instruction and more

typedef enum {
    ATTR_HOST,
    ATTR_GUEST,
} attr_mode_t;

attr_mode_t attrmode = ATTR_HOST;

void attr_host()
{
#ifdef COLOR
    trace && fprintf(trace, "\033[0m");
#endif
}

void attr_guest()
{
#ifdef COLOR
    trace && fprintf(trace, "\033[93m"); // light yellow
#endif
}

void attr_reg()
{
#ifdef COLOR
    trace && fprintf(trace, "\033[96m"); // light cyan
#endif
}

void attr_psw()
{
#ifdef COLOR
    trace && fprintf(trace, "\033[97m"); // light blue
#endif
}

void attr_diff(int differ)
{
#ifdef COLOR
    if (differ) {
        trace && fprintf(trace, "\033[48;5;94m");
    }
    else {
        trace && fprintf(trace, "\033[49m");
    }
#endif
}

extern uint16_t DisassembleInstruction(const uint16_t* pMemory, uint16_t addr, 
        char* strInstr, char* strArg);

void kvaz(int on)
{
    if (on) {
#ifdef WITH_KVAZ
        i8080_hal_io_output(0x10, 0x10);
#endif
    }
    else {
#ifdef WITH_KVAZ
        i8080_hal_io_output(0x10, 0x0);
#endif
    }
}



void load_file(const char* name, int addr, int kvas)
{
    FILE* f = fopen(name, "r+b");

    static uint8_t buffer[65536];
    uint8_t * load_to = &buffer[0];

    int sz;
    if (!f) {
        trace && fprintf(trace, "Unable to open file \"%s\"\n", name);
        exit(1);
    }
    sz = 0;
    while (!feof(f)) {
        int const read = fread((void *)load_to, 1, 1024, f);
        if (read == 0) break;
        sz += read;
        load_to += read;
    }
    trace && fprintf(trace, "\n*********************************\n");
    trace && fprintf(trace, "File \"%s\" loaded, size %d\n", name, sz);

    kvaz(kvas);

    for (size_t n = 0; n < sz; ++n) {
        i8080_hal_memory_write_byte(n + addr, buffer[n], kvas);
    }

    kvaz(0);
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


// message ff
// ret number of bytes
// base base addr
// guest = 0: print cp/m memory, guest = 1 print pdp-11 memory
void dump(const char * ff, size_t ret, uint16_t base = 0, int guest = 1)
{
    kvaz(guest);
    trace && fprintf(trace, "%s: %s %lu bytes\n", guest ? "PDP-11" : "CP/M", ff, ret);
    for (int i = 0; i < ret + 16; i += 16) {
        trace && fprintf(trace, "%04x ", i);
        for (int j = 0; j < 16; ++j) {
            if (i + j < ret) {
                trace && fprintf(trace, "%02x%c", i8080_hal_memory_read_byte(base+i+j, true), j == 7 ? '-' : ' ');
            }
            else {
                trace && fprintf(trace, "   ");
            }
        }
        trace && fprintf(trace, "  ");
        for (int j = 0; j < 16; ++j) {
            if (i + j < ret) {
                int c = i8080_hal_memory_read_byte(base+i+j, true);
                trace && fprintf(trace, "%c", (c >= 0x20 && c < 0x7f) ? c : '.');
            }
            else {
                trace && fprintf(trace, " ");
            }
        }
        trace && fprintf(trace, "\n");
    }
    kvaz(0);
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

    trace && fprintf(trace, "H: succesfully opened tun/tap %s\n", devtap);
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
        trace && fprintf(trace, "input buffer overrun, packet dropped\n");
    }

    //trace && fprintf(trace, "received packet, rxbuf size=%d\n", tap->rxbuf_size);

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
            //trace && fprintf(trace, "\nRXBUF empty, POPPED=%d\n", bytesread);
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
            trace && fprintf(trace, "tap_write_data: sending out\n");
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
    //trace && fprintf(trace, ": opcode=%06o\n", code);
    for (int i = 0; i < n; ++i) {
        //trace && fprintf(trace, ": opc_code=%06o opc_mask=%06o  code&mask=%06o\n",
        //        opc_codes[i], opc_masks[i], code & opc_masks[i]);
        if (opc_codes[i] == (code & opc_masks[i])) {
            return i;
        }
    }

    return -1;
}

uint16_t get_guest_reg(int n)
{
    return i8080_hal_memory_read_word(vm1_regfile_addr + n * 2);
}

void print_regs()
{
    static uint16_t prev_regs[9];

    attr_reg();
    for (int i = 0; i < 9; ++i) {
        if (i == 8) {
            attr_psw();
        }
        else {
            attr_reg();
        }
        uint16_t reg = get_guest_reg(i);
        attr_diff(reg != prev_regs[i]);
        trace && fprintf(trace, "%06o ", reg);
        prev_regs[i] = reg;
    }

    attr_host();

    uint16_t psw = get_guest_reg(8);

    char flags[] = "HP..TNZVC";
    for (int i = 0; i <= 8; ++i) {
        if ((psw & 1) == 0) flags[8 - i] = '.';
        psw >>= 1;
    }
    trace && fprintf(trace, " %s ", flags);

}

const uint16_t fcb1_addr = 0x5c;
const int CPM_RECORD_SZ = 128;
const int CPM_DMA_ADDR = 0x80;

typedef struct
{
    uint8_t drive;
    uint8_t name[8];
    uint8_t ext[3];
    uint8_t ex;        // extent
    uint8_t s1;
    uint8_t s2;
    uint8_t rc;        // record count
    uint8_t d0dn[16];
    uint8_t cr;        // current record
    uint8_t ra[3];     // RA record
} fcb_struct_t;

typedef union {
    fcb_struct_t fcb;
    uint8_t bytes[36];
} fcb_t;

FILE * cpm_files[2];

void get_fcb(int addr, fcb_t * fcb)
{
    for (int i = 0; i < sizeof(fcb_t); ++i) {
        fcb->bytes[i] = i8080_hal_memory_read_byte(addr + i);
    }
}

void bdos_fopen()
{
    // fcb1 at $5c, filename is 8+3 
    fcb_t fcb;
    get_fcb(fcb1_addr, &fcb);

    char filename[13]{};
    int pos = 0;
    for (int i = 0; i < 8 && fcb.fcb.name[i] > ' '; ++i) {
        filename[pos++] = fcb.fcb.name[i];
    }
    filename[pos++] = '.';
    for (int i = 0; i < 8 && fcb.fcb.ext[i] > ' '; ++i) {
        filename[pos++] = fcb.fcb.ext[i];
    }
    filename[pos++] = 0;

    cpm_files[0] = fopen(filename, "r");
    if (cpm_files[0] == NULL) {
        trace && fprintf(trace, "bdos_open: open error, filename=%s\n", filename);
    }
    i8080_setreg_a(2);
}

void bdos_fclose()
{
    if (cpm_files[0]) {
        fclose(cpm_files[0]);
    }
    i8080_setreg_a(2);
}

void bdos_readrand()
{
    fcb_t fcb;
    get_fcb(fcb1_addr, &fcb);

    uint32_t offset = CPM_RECORD_SZ * (fcb.fcb.ra[0] | (fcb.fcb.ra[1] << 8) | (fcb.fcb.ra[2] << 16));
    int result = fseek(cpm_files[0], offset, SEEK_SET);
    if (result < 0) {
        i8080_setreg_a(0xff);
        return;
    }

    for (int i = 0, c = 0; i < CPM_RECORD_SZ; ++i) {
        c = fgetc(cpm_files[0]);
        if (c < 0) {
            i8080_setreg_a(0xff);
            return;
        }
        i8080_hal_memory_write_byte(CPM_DMA_ADDR + i, c);
    }

    trace && fprintf(trace, "\nLOADED SECTOR T:%02d S:%02d ofs=%06x ", 
            i8080_hal_memory_read_byte(rxdrv_track_addr),
            i8080_hal_memory_read_byte(rxdrv_sector_addr),
            offset);
    dump("", 128, 0x0080, 0);

    i8080_setreg_a(0);
}

struct termios oldt, newt;

void restore_console()
{
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    trace && fprintf(trace, "restored console mode\n");
}

void console_raw()
{
    // Save old terminal settings
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;

    // Disable canonical mode and echo
    newt.c_lflag &= ~(ICANON | ECHO);
    newt.c_cc[VMIN] = 0;   // Return immediately if no data
    newt.c_cc[VTIME] = 0;  // No timeout

    tcsetattr(STDIN_FILENO, TCSANOW, &newt);

    // Set stdin to non-blocking
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    atexit(restore_console);

    trace && fprintf(trace, "entered raw console mode\n");
}

void conio_test()
{
    uint8_t ch;
    while (1) {
        ssize_t n = read(STDIN_FILENO, &ch, 1);
        if (n == 1) {
            printf("You pressed: %c (%u)\n", ch, ch);
            fflush(stdout);
            if (ch == 'q') break;
        }
        usleep(100000); // Sleep 100ms to avoid busy CPU
    }
}



ssize_t console_n = 0;
uint8_t console_ch = 0;

void check_console()
{
    if (console_n == 0) {
        console_n = read(STDIN_FILENO, &console_ch, 1);
    }
}

uint8_t read_console()
{
    if (console_n == 0) {
        check_console();
    }
    uint8_t result = console_ch;
    console_ch = 0;
    console_n = 0;
    return result;
}

void bdos(int * success)
{
    int i, c;

    switch (i8080_regs_c()) {
        case 2: // putchar
        case 4:
            attr_guest();
            putchar((char)i8080_regs_e());
            attr_host();
            fflush(stdout);
            break;
        case 6: // console input
            c = read_console();
            i8080_setreg_a(c);
            break;
        case 9: // print $-terminated string
            attr_guest();
            for (i = i8080_regs_de(); (c = i8080_hal_memory_read_byte(i)) != '$'; i += 1)
                putchar(c);
            *success = 1;
            fflush(stdout);
            attr_host();
            break;
        case 11: // C_STAT console status
            check_console();
            i8080_setreg_a(console_n ? 1 : 0);
            i8080_setreg_l(console_n ? 1 : 0);
            break;
        case 15: // F_OPEN
            bdos_fopen();
            break;
        case 16: // F_CLOSE
            bdos_fclose();
            break;
        case 33: // F_READRAND
            bdos_readrand();
            break;
    }
}


void execute_test(const char* filename, int success_check) {
    //unsigned char* mem = i8080_hal_memory();
    int success = 0;

    char instr_buf[9];
    char arg_buf[33];

    load_file(filename, 0x100, 0);  // load runtime under test

    //tap_init(&tapdev, "/dev/net/tun", &mem[0x8000], &mem[0x9000]);
    //tap_init(&tapdev, "/dev/net/tun", &mem[0x8000], &mem[0x8000]);

    // call 5 -> 0x8888
    i8080_hal_memory_write_byte(5,   0xc3);
    i8080_hal_memory_write_byte(5+1, 0x88);
    i8080_hal_memory_write_byte(5+2, 0x88);

    // rst7 -> 0x8889
    i8080_hal_memory_write_byte(0x38,   0xc3);
    i8080_hal_memory_write_byte(0x38+1, 0x89);
    i8080_hal_memory_write_byte(0x38+2, 0x88);

    i8080_hal_memory_write_byte(0x8888, 0xC9);  // ret from call 5
    i8080_hal_memory_write_byte(0x8889, 0xC9);  // ret from rst7

    i8080_hal_memory_write_byte(0x5d, ' ');  // empty fcb1
    i8080_hal_memory_write_byte(0x6d, ' ');  // empty fcb2

    i8080_init();
    i8080_jump(0x100);
    uint64_t cycles = 0, int_cycles = 0;

    while (1) {
        //tap_loop(&tapdev, cycles);

        int const pc = i8080_pc();
        //fprintf(stdout, "PC=%04x %02x %02x %02x [%04x]=%04x\n", pc,
        //        i8080_hal_memory_read_byte(pc), 
        //        i8080_hal_memory_read_byte(pc+1), 
        //        i8080_hal_memory_read_byte(pc+2),
        //        i8080_regs_sp(),
        //        i8080_hal_memory_read_word(i8080_regs_sp())
        //        );
        if (i8080_hal_memory_read_byte(pc) == 0x76 || i8080_hal_memory_read_byte(pc) == 0xc7) {
            trace && fprintf(trace, "\nHLT at %04X Total: %lu cycles. ", pc, cycles);
            trace && fprintf(trace, "A=%02x BC=%04x DE=%04x HL=%04x SP=%04x\n",
                    i8080_regs_a(),
                    i8080_regs_bc(), i8080_regs_de(), i8080_regs_hl(), i8080_regs_sp());

            dump("mem", 512);
            return;
        }

        if (pc == vm1_exec_addr) {
            uint16_t pc = get_guest_reg(7);
            uint16_t insnbuf[3];
            kvaz(1);
            for (int i = 0; i < 3; ++i) {
                insnbuf[i] = i8080_hal_memory_read_word(pc + i * 2, true);
            }
            kvaz(0);
            DisassembleInstruction(insnbuf, pc, 
                    instr_buf, arg_buf);
            trace && fprintf(trace, "\n%06o: %-8s%-32s", pc, instr_buf, arg_buf);

            print_regs();


#ifdef BENCHMARK
            if (pc == 000210) {
                printf("\nBENCHMARK tarp at 000210; Total: %lu cycles. ", cycles);
                return;
            }
#endif
        }

        int opc = find_in_opcode_handlers(pc);
        if (opc != -1) {
#ifdef EXAMINE_OPCODE_HANDLERS
            int executed_opcode = i8080_hal_memory_read_word(vm1_opcode_addr);
            const char * label = opc_labels[opc];

            trace && fprintf(trace, "opc: %06o %-8s @%04x", executed_opcode, label, opc_addrs[opc]);

            int index = find_opcode_index(executed_opcode);
            if (index >= 0 && strcmp(label+4, opc_names[index]) == 0) {
                //trace && fprintf(trace, " OK\n");
            }
            else {
                trace && fprintf(trace, " ERROR: expected opcode %o %s, actual label: %s\n",
                        executed_opcode, opc_names[index], label);
            }
#endif

            uint16_t rx11csr = i8080_hal_memory_read_word(rxdrv_csr_addr);
            uint8_t rcsr = i8080_hal_memory_read_byte(rx_control_reg_addr);
            uint8_t xcsr = i8080_hal_memory_read_byte(tx_control_reg_addr);

            trace && fprintf(trace, "rx csr: %06o rcsr: %03o xcsr: %03o", rx11csr, rcsr, xcsr);
        }

        if (pc == 0x8888) {
            bdos(&success);
        }

        int instr_cycles = i8080_instruction();
        cycles += instr_cycles;
        int_cycles += instr_cycles;
        // cycles are not v06c-aligned by why not use 59904 as a lucky number anyway
        if (int_cycles > 59904) {
            int_cycles -= 59904;
            if (i8080_iff()) {
                instr_cycles = i8080_execute(0xff); // rst7
                cycles += instr_cycles;
            }
        }
    }


}

int main(int argc, char **argv) {
    const char * filename = "vm1.com";

    console_raw();

    if (argc > 1) {
        filename = argv[1];
    }

#ifdef TEST_791401
    load_file("bktests/791401", 0, 1);  // load bk test into guest ram
#endif
#ifdef BASIC
    load_file("bktests/013-basic.bin", 0140000, 1);  // load bk test into guest ram
#endif
#ifdef TEST_GKAAA0
    load_file("bktests/GKAAA0", 0, 1);  // load GKAAA0 at address 0, start 0200
#endif
    execute_test(filename, 0);
    return 0;
}
