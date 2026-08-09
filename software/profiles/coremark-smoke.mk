include profiles/baremetal_sources.inc

COREMARK_ITERATIONS := 1
COREMARK_TICKS_PER_SEC := 1
COREMARK_FLAGS_TEXT := O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-functional-smoke
include profiles/coremark_sources.inc

PROFILE_KIND := coremark-baremetal-functional
PROFILE_INCLUDES := $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(COREMARK_CFLAGS)
PROFILE_ASFLAGS :=
OPTIMIZATION := -O3
SOURCES := \
	$(BAREMETAL_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	coremark/port/baremetal/main.c
