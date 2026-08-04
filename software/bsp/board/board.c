#include "board.h"
#include "drv_irq.h"
#include "drv_timer.h"
#include "drv_uart.h"

void board_init(void)
{
    uart_init();
    irq_controller_init();
    timer_disable_compare();
    timer_start(0);
}
