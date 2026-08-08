include profiles/baremetal_sources.inc

COREMARK_ITERATIONS ?= 2000
COREMARK_TICKS_PER_SEC := $(SOCRV_TIMER_CLOCK_HZ)
COREMARK_FLAGS_TEXT := O3-rv32imfd_zicsr_zicntr_zifencei-ilp32d-formal-baremetal
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
