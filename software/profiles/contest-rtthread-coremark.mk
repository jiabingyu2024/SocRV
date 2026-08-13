include profiles/rtthread_sources.inc

ifeq ($(strip $(CONTEST_ENTRY_SOURCE)),)
$(error contest-rtthread-coremark requires CONTEST_ENTRY_SOURCE)
endif
CONTEST_SOURCE_ROOT ?= $(dir $(CONTEST_ENTRY_SOURCE))

# The MSH command selects the iteration count at runtime. The competition
# driver is assumed to have the same role as upstream core_main.c; its main()
# is renamed by software/Makefile and called from command.c.
COREMARK_ITERATIONS := 10000
COREMARK_TICKS_PER_SEC := 50000000
COREMARK_FLAGS_TEXT := O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-rtthread-contest
include profiles/coremark_sources.inc

PROFILE_KIND := contest-rtthread-coremark-command
PROFILE_INCLUDES := \
	$(RTTHREAD_INCLUDES) \
	-I$(dir $(CONTEST_ENTRY_SOURCE)) \
	-I$(CONTEST_SOURCE_ROOT) \
	$(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(RTTHREAD_CFLAGS) $(COREMARK_CFLAGS)
PROFILE_ASFLAGS := -Irt-thread/port
PROFILE_ENTRY_SOURCE := $(CONTEST_ENTRY_SOURCE)
OPTIMIZATION := -O3
SOURCES := \
	$(RTTHREAD_COMMON_SOURCES) \
	$(COREMARK_SUPPORT_SOURCES) \
	applications/rtthread/shell_main.c \
	coremark/port/rtthread/command.c
