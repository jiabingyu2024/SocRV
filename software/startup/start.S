    .section .text.start
    .globl _start
    .type _start, @function
_start:
    csrci mstatus, 8
    csrw mie, zero
    csrw mscratch, zero
    /* mstatus.FS=Initial before any hard-float C code executes. */
    li t0, 0x2000
    csrs mstatus, t0
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop
    la sp, __stack_top
    la t0, trap_entry
    csrw mtvec, t0
    call crt0
1:
    j 1b
    .size _start, . - _start
