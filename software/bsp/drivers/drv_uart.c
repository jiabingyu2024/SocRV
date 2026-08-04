#include <stdint.h>
#include "soc.h"
#include "drv_uart.h"

enum {
    UART_TXDATA = 0x00,
    UART_STATUS = 0x08,
    UART_DIVISOR = 0x0c,
    UART_STATUS_TX_READY = 1u << 8,
    UART_STATUS_TX_EMPTY = 1u << 9
};

void uart_init(void)
{
    mmio_write32(SOCRV_UART_BASE + UART_DIVISOR, 434u);
}

void uart_putc(char character)
{
    while ((mmio_read32(SOCRV_UART_BASE + UART_STATUS) & UART_STATUS_TX_READY) == 0u) {
    }
    mmio_write32(SOCRV_UART_BASE + UART_TXDATA, (uint8_t)character);
}

void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc(*text++);
    }
}

void uart_flush(void)
{
    while ((mmio_read32(SOCRV_UART_BASE + UART_STATUS) & UART_STATUS_TX_EMPTY) == 0u) {
    }
}
