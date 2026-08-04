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
