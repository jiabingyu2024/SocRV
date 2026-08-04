#ifndef SOCRV_DRV_GPIO_H
#define SOCRV_DRV_GPIO_H

#include <stdint.h>

void gpio_set_output(uint32_t mask);
void gpio_write(uint32_t value);
uint32_t gpio_read(void);

#endif
