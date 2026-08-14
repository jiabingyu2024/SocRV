#ifndef SOCRV_DRV_I2C_H
#define SOCRV_DRV_I2C_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
    I2C_OK = 0,
    I2C_ERR_INVALID = -1,
    I2C_ERR_BUSY = -2,
    I2C_ERR_ADDR_NACK = -3,
    I2C_ERR_DATA_NACK = -4,
    I2C_ERR_TIMEOUT = -5,
    I2C_ERR_ARB_LOST = -6,
    I2C_ERR_BUS_STUCK = -7
} i2c_result_t;

int i2c_master_init(void);
int i2c_master_probe(uint8_t address);
int i2c_master_write(uint8_t address, const uint8_t *data, size_t length);
int i2c_master_read(uint8_t address, uint8_t *data, size_t length);
int i2c_master_write_read(
    uint8_t address,
    const uint8_t *write_data,
    size_t write_length,
    uint8_t *read_data,
    size_t read_length
);
const char *i2c_result_string(int result);

#endif
