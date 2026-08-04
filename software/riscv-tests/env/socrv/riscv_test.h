#ifndef SOCRV_RISCV_TEST_H
#define SOCRV_RISCV_TEST_H

#define TESTNUM gp

#define RVTEST_RV32U
#define RVTEST_RV64U RVTEST_RV32U

#define RVTEST_CODE_BEGIN                                             \
    .section .text.init, "ax", @progbits;                             \
    .align 2;                                                         \
    .globl _start;                                                    \
_start:                                                               \
    li TESTNUM, 0;                                                    \
    la t0, trap_vector;                                               \
    csrw mtvec, t0;                                                   \
    j 1f;                                                             \
trap_vector:                                                          \
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
