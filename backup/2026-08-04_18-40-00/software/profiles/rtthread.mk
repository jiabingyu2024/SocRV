include profiles/rtthread_sources.inc

PROFILE_KIND := rtthread
PROFILE_INCLUDES := $(RTTHREAD_INCLUDES)
PROFILE_CFLAGS := $(RTTHREAD_CFLAGS)
PROFILE_ASFLAGS := -Irt-thread/port
SOURCES := $(RTTHREAD_COMMON_SOURCES) applications/rtthread/main.c
