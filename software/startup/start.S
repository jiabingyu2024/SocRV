    .section .text.start
    .globl _start
    .type _start, @function
_start:
    csrci mstatus, 8
    la sp, _stack_top
    la t0, trap_entry
    csrw mtvec, t0
    call crt0
1:
    j 1b
    .size _start, . - _start
