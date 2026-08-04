include profiles/rtthread_sources.inc

COREMARK_ITERATIONS ?= 1
COREMARK_TICKS_PER_SEC := 1
COREMARK_FLAGS_TEXT := O2-rv32i_zicsr-rtthread-functional
include profiles/coremark_sources.inc

PROFILE_KIND := coremark-rtthread-functional
PROFILE_INCLUDES := $(RTTHREAD_INCLUDES) $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(RTTHREAD_CFLAGS) $(COREMARK_CFLAGS)
PROFILE_ASFLAGS := -Irt-thread/port
OPTIMIZATION := -O2
SOURCES := \
	$(RTTHREAD_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	coremark/port/rtthread/main.c
