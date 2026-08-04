    .section .text
    .align 2
    .globl trap_entry
    .type trap_entry, @function
trap_entry:
    addi sp, sp, -16
    sw ra, 12(sp)
    csrr a0, mcause
    csrr a1, mepc
    call trap_handler
1:
    j 1b
    .size trap_entry, . - trap_entry
