ARCH_FLAGS := -march=rv32imfd_zicsr_zicntr_zifencei_zbkb -mabi=ilp32d
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
	-msmall-data-limit=0 -Wall -Wextra -Werror
OPTIMIZATION ?= -O3
CFLAGS := $(COMMON_FLAGS) -std=c11 $(OPTIMIZATION) -g3
ASFLAGS := $(COMMON_FLAGS) -x assembler-with-cpp -g3
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -static -Wl,--gc-sections
