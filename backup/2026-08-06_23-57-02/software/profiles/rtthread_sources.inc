RT_ROOT := rt-thread/upstream
RT_COMMON := $(RT_ROOT)/libcpu/risc-v/common
RTTHREAD_COMMON_SOURCES := \
	rt-thread/port/start_rtthread.S \
	rt-thread/port/trap_gcc.S \
	rt-thread/port/rtthread_crt0.c \
	$(RT_COMMON)/context_gcc.S \
	$(RT_COMMON)/interrupt_gcc.S \
	$(RT_COMMON)/cpuport.c \
	$(RT_COMMON)/trap_common.c \
	$(RT_ROOT)/src/clock.c \
	$(RT_ROOT)/src/components.c \
	$(RT_ROOT)/src/cpu_up.c \
	$(RT_ROOT)/src/defunct.c \
	$(RT_ROOT)/src/idle.c \
	$(RT_ROOT)/src/ipc.c \
	$(RT_ROOT)/src/irq.c \
	$(RT_ROOT)/src/kservice.c \
	$(RT_ROOT)/src/mem.c \
	$(RT_ROOT)/src/mempool.c \
	$(RT_ROOT)/src/object.c \
	$(RT_ROOT)/src/scheduler_comm.c \
	$(RT_ROOT)/src/scheduler_up.c \
	$(RT_ROOT)/src/thread.c \
	$(RT_ROOT)/src/timer.c \
	$(RT_ROOT)/src/klibc/kerrno.c \
	$(RT_ROOT)/src/klibc/kstdio.c \
	$(RT_ROOT)/src/klibc/kstring.c \
	$(RT_ROOT)/src/klibc/rt_vsnprintf_tiny.c \
	$(RT_ROOT)/components/finsh/shell.c \
	$(RT_ROOT)/components/finsh/msh.c \
	$(RT_ROOT)/components/finsh/msh_parse.c \
	$(RT_ROOT)/components/finsh/cmd.c \
	startup/crt0.c \
	rt-thread/port/board.c \
	bsp/drivers/drv_uart.c \
	bsp/drivers/drv_timer.c \
	bsp/drivers/drv_irq.c \
	bsp/drivers/test_status.c \
	runtime/platform.c \
	runtime/minilibc.c \
	applications/rtthread/commands/cmd_info.c
RTTHREAD_INCLUDES := \
	-Irt-thread/port \
	-I$(RT_ROOT)/include \
	-I$(RT_COMMON) \
	-I$(RT_ROOT)/components/finsh
RTTHREAD_CFLAGS := \
	-Wno-unused-parameter \
	-Wno-sign-compare \
	-Wno-error=cast-function-type \
	-D__RTTHREAD__ \
	-D__RT_KERNEL_SOURCE__ \
	-std=gnu11
