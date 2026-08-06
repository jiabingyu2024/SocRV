#include "drv_i2c.h"

#include "soc.h"

#define I2C_WAIT_LIMIT 1000000u

static uintptr_t i2c_register(uint32_t offset)
{
    return (uintptr_t)SOCRV_I2C_BASE + offset;
}

static int wait_for_completion(uint32_t *status_out)
{
    uint32_t remaining = I2C_WAIT_LIMIT;
    uint32_t status;

    do {
        status = mmio_read32(i2c_register(SOCRV_I2C_STATUS_OFFSET));
        if ((status & SOCRV_I2C_STATUS_BUSY) == 0u) {
            *status_out = status;
            return SOCRV_I2C_OK;
        }
        --remaining;
    } while (remaining != 0u);

    socrv_i2c_reset();
    return SOCRV_I2C_ERR_TIMEOUT;
}

static int execute_command(uint32_t command, uint8_t *received)
{
    uint32_t status;
    int result;

    mmio_write32(i2c_register(SOCRV_I2C_STATUS_OFFSET),
                 SOCRV_I2C_STATUS_DONE |
                 SOCRV_I2C_STATUS_ACK_ERROR |
                 SOCRV_I2C_STATUS_RX_VALID);
    mmio_write32(i2c_register(SOCRV_I2C_COMMAND_OFFSET),
                 SOCRV_I2C_COMMAND_GO | command);
    result = wait_for_completion(&status);
    if (result != SOCRV_I2C_OK) {
        return result;
    }
    if ((status & SOCRV_I2C_STATUS_ACK_ERROR) != 0u) {
        socrv_i2c_reset();
        return SOCRV_I2C_ERR_NACK;
    }
    if (received != 0) {
        if ((status & SOCRV_I2C_STATUS_RX_VALID) == 0u) {
            socrv_i2c_reset();
            return SOCRV_I2C_ERR_NO_DATA;
        }
        *received = (uint8_t)mmio_read32(
            i2c_register(SOCRV_I2C_RXDATA_OFFSET));
    }
    return SOCRV_I2C_OK;
}

int socrv_i2c_init(uint32_t bus_hz)
{
    uint32_t divider;

    if (bus_hz == 0u || bus_hz > (SOCRV_SOC_CLOCK_HZ / 2u)) {
        return SOCRV_I2C_ERR_ARGUMENT;
    }
    divider = SOCRV_SOC_CLOCK_HZ / (2u * bus_hz);
    if (divider == 0u) {
        divider = 1u;
    }
    socrv_i2c_reset();
    mmio_write32(i2c_register(SOCRV_I2C_CLKDIV_OFFSET), divider);
    return SOCRV_I2C_OK;
}

void socrv_i2c_reset(void)
{
    mmio_write32(i2c_register(SOCRV_I2C_CONTROL_OFFSET),
                 SOCRV_I2C_CONTROL_ENABLE |
                 SOCRV_I2C_CONTROL_SOFT_RESET);
    mmio_write32(i2c_register(SOCRV_I2C_CONTROL_OFFSET),
                 SOCRV_I2C_CONTROL_ENABLE);
}

int socrv_i2c_write_byte(uint8_t value, bool start, bool stop)
{
    uint32_t command = 0u;

    if (start) {
        command |= SOCRV_I2C_COMMAND_START;
    }
    if (stop) {
        command |= SOCRV_I2C_COMMAND_STOP;
    }
    mmio_write32(i2c_register(SOCRV_I2C_TXDATA_OFFSET), value);
    return execute_command(command, 0);
}

int socrv_i2c_read_byte(uint8_t *value, bool nack, bool stop)
{
    uint32_t command = SOCRV_I2C_COMMAND_READ;

    if (value == 0) {
        return SOCRV_I2C_ERR_ARGUMENT;
    }
    if (nack) {
        command |= SOCRV_I2C_COMMAND_NACK;
    }
    if (stop) {
        command |= SOCRV_I2C_COMMAND_STOP;
    }
    return execute_command(command, value);
}
