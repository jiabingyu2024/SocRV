#include <stdint.h>

#include "drv_timer.h"
#include "soc.h"
#include "trap.h"

static volatile uint32_t timer_interrupts;

static void timer_handler(struct trap_frame *frame)
{
    (void)frame;
    ++timer_interrupts;
    timer_disable_compare();
}

int main(void)
{
    uint32_t timeout = 1000000u;

    /* The common trap handler must advance mepc and return from an M-mode ecall. */
    __asm volatile("ecall" : : : "memory");

    trap_install(SOCRV_MCAUSE_TIMER, timer_handler);
    if (timer_init_tick(1000u) == 0u) {
        return 1;
    }
    __asm volatile(
        "csrs mie, %0\n"
        "csrs mstatus, %1"
        :
        : "r"(SOCRV_MIE_TIMER_MASK), "r"(1u << 3)
        : "memory"
    );

    while (timer_interrupts == 0u && timeout-- != 0u) {
        __asm volatile("nop");
    }

    return timer_interrupts == 1u ? 0 : 2;
}
