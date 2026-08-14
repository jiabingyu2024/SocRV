#include <rtthread.h>

#include <stddef.h>
#include <stdint.h>

#include "drv_i2c.h"
#include "soc.h"

#define I2C_BUS_HZ 100000u
#define I2C_SOFTWARE_POLL_LIMIT 2000000u
#define I2C_CLEAR_FLAGS ( \
    SOCRV_I2C_STATUS_DONE | \
    SOCRV_I2C_STATUS_ADDR_NACK | \
    SOCRV_I2C_STATUS_DATA_NACK | \
    SOCRV_I2C_STATUS_TIMEOUT | \
    SOCRV_I2C_STATUS_ARB_LOST | \
    SOCRV_I2C_STATUS_BUS_STUCK \
)

static struct rt_mutex i2c_mutex;
static rt_bool_t mutex_initialized;
static rt_bool_t controller_initialized;

static uintptr_t i2c_register(uint32_t offset)
{
    return (uintptr_t)SOCRV_I2C_BASE + offset;
}

static uint32_t i2c_status(void)
{
    return mmio_read32(i2c_register(SOCRV_I2C_STATUS_OFFSET));
}

static int decode_status(uint32_t status)
{
    if ((status & SOCRV_I2C_STATUS_ADDR_NACK) != 0u) {
        return I2C_ERR_ADDR_NACK;
    }
    if ((status & SOCRV_I2C_STATUS_DATA_NACK) != 0u) {
        return I2C_ERR_DATA_NACK;
    }
    if ((status & SOCRV_I2C_STATUS_TIMEOUT) != 0u) {
        return I2C_ERR_TIMEOUT;
    }
    if ((status & SOCRV_I2C_STATUS_ARB_LOST) != 0u) {
        return I2C_ERR_ARB_LOST;
    }
    if ((status & SOCRV_I2C_STATUS_BUS_STUCK) != 0u) {
        return I2C_ERR_BUS_STUCK;
    }
    return I2C_OK;
}

static int wait_for_done(uint32_t *final_status)
{
    uint32_t status = 0u;
    uint32_t polls;

    for (polls = 0u; polls < I2C_SOFTWARE_POLL_LIMIT; ++polls) {
        status = i2c_status();
        if ((status & SOCRV_I2C_STATUS_BUSY) == 0u &&
            (status & SOCRV_I2C_STATUS_DONE) != 0u) {
            if (final_status != RT_NULL) {
                *final_status = status;
            }
            return decode_status(status);
        }
    }

    if (final_status != RT_NULL) {
        *final_status = status;
    }
    return I2C_ERR_TIMEOUT;
}

static int issue_command(uint32_t command)
{
    uint32_t status;

    status = i2c_status();
    if ((status & SOCRV_I2C_STATUS_BUSY) != 0u) {
        return I2C_ERR_BUSY;
    }
    mmio_write32(
        i2c_register(SOCRV_I2C_STATUS_OFFSET),
        SOCRV_I2C_STATUS_DONE
    );
    mmio_write32(i2c_register(SOCRV_I2C_COMMAND_OFFSET), command);
    return wait_for_done(RT_NULL);
}

static int write_byte(uint8_t value, rt_bool_t address_phase)
{
    uint32_t command = SOCRV_I2C_COMMAND_WRITE;

    if (address_phase) {
        command |= SOCRV_I2C_COMMAND_ADDRESS;
    }
    mmio_write32(i2c_register(SOCRV_I2C_TXDATA_OFFSET), value);
    return issue_command(command);
}

static int read_byte(uint8_t *value, rt_bool_t send_nack)
{
    uint32_t command = SOCRV_I2C_COMMAND_READ;
    int result;

    if (send_nack) {
        command |= SOCRV_I2C_COMMAND_READ_NACK;
    }
    result = issue_command(command);
    if (result == I2C_OK) {
        *value = (uint8_t)mmio_read32(
            i2c_register(SOCRV_I2C_RXDATA_OFFSET)
        );
    }
    return result;
}

static void finish_with_stop(void)
{
    (void)issue_command(SOCRV_I2C_COMMAND_STOP);
}

static int recover_bus(void)
{
    mmio_write32(i2c_register(SOCRV_I2C_STATUS_OFFSET), I2C_CLEAR_FLAGS);
    mmio_write32(
        i2c_register(SOCRV_I2C_CONTROL_OFFSET),
        SOCRV_I2C_CONTROL_ENABLE | SOCRV_I2C_CONTROL_RECOVER
    );
    return wait_for_done(RT_NULL);
}

static int lock_bus(void)
{
    int result = i2c_master_init();

    if (result != I2C_OK) {
        return result;
    }
    if (rt_mutex_take(&i2c_mutex, RT_TICK_PER_SECOND) != RT_EOK) {
        return I2C_ERR_BUSY;
    }
    return I2C_OK;
}

static void unlock_bus(void)
{
    (void)rt_mutex_release(&i2c_mutex);
}

static int begin_transaction(uint8_t address, rt_bool_t read)
{
    uint32_t status;
    int result;

    mmio_write32(i2c_register(SOCRV_I2C_STATUS_OFFSET), I2C_CLEAR_FLAGS);
    status = i2c_status();
    if ((status & SOCRV_I2C_STATUS_BUS_READY) == 0u) {
        result = recover_bus();
        if (result != I2C_OK) {
            return result;
        }
    }

    result = issue_command(SOCRV_I2C_COMMAND_START);
    if (result != I2C_OK) {
        return result;
    }
    return write_byte((uint8_t)((address << 1) | (read ? 1u : 0u)), RT_TRUE);
}

int i2c_master_init(void)
{
    uint32_t peripheral_hz;
    uint32_t divider;
    uint32_t timeout_cycles;

    if (!mutex_initialized) {
        if (rt_mutex_init(&i2c_mutex, "i2c", RT_IPC_FLAG_PRIO) != RT_EOK) {
            return I2C_ERR_BUSY;
        }
        mutex_initialized = RT_TRUE;
    }
    if (controller_initialized) {
        return I2C_OK;
    }

    peripheral_hz = soc_peripheral_clock_hz();
    if (peripheral_hz < (4u * I2C_BUS_HZ)) {
        return I2C_ERR_INVALID;
    }
    divider = peripheral_hz / (4u * I2C_BUS_HZ) - 1u;
    timeout_cycles = peripheral_hz / 100u;

    mmio_write32(
        i2c_register(SOCRV_I2C_CONTROL_OFFSET),
        SOCRV_I2C_CONTROL_ENABLE | SOCRV_I2C_CONTROL_SOFT_RESET
    );
    mmio_write32(i2c_register(SOCRV_I2C_CLOCK_DIV_OFFSET), divider);
    mmio_write32(i2c_register(SOCRV_I2C_TIMEOUT_OFFSET), timeout_cycles);
    mmio_write32(
        i2c_register(SOCRV_I2C_CONTROL_OFFSET),
        SOCRV_I2C_CONTROL_ENABLE
    );
    mmio_write32(i2c_register(SOCRV_I2C_STATUS_OFFSET), I2C_CLEAR_FLAGS);
    controller_initialized = RT_TRUE;
    return I2C_OK;
}

int i2c_master_probe(uint8_t address)
{
    int result;

    if (address > 0x7fu) {
        return I2C_ERR_INVALID;
    }
    result = lock_bus();
    if (result != I2C_OK) {
        return result;
    }
    result = begin_transaction(address, RT_FALSE);
    finish_with_stop();
    unlock_bus();
    return result;
}

int i2c_master_write(uint8_t address, const uint8_t *data, size_t length)
{
    size_t index;
    int result;

    if (address > 0x7fu || (length != 0u && data == RT_NULL)) {
        return I2C_ERR_INVALID;
    }
    result = lock_bus();
    if (result != I2C_OK) {
        return result;
    }

    result = begin_transaction(address, RT_FALSE);
    for (index = 0u; result == I2C_OK && index < length; ++index) {
        result = write_byte(data[index], RT_FALSE);
    }
    finish_with_stop();
    unlock_bus();
    return result;
}

int i2c_master_read(uint8_t address, uint8_t *data, size_t length)
{
    size_t index;
    int result;

    if (address > 0x7fu || length == 0u || data == RT_NULL) {
        return I2C_ERR_INVALID;
    }
    result = lock_bus();
    if (result != I2C_OK) {
        return result;
    }

    result = begin_transaction(address, RT_TRUE);
    for (index = 0u; result == I2C_OK && index < length; ++index) {
        result = read_byte(&data[index], index + 1u == length);
    }
    finish_with_stop();
    unlock_bus();
    return result;
}

int i2c_master_write_read(
    uint8_t address,
    const uint8_t *write_data,
    size_t write_length,
    uint8_t *read_data,
    size_t read_length
)
{
    size_t index;
    int result;

    if (address > 0x7fu || write_length == 0u || read_length == 0u ||
        write_data == RT_NULL || read_data == RT_NULL) {
        return I2C_ERR_INVALID;
    }
    result = lock_bus();
    if (result != I2C_OK) {
        return result;
    }

    result = begin_transaction(address, RT_FALSE);
    for (index = 0u; result == I2C_OK && index < write_length; ++index) {
        result = write_byte(write_data[index], RT_FALSE);
    }
    if (result == I2C_OK) {
        result = issue_command(SOCRV_I2C_COMMAND_START);
    }
    if (result == I2C_OK) {
        result = write_byte((uint8_t)((address << 1) | 1u), RT_TRUE);
    }
    for (index = 0u; result == I2C_OK && index < read_length; ++index) {
        result = read_byte(&read_data[index], index + 1u == read_length);
    }
    finish_with_stop();
    unlock_bus();
    return result;
}

const char *i2c_result_string(int result)
{
    switch (result) {
    case I2C_OK:
        return "ok";
    case I2C_ERR_INVALID:
        return "invalid";
    case I2C_ERR_BUSY:
        return "busy";
    case I2C_ERR_ADDR_NACK:
        return "addr_nack";
    case I2C_ERR_DATA_NACK:
        return "data_nack";
    case I2C_ERR_TIMEOUT:
        return "timeout";
    case I2C_ERR_ARB_LOST:
        return "arb_lost";
    case I2C_ERR_BUS_STUCK:
        return "bus_stuck";
    default:
        return "unknown";
    }
}
