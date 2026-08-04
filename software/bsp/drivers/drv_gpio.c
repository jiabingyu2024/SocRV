#include <stdint.h>
#include "soc.h"
#include "drv_gpio.h"

void gpio_set_output(uint32_t mask)
{
    mmio_write32(SOCRV_GPIO_BASE + 0x04u, mask);
}

void gpio_write(uint32_t value)
{
    mmio_write32(SOCRV_GPIO_BASE + 0x00u, value);
}

uint32_t gpio_read(void)
{
    return mmio_read32(SOCRV_GPIO_BASE + 0x08u);
}
