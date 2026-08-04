#ifndef SOCRV_SOC_H
#define SOCRV_SOC_H

#include <stdint.h>
#include "soc_memory_map.h"

static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uintptr_t address)
{
    return *(volatile const uint32_t *)address;
}

#endif
