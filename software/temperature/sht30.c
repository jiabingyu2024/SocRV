#include "sht30.h"

#include <rtthread.h>

#include "drv_i2c.h"

#define SHT30_ADDRESS_LOW  0x44u
#define SHT30_ADDRESS_HIGH 0x45u
#define SHT30_COMMAND_MSB  0x24u
#define SHT30_COMMAND_LSB  0x00u
#define SHT30_I2C_HZ       100000u

static uint8_t active_address = SHT30_ADDRESS_LOW;

static uint8_t crc8(const uint8_t *data, unsigned length)
{
    uint8_t crc = 0xffu;
    unsigned byte_index;
    unsigned bit_index;

    for (byte_index = 0; byte_index < length; ++byte_index) {
        crc ^= data[byte_index];
        for (bit_index = 0; bit_index < 8u; ++bit_index) {
            crc = (crc & 0x80u) != 0u
                ? (uint8_t)((crc << 1) ^ 0x31u)
                : (uint8_t)(crc << 1);
        }
    }
    return crc;
}

static int read_from_address(uint8_t address, int32_t *temperature_mc)
{
    uint8_t data[6];
    uint16_t raw_temperature;
    unsigned index;
    int result;

    result = socrv_i2c_write_byte((uint8_t)(address << 1), true, false);
    if (result != SOCRV_I2C_OK) {
        return result;
    }
    result = socrv_i2c_write_byte(SHT30_COMMAND_MSB, false, false);
    if (result != SOCRV_I2C_OK) {
        socrv_i2c_reset();
        return result;
    }
    result = socrv_i2c_write_byte(SHT30_COMMAND_LSB, false, true);
    if (result != SOCRV_I2C_OK) {
        socrv_i2c_reset();
        return result;
    }

    rt_thread_mdelay(20);
    result = socrv_i2c_write_byte((uint8_t)((address << 1) | 1u),
                                  true,
                                  false);
    if (result != SOCRV_I2C_OK) {
        return result;
    }
    for (index = 0; index < sizeof(data); ++index) {
        bool last = index == (sizeof(data) - 1u);
        result = socrv_i2c_read_byte(&data[index], last, last);
        if (result != SOCRV_I2C_OK) {
            socrv_i2c_reset();
            return result;
        }
    }

    if (crc8(&data[0], 2u) != data[2] ||
        crc8(&data[3], 2u) != data[5]) {
        return SHT30_ERR_CRC;
    }
    raw_temperature = (uint16_t)(((uint16_t)data[0] << 8) | data[1]);
    *temperature_mc = -45000 +
        (int32_t)(((int64_t)175000 * raw_temperature) / 65535);
    active_address = address;
    return SHT30_OK;
}

int sht30_init(void)
{
    active_address = SHT30_ADDRESS_LOW;
    return socrv_i2c_init(SHT30_I2C_HZ) == SOCRV_I2C_OK
        ? SHT30_OK
        : SHT30_ERR_I2C;
}

int sht30_read_millicelsius(int32_t *temperature_mc)
{
    int result;

    if (temperature_mc == 0) {
        return SHT30_ERR_I2C;
    }
    result = read_from_address(active_address, temperature_mc);
    if (result == SOCRV_I2C_ERR_NACK &&
        active_address == SHT30_ADDRESS_LOW) {
        result = read_from_address(SHT30_ADDRESS_HIGH, temperature_mc);
    }
    return result == SOCRV_I2C_OK || result == SHT30_ERR_CRC
        ? result
        : SHT30_ERR_I2C;
}

uint8_t sht30_address(void)
{
    return active_address;
}
