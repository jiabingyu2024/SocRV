#ifndef SOCRV_RISCV_TEST_H
#define SOCRV_RISCV_TEST_H

#include "encoding.h"

#define TESTNUM gp

#define RVTEST_RV32U                                                 \
    .macro init;                                                     \
    .endm
#define RVTEST_RV64U RVTEST_RV32U
#define RVTEST_RV32M RVTEST_RV32U
#define RVTEST_RV64M RVTEST_RV32M
#define RVTEST_RV32UF                                                \
    .macro init;                                                     \
    li t0, MSTATUS_FS;                                               \
    csrs mstatus, t0;                                                \
    csrwi fcsr, 0;                                                   \
    .endm
#define RVTEST_RV64UF RVTEST_RV32UF

#define RVTEST_CODE_BEGIN                                             \
    .section .text.init, "ax", @progbits;                             \
    .align 2;                                                         \
    .weak mtvec_handler;                                              \
    .globl _start;                                                    \
_start:                                                               \
    li TESTNUM, 0;                                                    \
    la t0, trap_vector;                                               \
    csrw mtvec, t0;                                                   \
    init;                                                             \
    j 1f;                                                             \
trap_vector:                                                          \
    la t5, mtvec_handler;                                             \
    beqz t5, unexpected_trap;                                         \
    jr t5;                                                            \
unexpected_trap:                                                      \
    li t0, 0x30002000;                                                \
    csrr t1, mcause;                                                  \
    sw t1, 4(t0);                                                     \
    li t1, 0x4641494c;                                                \
    sw t1, 0(t0);                                                     \
0:  j 0b;                                                             \
1:

#define RVTEST_CODE_END

#define RVTEST_PASS                                                   \
    li t0, 0x30002000;                                                \
    sw zero, 4(t0);                                                   \
    li t1, 0x50415353;                                                \
    sw t1, 0(t0);                                                     \
0:  j 0b;

#define RVTEST_FAIL                                                   \
    li t0, 0x30002000;                                                \
    sw TESTNUM, 4(t0);                                                \
    li t1, 0x4641494c;                                                \
    sw t1, 0(t0);                                                     \
0:  j 0b;

#define RVTEST_DATA_BEGIN                                             \
    .align 4;                                                         \
    .global begin_signature;                                         \
begin_signature:

#define RVTEST_DATA_END                                               \
    .align 4;                                                         \
    .global end_signature;                                           \
end_signature:

#endif
