#include <rtthread.h>
#include <finsh.h>
#include <string.h>

#include "core_portme.h"
#include "drv_timer.h"
#include "drv_uart.h"
#include "test_status.h"

int coremark_main(void);

#define COREMARK_DEFAULT_ITERATIONS 10000u
#define COREMARK_MAX_ITERATIONS 1000000u

static void print_u64(uint64_t value)
{
    char digits[24];
    unsigned used = 0;

    do {
        digits[used++] = (char)('0' + (value % 10u));
        value /= 10u;
    } while (value != 0u);
    while (used != 0u) {
        uart_putc(digits[--used]);
    }
}

static int parse_iterations(int argc, char **argv, uint32_t *iterations)
{
    unsigned long parsed;
    char *end;

    *iterations = COREMARK_DEFAULT_ITERATIONS;
    if (argc == 1) {
        return 0;
    }
    if (argc != 2) {
        return -1;
    }
    parsed = strtoul(argv[1], &end, 10);
    if (*argv[1] == '\0' || *end != '\0' ||
        parsed == 0u || parsed > COREMARK_MAX_ITERATIONS) {
        return -1;
    }
    *iterations = (uint32_t)parsed;
    return 0;
}

static int cmd_coremark(int argc, char **argv)
{
    uint32_t iterations;
    uint64_t ticks;
    int result;

    if (parse_iterations(argc, argv, &iterations) != 0) {
        rt_kprintf("usage: coremark [iterations]\n");
        rt_kprintf("iterations: 1..%u, default %u\n",
                   COREMARK_MAX_ITERATIONS,
                   COREMARK_DEFAULT_ITERATIONS);
        return -RT_EINVAL;
    }

    uart_flush();
    rt_kprintf("SocRV CoreMark: iterations=%u, clock=%u Hz\n",
               iterations,
               COREMARK_TICKS_PER_SEC);
    coremark_set_iterations(iterations);
    (void)coremark_main();
    result = coremark_result_code();
    ticks = coremark_last_ticks();

    if (ticks == 0u) {
        rt_kprintf("SocRV CoreMark timer did not advance\n");
        (void)timer_init_tick(RT_TICK_PER_SECOND);
        coremark_resume_interrupts();
        test_status_report_fail(0xffffffffu);
        return -RT_ERROR;
    }

    // CoreMark's ee_printf stream may still occupy the four-byte hardware
    // FIFO.  Drain it before the checker-critical exact-tick record so a
    // timer/shell boundary cannot interleave that label on a slow UART.
    uart_flush();
    uart_puts("SocRV exact total ticks: ");
    print_u64(ticks);
    uart_puts("\nSocRV total time (ms): ");
    print_u64((ticks * 1000u) / COREMARK_TICKS_PER_SEC);
    uart_puts("\nSocRV ticks/iteration: ");
    print_u64(ticks / iterations);
    uart_puts("\nSocRV CoreMark/MHz (x1000): ");
    print_u64(((uint64_t)iterations * 1000000000ull) / ticks);
    uart_putc('\n');

    if (ticks < (uint64_t)COREMARK_TICKS_PER_SEC * 10u) {
        rt_kprintf(
            "SocRV note: short functional/trend run; not a formal score.\n"
        );
    }
    if (result == 0) {
        rt_kprintf("SocRV CoreMark CRC check PASS\n");
    } else {
        rt_kprintf("SocRV CoreMark CRC check FAIL: %d\n", result);
    }
    uart_flush();

    /*
     * The performance port deliberately disables the machine-timer IRQ while
     * CoreMark is running.  Re-arm the RT-Thread tick from the current mtime
     * value before FinSH returns to its blocking getchar loop; merely setting
     * the IRQ-enable bit would leave the old compare deadline in the past and
     * cause an interrupt storm.
     */
    RT_ASSERT(timer_init_tick(RT_TICK_PER_SECOND) != 0u);
    coremark_resume_interrupts();
    if (result == 0) {
        test_status_report_pass(0u);
    } else {
        test_status_report_fail((uint32_t)result);
    }
    return result;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_coremark,
    coremark,
    run CoreMark: coremark [iterations]
);
