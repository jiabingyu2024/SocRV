#include <stdint.h>

#include "coremark.h"
#include "core_portme.h"
#include "drv_irq.h"
#include "drv_timer.h"
#include "drv_uart.h"
#include "soc.h"
#include "test_status.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0;
volatile ee_s32 seed2_volatile = 0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif

volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

ee_u32 default_num_contexts = 1;

static CORE_TICKS start_ticks;
static CORE_TICKS stop_ticks;
static int data_error_seen;
static uint32_t saved_mstatus;

void start_time(void)
{
    saved_mstatus = irq_save();
    irq_clear_software();
    timer_start(0);
    test_status_set_code(SOCRV_TEST_PERF_START_MAGIC);
    start_ticks = (CORE_TICKS)timer_read();
}

void stop_time(void)
{
    stop_ticks = (CORE_TICKS)timer_read();
    test_status_set_code(SOCRV_TEST_PERF_STOP_MAGIC);
}

CORE_TICKS get_time(void)
{
    return stop_ticks - start_ticks;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)ticks / (secs_ret)COREMARK_TICKS_PER_SEC;
}

void *portable_malloc(ee_size_t size)
{
    (void)size;
    return NULL;
}

void portable_free(void *memory)
{
    (void)memory;
}

void portable_init(core_portable *portable, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    uart_init();
    timer_start(0);
    data_error_seen = 0;
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *) || sizeof(ee_u32) != 4u) {
        data_error_seen = 1;
    }
    portable->portable_id = 1;
}

void portable_fini(core_portable *portable)
{
    portable->portable_id = 0;
    uart_flush();
}

int coremark_result_code(void)
{
    return data_error_seen == 0 ? 0 : 1;
}

void coremark_set_iterations(ee_u32 iterations)
{
    seed4_volatile = (ee_s32)iterations;
}

CORE_TICKS coremark_last_ticks(void)
{
    return get_time();
}

void coremark_resume_interrupts(void)
{
    if ((saved_mstatus & (1u << 3)) != 0u) {
        __asm volatile("csrsi mstatus, 8" : : : "memory");
    }
}
