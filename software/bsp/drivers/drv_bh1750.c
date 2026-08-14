#include <rtthread.h>

#include <stdint.h>

#include "drv_bh1750.h"
#include "drv_i2c.h"

#define BH1750_POWER_ON 0x01u
#define BH1750_ONE_TIME_H_RESOLUTION 0x20u
#define BH1750_CONVERSION_DELAY_MS 180u

int bh1750_read_once(bh1750_measurement_t *measurement)
{
    const uint8_t commands[] = {
        BH1750_POWER_ON,
        BH1750_ONE_TIME_H_RESOLUTION
    };
    uint8_t sample[2];
    uint16_t raw;
    int result;

    if (measurement == RT_NULL) {
        return I2C_ERR_INVALID;
    }
    measurement->address = BH1750_DEFAULT_ADDRESS;
    measurement->raw = 0u;
    measurement->lux_x100 = 0u;

    result = i2c_master_write(
        BH1750_DEFAULT_ADDRESS,
        commands,
        sizeof(commands)
    );
    if (result != I2C_OK) {
        return result;
    }

    rt_thread_mdelay(BH1750_CONVERSION_DELAY_MS);
    result = i2c_master_read(BH1750_DEFAULT_ADDRESS, sample, sizeof(sample));
    if (result != I2C_OK) {
        return result;
    }

    raw = (uint16_t)(((uint16_t)sample[0] << 8) | sample[1]);
    measurement->raw = raw;
    measurement->lux_x100 = ((uint32_t)raw * 250u) / 3u;
    return I2C_OK;
}
