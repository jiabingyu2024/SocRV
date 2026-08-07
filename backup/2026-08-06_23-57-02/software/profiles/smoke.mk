include profiles/baremetal_sources.inc

PROFILE_KIND := baremetal
PROFILE_INCLUDES :=
PROFILE_CFLAGS :=
PROFILE_ASFLAGS :=
SOURCES := $(BAREMETAL_COMMON_SOURCES) applications/baremetal/smoke/main.c
