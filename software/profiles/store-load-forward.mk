include profiles/baremetal_sources.inc

PROFILE_KIND := baremetal-store-load-forward
PROFILE_INCLUDES :=
PROFILE_CFLAGS :=
PROFILE_ASFLAGS :=
SOURCES := $(BAREMETAL_COMMON_SOURCES) applications/baremetal/store-load-forward/main.c
