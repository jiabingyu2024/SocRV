#include "drv_irq.h"
#include "soc.h"

void irq_controller_init(void)
{
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_ENABLE_OFFSET,
        0u
    );
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_PENDING_OFFSET,
        0xffffffffu
    );
    irq_clear_software();
}

uint32_t irq_pending(void)
{
    return mmio_read32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_PENDING_OFFSET
    );
}

void irq_clear(uint32_t mask)
{
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_PENDING_OFFSET,
        mask
    );
}

void irq_enable_sources(uint32_t mask)
{
    uint32_t enable = mmio_read32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_ENABLE_OFFSET
    );
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_ENABLE_OFFSET,
        enable | mask
    );
}

void irq_disable_sources(uint32_t mask)
{
    uint32_t enable = mmio_read32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_ENABLE_OFFSET
    );
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_ENABLE_OFFSET,
        enable & ~mask
    );
}

void irq_trigger_software(void)
{
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_SOFTWARE_OFFSET,
        1u
    );
}

void irq_clear_software(void)
{
    mmio_write32(
        SOCRV_IRQ_CTRL_BASE + SOCRV_IRQ_CTRL_SOFTWARE_OFFSET,
        0u
    );
}
