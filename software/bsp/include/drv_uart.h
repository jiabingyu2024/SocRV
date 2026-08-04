#ifndef SOCRV_DRV_UART_H
#define SOCRV_DRV_UART_H

void uart_init(void);
void uart_putc(char character);
void uart_puts(const char *text);
void uart_flush(void);

#endif
