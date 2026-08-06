#ifndef SOCRV_SHT30_H
#define SOCRV_SHT30_H

#include <stdint.h>

enum sht30_result {
    SHT30_OK = 0,
    SHT30_ERR_I2C = -10,
    SHT30_ERR_CRC = -11
};

int sht30_init(void);
int sht30_read_millicelsius(int32_t *temperature_mc);
uint8_t sht30_address(void);

#endif
