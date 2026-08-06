include profiles/baremetal_sources.inc

COREMARK_ITERATIONS ?= 2000
COREMARK_TICKS_PER_SEC := 50000000
COREMARK_FLAGS_TEXT := O2-rv32i_zicsr-formal-baremetal
include profiles/coremark_sources.inc

PROFILE_KIND := coremark-baremetal-score-candidate
PROFILE_INCLUDES := $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(COREMARK_CFLAGS)
PROFILE_ASFLAGS :=
OPTIMIZATION := -O2
SOURCES := \
	$(BAREMETAL_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	coremark/port/baremetal/main.c
