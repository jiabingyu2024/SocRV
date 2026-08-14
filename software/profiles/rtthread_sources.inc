RT_ROOT := rt-thread/upstream
RTTHREAD_COMMON_SOURCES := \
	rt-thread/port/start_rtthread.S \
	rt-thread/port/trap_gcc.S \
	rt-thread/port/rtthread_crt0.c \
	rt-thread/port/context_gcc.S \
	rt-thread/port/interrupt_gcc.S \
	rt-thread/port/cpuport.c \
	rt-thread/port/trap_common.c \
	$(RT_ROOT)/src/clock.c \
	$(RT_ROOT)/src/components.c \
	$(RT_ROOT)/src/idle.c \
	$(RT_ROOT)/src/ipc.c \
	$(RT_ROOT)/src/irq.c \
	$(RT_ROOT)/src/kservice.c \
	$(RT_ROOT)/src/mem.c \
	$(RT_ROOT)/src/mempool.c \
	$(RT_ROOT)/src/object.c \
	$(RT_ROOT)/src/scheduler.c \
	$(RT_ROOT)/src/thread.c \
	$(RT_ROOT)/src/timer.c \
	$(RT_ROOT)/components/finsh/shell.c \
	$(RT_ROOT)/components/finsh/msh.c \
	$(RT_ROOT)/components/finsh/cmd.c \
	startup/crt0.c \
	rt-thread/port/board.c \
	bsp/drivers/drv_uart.c \
	bsp/drivers/drv_timer.c \
	bsp/drivers/drv_irq.c \
	bsp/drivers/drv_gpio.c \
	bsp/drivers/drv_i2c.c \
	bsp/drivers/drv_bh1750.c \
	bsp/drivers/drv_oled.c \
	bsp/drivers/test_status.c \
	runtime/platform.c \
	runtime/minilibc.c \
	applications/rtthread/commands/cmd_info.c \
	applications/rtthread/commands/cmd_sensors.c
RTTHREAD_INCLUDES := \
	-Irt-thread/port \
	-I$(RT_ROOT)/include \
	-I$(RT_ROOT)/components/finsh
# RT-Thread 3.1.5 assumes every GCC toolchain ships newlib headers.  SocRV's
# freestanding compiler uses the small compatibility headers in runtime/include.
RTTHREAD_CFLAGS := \
	-Wno-unused-parameter \
	-Wno-sign-compare \
	-Wno-implicit-fallthrough \
	-Wno-empty-body \
	-Wno-error=cast-function-type \
	-fsigned-char \
	-D__ARMCC_VERSION=0 \
	-D__RTTHREAD__ \
	-D__RT_KERNEL_SOURCE__ \
	-std=gnu11
