#include "drv_irq.h"
#include "soc.h"

void irq_controller_init(void)
{
    irq_clear_software();
}

uint32_t irq_pending(void)
{
    return mmio_read32(SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_SOFTWARE_IRQ_OFFSET)
           & 1u;
}

void irq_clear(uint32_t mask)
{
    if ((mask & 1u) != 0u) {
        irq_clear_software();
    }
}

void irq_enable_sources(uint32_t mask)
{
    (void)mask;
}

void irq_disable_sources(uint32_t mask)
{
    (void)mask;
}

void irq_trigger_software(void)
{
    mmio_write32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_SOFTWARE_IRQ_OFFSET,
        1u
    );
}

void irq_clear_software(void)
{
    mmio_write32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_SOFTWARE_IRQ_OFFSET,
        0u
    );
}
