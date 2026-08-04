#include <rthw.h>
#include <rtthread.h>

#include "soc.h"
#include "drv_uart.h"

#define TIMER_MTIME_LO      (SOCRV_TIMER_BASE + 0x00u)
#define TIMER_MTIME_HI      (SOCRV_TIMER_BASE + 0x04u)
#define TIMER_MTIMECMP_LO   (SOCRV_TIMER_BASE + 0x08u)
#define TIMER_MTIMECMP_HI   (SOCRV_TIMER_BASE + 0x0cu)
#define TIMER_CONTROL       (SOCRV_TIMER_BASE + 0x10u)
#define IRQ_SOFTWARE        (SOCRV_IRQ_CTRL_BASE + 0x08u)
#define SOC_CLOCK_HZ        50000000u

extern rt_uint8_t _heap_start;
extern rt_uint8_t _heap_end;

static rt_uint64_t timer_read(void)
{
    rt_uint32_t high_before;
    rt_uint32_t low;
    rt_uint32_t high_after;
    do {
        high_before = mmio_read32(TIMER_MTIME_HI);
        low = mmio_read32(TIMER_MTIME_LO);
        high_after = mmio_read32(TIMER_MTIME_HI);
    } while (high_before != high_after);
    return ((rt_uint64_t)high_after << 32) | low;
}

static void timer_schedule_next(void)
{
    rt_uint64_t next = timer_read() + SOC_CLOCK_HZ / RT_TICK_PER_SECOND;
    mmio_write32(TIMER_MTIMECMP_HI, 0xffffffffu);
    mmio_write32(TIMER_MTIMECMP_LO, (rt_uint32_t)next);
    mmio_write32(TIMER_MTIMECMP_HI, (rt_uint32_t)(next >> 32));
}

static void timer_irq(int vector, void *parameter)
{
    RT_UNUSED(vector);
    RT_UNUSED(parameter);
    timer_schedule_next();
    rt_tick_increase();
}

static void software_irq(int vector, void *parameter)
{
    RT_UNUSED(vector);
    RT_UNUSED(parameter);
    mmio_write32(IRQ_SOFTWARE, 0u);
}

void rt_trigger_software_interrupt(void)
{
    mmio_write32(IRQ_SOFTWARE, 1u);
}

void rt_hw_console_output(const char *text)
{
    uart_puts(text);
}

void rt_hw_board_init(void)
{
    uart_init();
    rt_system_heap_init(&_heap_start, &_heap_end);
    rt_hw_interrupt_init();
    rt_hw_interrupt_install(3, software_irq, RT_NULL, "soft");
    rt_hw_interrupt_install(7, timer_irq, RT_NULL, "timer");
    timer_schedule_next();
    mmio_write32(TIMER_CONTROL, 3u);
    __asm volatile("csrs mie, %0" : : "r"((1u << 3) | (1u << 7)));
}
