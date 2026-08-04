#ifndef SOCRV_DRV_UART_H
#define SOCRV_DRV_UART_H

void uart_init(void);
void uart_early_putc(char character);
void uart_putc(char character);
void uart_puts(const char *text);
int uart_getc_nonblocking(char *character);
char uart_getc(void);
void uart_enable_rx_irq(int enable);
void uart_flush(void);

#endif
