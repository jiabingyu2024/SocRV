#ifndef SOCRV_DRV_BH1750_H
#define SOCRV_DRV_BH1750_H

#include <stdint.h>

#define BH1750_DEFAULT_ADDRESS 0x23u

typedef struct {
    uint8_t address;
    uint16_t raw;
    uint32_t lux_x100;
} bh1750_measurement_t;

int bh1750_read_once(bh1750_measurement_t *measurement);

#endif
