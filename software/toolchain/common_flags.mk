ARCH_FLAGS := -march=rv32i_zicsr -mabi=ilp32
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
	-msmall-data-limit=0 -Wall -Wextra -Werror
CFLAGS := $(COMMON_FLAGS) -std=c11 -Os -g3
ASFLAGS := $(COMMON_FLAGS) -x assembler-with-cpp -g3
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -static -Wl,--gc-sections
