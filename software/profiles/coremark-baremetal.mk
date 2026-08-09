include profiles/baremetal_sources.inc

COREMARK_ITERATIONS ?= 10000
COREMARK_TICKS_PER_SEC := 250000000
COREMARK_FLAGS_TEXT := O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-baremetal
include profiles/coremark_sources.inc

PROFILE_KIND := coremark-baremetal-score-candidate
PROFILE_INCLUDES := $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(COREMARK_CFLAGS)
PROFILE_ASFLAGS :=
OPTIMIZATION := -O3
SOURCES := \
	$(BAREMETAL_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	coremark/port/baremetal/main.c
