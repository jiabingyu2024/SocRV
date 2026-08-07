BAREMETAL_COMMON_SOURCES := \
	startup/start.S \
	startup/trap_entry.S \
	startup/crt0.c \
	bsp/board/board.c \
	bsp/trap/trap.c \
	bsp/drivers/drv_uart.c \
	bsp/drivers/drv_timer.c \
	bsp/drivers/drv_irq.c \
	bsp/drivers/drv_gpio.c \
	bsp/drivers/test_status.c \
	runtime/platform.c \
	runtime/minilibc.c
