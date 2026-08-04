#include <stdint.h>
#include "drv_gpio.h"
#include "drv_uart.h"

int main(void)
{
    uart_init();
    gpio_set_output(0xffffu);
    gpio_write(0x5a5au);
    uart_puts("SocRV smoke PASS\n");
    uart_flush();
    return 0;
}
