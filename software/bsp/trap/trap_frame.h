#ifndef SOCRV_TRAP_FRAME_H
#define SOCRV_TRAP_FRAME_H

#include <stddef.h>
#include <stdint.h>

struct trap_frame {
    uint32_t ra;
    uint32_t sp;
    uint32_t gp;
    uint32_t tp;
    uint32_t t0;
    uint32_t t1;
    uint32_t t2;
    uint32_t s0;
    uint32_t s1;
    uint32_t a0;
    uint32_t a1;
    uint32_t a2;
    uint32_t a3;
    uint32_t a4;
    uint32_t a5;
    uint32_t a6;
    uint32_t a7;
    uint32_t s2;
    uint32_t s3;
    uint32_t s4;
    uint32_t s5;
    uint32_t s6;
    uint32_t s7;
    uint32_t s8;
    uint32_t s9;
    uint32_t s10;
    uint32_t s11;
    uint32_t t3;
    uint32_t t4;
    uint32_t t5;
    uint32_t t6;
    uint32_t mepc;
    uint32_t mstatus;
    uint32_t mcause;
    uint32_t mtval;
    uint32_t reserved;
};

_Static_assert(offsetof(struct trap_frame, mepc) == 124, "trap frame mepc");
_Static_assert(offsetof(struct trap_frame, mcause) == 132, "trap frame mcause");
_Static_assert(sizeof(struct trap_frame) == 144, "trap frame size");

#endif
