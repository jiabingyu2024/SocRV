#ifndef SOCRV_SOC_H
#define SOCRV_SOC_H

#include <stdint.h>
#include "soc_config.h"
#include "soc_irq.h"
#include "soc_memory_map.h"
#include "soc_registers.h"

static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uintptr_t address)
{
    return *(volatile const uint32_t *)address;
}

static inline uint32_t soc_clock_hz(void)
{
    uint32_t clock_hz = mmio_read32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_CLOCK_HZ_OFFSET
    );

    /* Keep the generated contract as a safe fallback for simulation or an
     * older SYSCTRL implementation, while allowing one firmware source tree
     * to run correctly in both the 100 MHz bring-up and 250 MHz targets. */
    return clock_hz != 0u ? clock_hz : SOCRV_SOC_CLOCK_HZ;
}

static inline uint32_t soc_peripheral_clock_hz(void)
{
    uint32_t clock_hz = mmio_read32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_PERIPHERAL_CLOCK_HZ_OFFSET
    );

    /* A clock value outside the supported implementation range cannot be a
     * valid SYSCTRL response.  Fall back to the generated contract so an
     * early or stale MMIO sample cannot poison UART/timer/I2C divisors. */
    if (clock_hz >= 1000000u && clock_hz <= 500000000u) {
        return clock_hz;
    }
    return SOCRV_PERIPHERAL_CLOCK_HZ;
}

static inline uint32_t csr_read_mstatus(void)
{
    uint32_t value;
    __asm volatile("csrr %0, mstatus" : "=r"(value));
    return value;
}

static inline void csr_write_mstatus(uint32_t value)
{
    __asm volatile("csrw mstatus, %0" : : "r"(value) : "memory");
}

static inline uint32_t irq_save(void)
{
    uint32_t previous;
    __asm volatile("csrrc %0, mstatus, %1"
                   : "=r"(previous)
                   : "r"(1u << 3)
                   : "memory");
    return previous;
}

static inline void irq_restore(uint32_t previous)
{
    csr_write_mstatus(previous);
}

#endif
