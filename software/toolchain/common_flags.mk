ARCH_FLAGS := -march=$(SOCRV_MARCH) -mabi=$(SOCRV_MABI)
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
	-msmall-data-limit=0 -Wall -Wextra -Werror
OPTIMIZATION ?= -O3
CFLAGS := $(COMMON_FLAGS) -std=c11 $(OPTIMIZATION) -g3
ASFLAGS := $(COMMON_FLAGS) -x assembler-with-cpp -g3
LDFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -static -Wl,--gc-sections
