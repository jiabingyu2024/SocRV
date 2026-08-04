#include <stdint.h>
#include "soc.h"
#include "drv_uart.h"

void uart_init(void)
{
    mmio_write32(
        SOCRV_UART_BASE + SOCRV_UART_DIVISOR_OFFSET,
        SOCRV_UART_DIVISOR
    );
    mmio_write32(
        SOCRV_UART_BASE + SOCRV_UART_CONTROL_OFFSET,
        0u
    );
}

void uart_early_putc(char character)
{
    while ((mmio_read32(
                SOCRV_UART_BASE + SOCRV_UART_STATUS_OFFSET
            ) & SOCRV_UART_STATUS_TX_READY) == 0u) {
    }
    mmio_write32(
        SOCRV_UART_BASE + SOCRV_UART_TXDATA_OFFSET,
        (uint8_t)character
    );
}

void uart_putc(char character)
{
    uart_early_putc(character);
}

void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc(*text++);
    }
}

int uart_getc_nonblocking(char *character)
{
    uint32_t status = mmio_read32(
        SOCRV_UART_BASE + SOCRV_UART_STATUS_OFFSET
    );
    if ((status & SOCRV_UART_STATUS_RX_VALID) == 0u) {
        return 0;
    }
    *character = (char)mmio_read32(
        SOCRV_UART_BASE + SOCRV_UART_RXDATA_OFFSET
    );
    return 1;
}

char uart_getc(void)
{
    char character;
    while (!uart_getc_nonblocking(&character)) {
    }
    return character;
}

void uart_enable_rx_irq(int enable)
{
    mmio_write32(
        SOCRV_UART_BASE + SOCRV_UART_CONTROL_OFFSET,
        enable ? SOCRV_UART_CONTROL_RX_IRQ_ENABLE : 0u
    );
}

void uart_flush(void)
{
    while ((mmio_read32(
                SOCRV_UART_BASE + SOCRV_UART_STATUS_OFFSET
            ) & SOCRV_UART_STATUS_TX_EMPTY) == 0u) {
    }
}
