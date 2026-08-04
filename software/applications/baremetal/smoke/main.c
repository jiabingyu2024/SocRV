#include <stdint.h>

#include "drv_gpio.h"
#include "drv_uart.h"

static volatile uint32_t initialized_data = 0x13579bdfu;
static volatile uint32_t cleared_bss;

int main(void)
{
    uart_init();
    if (initialized_data != 0x13579bdfu || cleared_bss != 0u) {
        return 2;
    }
    gpio_set_output(0xffffu);
    gpio_write(0x5a5au);
    uart_puts("SocRV smoke PASS\n");
    uart_flush();
    return 0;
}
