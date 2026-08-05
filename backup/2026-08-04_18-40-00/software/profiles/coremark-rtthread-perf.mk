include profiles/rtthread_sources.inc

# A bounded multi-iteration simulation profile. COREMARK_TICKS_PER_SEC remains
# synthetic so the upstream functional validation path runs in a practical
# simulation time. Harness statistics use the real 50 MHz SoC clock.
COREMARK_ITERATIONS := 10
COREMARK_TICKS_PER_SEC := 1
COREMARK_FLAGS_TEXT := O2-rv32i_zicsr-rtthread-sim-perf-10it
include profiles/coremark_sources.inc

PROFILE_KIND := coremark-rtthread-performance-simulation
PROFILE_INCLUDES := $(RTTHREAD_INCLUDES) $(COREMARK_INCLUDES)
PROFILE_CFLAGS := $(RTTHREAD_CFLAGS) $(COREMARK_CFLAGS)
PROFILE_ASFLAGS := -Irt-thread/port
OPTIMIZATION := -O2
SOURCES := \
	$(RTTHREAD_COMMON_SOURCES) \
	$(COREMARK_SOURCES) \
	coremark/port/rtthread/main.c
