include profiles/rtthread_sources.inc

# The command selects the iteration count at runtime. This compile-time value
# only initializes CoreMark before the FinSH command overrides it.
COREMARK_ITERATIONS := 10000
COREMARK_TICKS_PER_SEC := 50000000
COREMARK_FLAGS_TEXT := -O3 -march=rv32imf_zicsr -mabi=ilp32f
include profiles/coremark_sources.inc

PROFILE_KIND := rtthread-coremark-command
PROFILE_INCLUDES := $(RTTHREAD_INCLUDES) $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(RTTHREAD_CFLAGS) $(COREMARK_CFLAGS)
PROFILE_ASFLAGS := -Irt-thread/port
OPTIMIZATION := -O3
SOURCES := \
	$(RTTHREAD_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	applications/rtthread/shell_main.c \
	coremark/port/rtthread/command.c
