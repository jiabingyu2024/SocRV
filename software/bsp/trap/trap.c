#include <stdint.h>

#include "drv_uart.h"
#include "test_status.h"
#include "trap.h"
#include "trap_frame.h"

#define MCAUSE_INTERRUPT (1u << 31)
#define MCAUSE_CODE_MASK 0x7fffffffu
#define MCAUSE_ECALL_MMODE 11u

static trap_isr_t interrupt_handlers[16];

void trap_install(uint32_t cause, trap_isr_t handler)
{
    if (cause < 16u) {
        interrupt_handlers[cause] = handler;
    }
}

static void print_hex32(uint32_t value)
{
    static const char digits[] = "0123456789abcdef";
    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_early_putc(digits[(value >> shift) & 0xfu]);
    }
}

static void trap_panic(const struct trap_frame *frame)
{
    uart_puts("SocRV trap mcause=0x");
    print_hex32(frame->mcause);
    uart_puts(" mepc=0x");
    print_hex32(frame->mepc);
    uart_puts(" mtval=0x");
    print_hex32(frame->mtval);
    uart_puts("\n");
    uart_flush();
    test_status_fail(frame->mcause);
}

void trap_handler(struct trap_frame *frame)
{
    uint32_t cause = frame->mcause & MCAUSE_CODE_MASK;
    if ((frame->mcause & MCAUSE_INTERRUPT) != 0u) {
        if (cause < 16u && interrupt_handlers[cause] != 0) {
            interrupt_handlers[cause](frame);
            return;
        }
        trap_panic(frame);
    }
    if (cause == MCAUSE_ECALL_MMODE) {
        frame->mepc += 4u;
        return;
    }
    trap_panic(frame);
}
