#include <rthw.h>
#include <rtthread.h>

#include "drv_irq.h"
#include "drv_timer.h"
#include "drv_uart.h"
#include "soc.h"

extern rt_uint8_t __heap_start;
extern rt_uint8_t __heap_end;

static void timer_irq(int vector, void *parameter)
{
    RT_UNUSED(vector);
    RT_UNUSED(parameter);
    timer_schedule_next_tick();
    rt_tick_increase();
}

static void software_irq(int vector, void *parameter)
{
    RT_UNUSED(vector);
    RT_UNUSED(parameter);
    irq_clear_software();
}

void rt_trigger_software_interrupt(void)
{
    irq_trigger_software();
}

void rt_hw_console_output(const char *text)
{
    uart_puts(text);
}

signed char rt_hw_console_getchar(void)
{
    static unsigned int idle_polls;
    char character;
    if (uart_getc_nonblocking(&character)) {
        idle_polls = 0u;
        return (signed char)character;
    }
    if (++idle_polls >= 10000u) {
        idle_polls = 0u;
        rt_thread_mdelay(1);
    }
    return (signed char)-1;
}

void rt_hw_board_init(void)
{
    uart_init();
    irq_controller_init();
    rt_system_heap_init(&__heap_start, &__heap_end);
    rt_hw_interrupt_init();
    rt_hw_interrupt_install(
        SOCRV_MCAUSE_SOFTWARE,
        software_irq,
        RT_NULL,
        "soft"
    );
    rt_hw_interrupt_install(
        SOCRV_MCAUSE_TIMER,
        timer_irq,
        RT_NULL,
        "timer"
    );
    RT_ASSERT(timer_init_tick(RT_TICK_PER_SECOND) != 0u);
    __asm volatile(
        "csrs mie, %0"
        :
        : "r"(SOCRV_MIE_SOFTWARE_MASK | SOCRV_MIE_TIMER_MASK)
        : "memory"
    );
}
