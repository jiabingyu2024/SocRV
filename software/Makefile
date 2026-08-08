include toolchain/riscv_gcc.mk

PROFILE ?= smoke
PYTHON ?= python3
OUT ?= ../build/software/$(PROFILE)
LINKER := linker/socrv_code_data.ld
PROFILE_FILE := profiles/$(PROFILE).mk

ifeq ($(wildcard $(PROFILE_FILE)),)
$(error unknown software PROFILE '$(PROFILE)')
endif

include $(PROFILE_FILE)
include toolchain/common_flags.mk

INCLUDES := -Iruntime/include -Ibsp/include -Ibsp/trap $(PROFILE_INCLUDES)
CFLAGS += $(PROFILE_CFLAGS)
ASFLAGS += $(PROFILE_ASFLAGS)
LDLIBS += -lgcc

OBJECTS := $(addprefix $(OUT)/objects/,$(SOURCES:=.o))
DEPFILES := $(OBJECTS:.o=.d)
BUILD_CONFIG_FILES := $(MAKEFILE_LIST)
XMAC16 ?= 1
ELF := $(OUT)/firmware.elf
MAP := $(OUT)/firmware.map
DIS := $(OUT)/firmware.dis
BIN := $(OUT)/firmware.bin
SIZE_TXT := $(OUT)/size.txt

.PHONY: all clean print-sources print-flags print-kind
all: $(ELF) $(BIN) $(DIS) $(SIZE_TXT)

# Compiler/profile changes affect every object even when the C/assembly source
# itself is unchanged. Track all parsed make fragments so switching ISA,
# optimization, profile macros, or source lists cannot silently reuse stale
# objects from an earlier software contract.
$(OBJECTS): $(BUILD_CONFIG_FILES)

$(OUT)/objects/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) $(ASFLAGS) $(INCLUDES) -MMD -MP -c $< -o $@

$(OUT)/objects/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -MMD -MP -c $< -o $@

ifeq ($(XMAC16),1)
# Keep the benchmark source pristine: compile its generic matrix C to assembly,
# fuse proven arithmetic DAGs, then assemble the result.
$(OUT)/objects/coremark/upstream/core_matrix.c.o: coremark/upstream/core_matrix.c ../scripts/fuse_xmac16_asm.py
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -MMD -MP -S $< -o $@.base.s
	$(PYTHON) ../scripts/fuse_xmac16_asm.py $@.base.s $@.xmac.s
	$(CC) $(ASFLAGS) -c $@.xmac.s -o $@
endif

$(OUT)/objects/coremark/upstream/core_main.c.o: coremark/upstream/core_main.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -Dmain=coremark_main -MMD -MP -c $< -o $@

$(ELF): $(OBJECTS) $(LINKER) linker/memory.ldh
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) -T$(LINKER) -Wl,-Map,$(MAP) $(OBJECTS) $(LDLIBS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(DIS): $(ELF)
	$(OBJDUMP) -d -S $< > $@

$(SIZE_TXT): $(ELF)
	$(SIZE) -A $< | tee $@

clean:
	rm -rf $(OUT)

print-sources:
	@printf '%s\n' $(SOURCES)

print-flags:
	@printf '%s\n' '$(CFLAGS)'

print-kind:
	@printf '%s\n' '$(PROFILE_KIND)'

-include $(DEPFILES)
