ARCH_FLAGS := -march=rv32imf_zicsr -mabi=ilp32f
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
	-msmall-data-limit=0 -Wall -Wextra -Werror
OPTIMIZATION ?= -O3
EXTRA_OPT_FLAGS ?=
CFLAGS := $(COMMON_FLAGS) -std=c11 $(OPTIMIZATION) $(EXTRA_OPT_FLAGS) -g3
ASFLAGS := $(COMMON_FLAGS) -x assembler-with-cpp -g3
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -static -Wl,--gc-sections
