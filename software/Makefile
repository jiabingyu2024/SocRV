include toolchain/riscv_gcc.mk
include toolchain/common_flags.mk

APP ?= smoke
OUT ?= ../build/software/baremetal-$(APP)
LINKER := linker/socrv_code_data.ld
INCLUDES := -Ibsp/include

ifeq ($(APP),rtthread)
RT_ROOT := rt-thread/upstream
RT_COMMON := $(RT_ROOT)/libcpu/risc-v/common
INCLUDES += -Irt-thread/port -I$(RT_ROOT)/include -I$(RT_COMMON)
CFLAGS := $(filter-out -Werror,$(CFLAGS)) -Wno-unused-parameter -Wno-sign-compare \
	-D__RTTHREAD__ -D__RT_KERNEL_SOURCE__ -std=gnu11
SOURCES := rt-thread/port/start_rtthread.S rt-thread/port/trap_gcc.S \
	$(RT_COMMON)/context_gcc.S $(RT_COMMON)/interrupt_gcc.S \
	$(RT_COMMON)/cpuport.c $(RT_COMMON)/trap_common.c \
	$(RT_ROOT)/src/clock.c $(RT_ROOT)/src/components.c \
	$(RT_ROOT)/src/cpu_up.c $(RT_ROOT)/src/defunct.c \
	$(RT_ROOT)/src/idle.c $(RT_ROOT)/src/ipc.c $(RT_ROOT)/src/irq.c \
	$(RT_ROOT)/src/kservice.c $(RT_ROOT)/src/mem.c \
	$(RT_ROOT)/src/mempool.c $(RT_ROOT)/src/object.c \
	$(RT_ROOT)/src/scheduler_comm.c $(RT_ROOT)/src/scheduler_up.c \
	$(RT_ROOT)/src/thread.c $(RT_ROOT)/src/timer.c \
	$(RT_ROOT)/src/klibc/kerrno.c $(RT_ROOT)/src/klibc/kstdio.c \
	$(RT_ROOT)/src/klibc/kstring.c $(RT_ROOT)/src/klibc/rt_vsnprintf_tiny.c \
	rt-thread/port/board.c bsp/drivers/drv_uart.c runtime/minilibc.c \
	rt-thread/app/main.c
LDLIBS := -lgcc
else
SOURCES := startup/start.S startup/trap_entry.S startup/crt0.c \
	bsp/trap/trap.c bsp/drivers/drv_uart.c bsp/drivers/drv_gpio.c \
	runtime/platform.c baremetal/$(APP)/main.c
endif
OBJECTS := $(addprefix $(OUT)/obj/,$(SOURCES:=.o))
ELF := $(OUT)/socrv-$(APP).elf

.PHONY: all clean
all: $(ELF) $(OUT)/socrv-$(APP).bin $(OUT)/socrv-$(APP).dis $(OUT)/socrv-$(APP).size

$(OUT)/obj/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) $(INCLUDES) -c $< -o $@

$(OUT)/obj/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(ELF): $(OBJECTS) $(LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) -T$(LINKER) -Wl,-Map,$(OUT)/socrv-$(APP).map $(OBJECTS) $(LDLIBS) -o $@

$(OUT)/socrv-$(APP).bin: $(ELF)
	$(OBJCOPY) -O binary $< $@

$(OUT)/socrv-$(APP).dis: $(ELF)
	$(OBJDUMP) -d -S $< > $@

$(OUT)/socrv-$(APP).size: $(ELF)
	$(SIZE) $< | tee $@

clean:
	rm -rf $(OUT)
