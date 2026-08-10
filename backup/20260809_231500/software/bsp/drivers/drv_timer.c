#include "drv_timer.h"
#include "soc.h"

static uint64_t next_deadline;
static uint64_t tick_delta;

uint64_t timer_read(void)
{
    uint32_t high_before;
    uint32_t low;
    uint32_t high_after;
    do {
        high_before = mmio_read32(
            SOCRV_TIMER_BASE + SOCRV_TIMER_MTIME_HI_OFFSET
        );
        low = mmio_read32(
            SOCRV_TIMER_BASE + SOCRV_TIMER_MTIME_LO_OFFSET
        );
        high_after = mmio_read32(
            SOCRV_TIMER_BASE + SOCRV_TIMER_MTIME_HI_OFFSET
        );
    } while (high_before != high_after);
    return ((uint64_t)high_after << 32) | low;
}

void timer_set_compare(uint64_t deadline)
{
    mmio_write32(
        SOCRV_TIMER_BASE + SOCRV_TIMER_MTIMECMP_HI_OFFSET,
        0xffffffffu
    );
    mmio_write32(
        SOCRV_TIMER_BASE + SOCRV_TIMER_MTIMECMP_LO_OFFSET,
        (uint32_t)deadline
    );
    mmio_write32(
        SOCRV_TIMER_BASE + SOCRV_TIMER_MTIMECMP_HI_OFFSET,
        (uint32_t)(deadline >> 32)
    );
}

void timer_disable_compare(void)
{
    timer_set_compare(UINT64_MAX);
}

void timer_start(int irq_enable)
{
    uint32_t control = SOCRV_TIMER_CONTROL_MTIME_ENABLE;
    if (irq_enable) {
        control |= SOCRV_TIMER_CONTROL_IRQ_ENABLE;
    }
    mmio_write32(
        SOCRV_TIMER_BASE + SOCRV_TIMER_CONTROL_OFFSET,
        control
    );
}

uint64_t timer_init_tick(uint32_t tick_hz)
{
    if (tick_hz == 0u || (SOCRV_TIMER_CLOCK_HZ % tick_hz) != 0u) {
        return 0u;
    }
    tick_delta = SOCRV_TIMER_CLOCK_HZ / tick_hz;
    next_deadline = timer_read() + tick_delta;
    timer_set_compare(next_deadline);
    timer_start(1);
    return tick_delta;
}

uint64_t timer_schedule_next_tick(void)
{
    next_deadline += tick_delta;
    timer_set_compare(next_deadline);
    return next_deadline;
}
