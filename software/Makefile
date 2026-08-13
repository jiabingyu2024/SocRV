include toolchain/riscv_gcc.mk

PROFILE ?= smoke
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

PROFILE_ENTRY_SOURCE ?=
PROFILE_ENTRY_OBJECT :=
ifneq ($(strip $(PROFILE_ENTRY_SOURCE)),)
PROFILE_ENTRY_OBJECT := $(OUT)/objects/contest/core_main.c.o
endif
OBJECTS := $(addprefix $(OUT)/objects/,$(SOURCES:=.o)) $(PROFILE_ENTRY_OBJECT)
DEPFILES := $(OBJECTS:.o=.d)
BUILD_CONFIG_FILES := $(MAKEFILE_LIST)
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

$(OUT)/objects/coremark/upstream/core_main.c.o: coremark/upstream/core_main.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -Dmain=coremark_main -MMD -MP -c $< -o $@

ifneq ($(strip $(PROFILE_ENTRY_SOURCE)),)
$(PROFILE_ENTRY_OBJECT): $(PROFILE_ENTRY_SOURCE)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -Dmain=coremark_main -MMD -MP -c $< -o $@
endif

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
	@printf '%s\n' $(SOURCES) $(PROFILE_ENTRY_SOURCE)

print-flags:
	@printf '%s\n' '$(CFLAGS)'

print-kind:
	@printf '%s\n' '$(PROFILE_KIND)'

-include $(DEPFILES)
