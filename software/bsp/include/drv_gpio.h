#ifndef SOCRV_DRV_GPIO_H
#define SOCRV_DRV_GPIO_H

#include <stdint.h>

void gpio_set_output(uint32_t mask);
void gpio_write(uint32_t value);
uint32_t gpio_read(void);

/*
 * Board LED mapping: GPIO[15:0] drives virtual_led[15:0] on the FPGA board.
 * Bit indices are board-specific; adjust to the actual wiring.  Avoid bits
 * [28:31], which the board reserves for clock-lock / fault / FAIL / PASS.
 */
#define LED_COREMARK_RUN_MASK  (1u << 0)  /* lit when CoreMark starts */
#define LED_COREMARK_DONE_MASK (1u << 1)  /* lit when CoreMark finishes */

#endif
