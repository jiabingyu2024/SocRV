#include <stdarg.h>
#include <stdint.h>

#include "coremark.h"
#include "core_portme.h"
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
static int validation_seen;

static int starts_with(const char *text, const char *prefix)
{
    while (*prefix != '\0') {
        if (*text++ != *prefix++) {
            return 0;
        }
    }
    return 1;
}

static void emit_unsigned(uint32_t value, unsigned radix, int width, char pad)
{
    char buffer[16];
    int used = 0;
    static const char digits[] = "0123456789abcdef";
    do {
        buffer[used++] = digits[value % radix];
        value /= radix;
    } while (value != 0u);
    while (used < width) {
        uart_putc(pad);
        --width;
    }
    while (used != 0) {
        uart_putc(buffer[--used]);
    }
}

int ee_printf(const char *format, ...)
{
    va_list arguments;
    int count = 0;
    if (starts_with(
            format,
            "Correct operation validated."
        )) {
        validation_seen = 1;
    }
    va_start(arguments, format);
    while (*format != '\0') {
        if (*format != '%') {
            uart_putc(*format++);
            ++count;
            continue;
        }
        ++format;
        if (*format == '%') {
            uart_putc(*format++);
            ++count;
            continue;
        }
        char pad = ' ';
        int width = 0;
        if (*format == '0') {
            pad = '0';
            ++format;
        }
        while (*format >= '0' && *format <= '9') {
            width = width * 10 + (*format++ - '0');
        }
        if (*format == 'l') {
            ++format;
        }
        switch (*format++) {
        case 'c':
            uart_putc((char)va_arg(arguments, int));
            break;
        case 's': {
            const char *text = va_arg(arguments, const char *);
            uart_puts(text != 0 ? text : "(null)");
            break;
        }
        case 'd': {
            int32_t value = va_arg(arguments, int32_t);
            uint32_t magnitude;
            if (value < 0) {
                uart_putc('-');
                magnitude = (uint32_t)(-(value + 1)) + 1u;
            } else {
                magnitude = (uint32_t)value;
            }
            emit_unsigned(magnitude, 10u, width, pad);
            break;
        }
        case 'u':
            emit_unsigned(
                va_arg(arguments, uint32_t),
                10u,
                width,
                pad
            );
            break;
        case 'x':
        case 'X':
            emit_unsigned(
                va_arg(arguments, uint32_t),
                16u,
                width,
                pad
            );
            break;
        default:
            uart_putc('?');
            break;
        }
    }
    va_end(arguments);
    return count;
}

void start_time(void)
{
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
    return (secs_ret)(ticks / COREMARK_TICKS_PER_SEC);
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
    validation_seen = 0;
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *) || sizeof(ee_u32) != 4u) {
        validation_seen = -1;
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
    return validation_seen == 1 ? 0 : 1;
}
