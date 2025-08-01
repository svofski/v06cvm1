#include <inttypes.h>
#include <string.h>
#include <stdio.h>
#include <vector>
#include <algorithm>

#include "memory.h"
#include "i8080.h"

using namespace std;

Memory::Memory() : mode_stack(false), mode_map(false), page_map(0),
    page_stack(0)
{
    memset(bytes, 0, sizeof(bytes));
    //printf("memory init\n");
}

// Barkar extensions:
//
// 1 = enable
//
// 7              screen 0    0xe000-0xffff  8k
//  6             screen 3    0x8000-0x9fff  8k
//   5            screen 1-2  0xa000-0xdfff  16k  default Kishinev version
//    4           stack
//     32         stack page
//       10       screen page
void Memory::control_write(uint8_t w8)
{
    this->mode_stack = (w8 & 0x10) != 0;
    this->mode_map = w8 & 0xe0;

    this->page_map = ((w8 & 3) + 1) << 16;
    this->page_stack = (((w8 & 0xc) >> 2) + 1) << 16;

    //printf("memory: raw=%02x mode_stack=%x mode_map=%02x page_map=%x page_stack=%x\n",
    //        w8, this->mode_stack, this->mode_map, this->page_map, this->page_stack);
}

uint32_t Memory::bigram_select(uint32_t addr, bool stackrq) const
{
    uint8_t map = this->mode_map;
    bool stack = this->mode_stack;
    if (!(map || stack)) {
        return addr;
    } else if (stack && stackrq) {
        return addr + this->page_stack;
    } else if ((map & 0x20) && (addr >= 0xa000) && (addr <= 0xdfff)) {
        return addr + this->page_map;
    } else if ((map & 0x40) && (addr >= 0x8000) && (addr <= 0x9fff)) {
        return addr + this->page_map;
    } else if ((map & 0x80) && (addr >= 0xe000) && (addr <= 0xffff)) {
        return addr + this->page_map;
    }

    return addr;
}

uint32_t Memory::tobank(uint32_t a)
{
    return (a & 0x78000) | ((a<<2)&0x7ffc) | ((a>>13)&3);
}

uint8_t Memory::read(uint32_t addr, bool stackrq, const bool _is_opcode) const
{
    uint8_t value;
    uint32_t phys = addr;

    uint32_t bigaddr = this->bigram_select(addr & 0xffff, stackrq);
    if (this->bootbytes.size() && bigaddr < this->bootbytes.size()) {
        value = this->bootbytes[bigaddr];
    } 
    else {
        phys = Memory::tobank(bigaddr);
        value = this->bytes[phys];
    }

#ifndef NOSCRIPT
    if (this->onread) this->onread(addr, phys, stackrq, value);
#endif

#ifndef NODEBUGGER
    if (debug_onread) 
    {
        debug_onread(bigaddr, value, _is_opcode);
    }
#endif

    //if (bigaddr > 0xffff)
    //    printf("read(%05x)->%02x\n", bigaddr, value);

    return value;
}

uint8_t Memory::get_byte(uint32_t addr, bool stackrq) const
{
    uint8_t value;
    uint32_t phys = addr;

    uint32_t bigaddr = this->bigram_select(addr & 0xffff, stackrq);
    if (this->bootbytes.size() && bigaddr < this->bootbytes.size()) {
        value = this->bootbytes[bigaddr];
    } 
    else {
        phys = Memory::tobank(bigaddr);
        value = this->bytes[phys];
    }

    return value;
}

void Memory::write(uint32_t addr, uint8_t w8, bool stackrq)
{
    uint32_t bigaddr = this->bigram_select(addr & 0xffff, stackrq);

    //if (bigaddr > 0xffff) {
    //    fprintf(stderr, "himem[%05x]<-%02x ", bigaddr, w8);
    //}

    uint32_t phys = Memory::tobank(bigaddr);
#ifndef NOSCRIPT
    if (this->onwrite) {
        this->onwrite(addr, phys, stackrq, w8);
    }
#endif
    this->bytes[phys] = w8;
#ifndef NOHEATMAP
    if (bigaddr < this->heatmap.size()) {
        //this->heatmap[phys] = std::clamp(this->heatmap[phys] + 64, 0, 255);
        this->heatmap[bigaddr] = 255;
    }
#endif 
#ifndef NODEBUGGER
    if (debug_onwrite) debug_onwrite(bigaddr, w8);
#endif
    if (bigaddr > 0xffff)
        fprintf(stderr, "write(%05x)->%02x\n", bigaddr, w8);
}

void Memory::init_from_vector(const vector<uint8_t> & from, uint32_t start_addr)
{
    // clear the main ram because otherwise switching roms is a pain
    // but leave the kvaz alone
    if (start_addr < 65536) {
        memset(this->bytes, 0, 65536);
    }
    else {
        memset(this->bytes + start_addr, 0, sizeof(bytes) - start_addr);
    }
    for (unsigned i = 0; i < from.size(); ++i) {
        int addr = start_addr + i;
        //this->write(addr, from[i], false);
        uint32_t phys = Memory::tobank(addr);
        if (phys < sizeof(this->bytes)) {
            this->bytes[phys] = from[i];
        }
    }
}

void Memory::attach_boot(vector<uint8_t> boot)
{
    this->bootbytes = boot;
}

void Memory::detach_boot()
{
    this->bootbytes.clear();
}

uint8_t * Memory::buffer() 
{
    return bytes;
}

#include "serialize.h"

void Memory::serialize(std::vector<uint8_t> &to) {
    std::vector<uint8_t> tmp;
    tmp.push_back((uint8_t)mode_stack);
    tmp.push_back((uint8_t)mode_map);
    tmp.push_back((uint8_t)(page_map>>16));
    tmp.push_back((uint8_t)(page_stack>>16));
    tmp.push_back(sizeof(this->bytes)/65536); // normally 1+4, but we could get many ramdisks later
    tmp.insert(std::end(tmp), this->bytes, this->bytes + sizeof(this->bytes));
    tmp.insert(std::end(tmp), std::begin(this->bootbytes), std::end(this->bootbytes));

    SerializeChunk::insert_chunk(to, SerializeChunk::MEMORY, tmp);
}

void Memory::deserialize(std::vector<uint8_t>::iterator it, uint32_t size)
{
    auto begin = it;
    this->mode_stack = (bool) *it++;
    this->mode_map = (uint8_t) *it++;
    this->page_map = ((uint32_t) *it++) << 16;
    this->page_stack = ((uint32_t) *it++) << 16;
    uint32_t stored_ramsize = 65536 * *it++;
    size_t nbytes = std::min(stored_ramsize, (uint32_t)sizeof(this->bytes));
    std::copy(it, it + nbytes, this->bytes);
    it += stored_ramsize;

    this->bootbytes.clear();
    this->bootbytes.assign(it, begin + size);
}

#ifndef NOHEATMAP
void Memory::cool_off_heatmap()
{
    for (auto it = heatmap.begin(); it < heatmap.end(); ++it) {
        //if (*it > 0) printf("%04x %02x\n ", it - heatmap.begin(), *it);
        int i = *it;
        if (i > 64) {
            *it -= 10;
        }
        else {
            *it = std::clamp(static_cast<int>(*it) - 5, 0, 255);
        }
    }
}
#endif

void Memory::export_bytes(uint8_t * dst, uint32_t addr, uint32_t size) const
{
    for (uint32_t i = 0; i < size; ++i) {
        dst[i] = this->bytes[Memory::tobank(addr + i)];
    }
}


auto Memory::get_mode_stack() const -> const bool
{
    return mode_stack;
}

auto Memory::get_mode_map() const -> const uint8_t
{
    return mode_map;
}

auto Memory::get_page_map() const -> const uint32_t
{
    return page_map>>16 - 1;
}

auto Memory::get_page_stack() const -> const uint32_t
{
    return page_stack>>16 - 1;
}
