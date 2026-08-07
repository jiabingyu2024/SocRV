#ifndef SOCRV_CORE_PORTME_H
#define SOCRV_CORE_PORTME_H

#include <stddef.h>
#include <stdint.h>

#define HAS_FLOAT 0
#define HAS_TIME_H 0
#define USE_CLOCK 0
#define HAS_STDIO 0
#define HAS_PRINTF 0

#define COMPILER_VERSION "GCC " __VERSION__
#ifndef FLAGS_STR
#define FLAGS_STR "unrecorded"
#endif
#define COMPILER_FLAGS FLAGS_STR
#define MEM_LOCATION "STATIC"

typedef int16_t ee_s16;
typedef uint16_t ee_u16;
typedef int32_t ee_s32;
typedef uint32_t ee_u32;
typedef uint8_t ee_u8;
typedef uint32_t ee_ptr_int;
typedef size_t ee_size_t;
typedef uint64_t CORE_TICKS;
typedef uint64_t CORETIMETYPE;

#define NULL ((void *)0)
#define align_mem(x) \
    (void *)(4u + (((ee_ptr_int)(x) - 1u) & ~(ee_ptr_int)3u))

#define SEED_METHOD SEED_VOLATILE
#define MEM_METHOD MEM_STATIC
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK 0
#define USE_SOCKET 0
#define MAIN_HAS_NOARGC 1
#define MAIN_HAS_NORETURN 0

#ifndef COREMARK_TICKS_PER_SEC
#define COREMARK_TICKS_PER_SEC 200000000u
#endif

typedef struct CORE_PORTABLE_S {
    ee_u8 portable_id;
} core_portable;

extern ee_u32 default_num_contexts;

void portable_init(core_portable *portable, int *argc, char *argv[]);
void portable_fini(core_portable *portable);
int coremark_result_code(void);
void coremark_set_iterations(ee_u32 iterations);
CORE_TICKS coremark_last_ticks(void);
int ee_printf(const char *format, ...);

#endif
