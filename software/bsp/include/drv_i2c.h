#ifndef SOCRV_DRV_I2C_H
#define SOCRV_DRV_I2C_H

#include <stdbool.h>
#include <stdint.h>

enum socrv_i2c_result {
    SOCRV_I2C_OK = 0,
    SOCRV_I2C_ERR_TIMEOUT = -1,
    SOCRV_I2C_ERR_NACK = -2,
    SOCRV_I2C_ERR_NO_DATA = -3,
    SOCRV_I2C_ERR_ARGUMENT = -4
};

int socrv_i2c_init(uint32_t bus_hz);
void socrv_i2c_reset(void);
int socrv_i2c_write_byte(uint8_t value, bool start, bool stop);
int socrv_i2c_read_byte(uint8_t *value, bool nack, bool stop);

#endif
