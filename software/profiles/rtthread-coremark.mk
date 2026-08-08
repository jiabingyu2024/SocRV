include profiles/rtthread_sources.inc

# The command selects the iteration count at runtime. This compile-time value
# only initializes CoreMark before the FinSH command overrides it.
COREMARK_ITERATIONS := 10000
COREMARK_TICKS_PER_SEC := $(SOCRV_TIMER_CLOCK_HZ)
COREMARK_FLAGS_TEXT := O3-rv32imfd_zicsr_zicntr_zifencei-ilp32d-rtthread-command
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
