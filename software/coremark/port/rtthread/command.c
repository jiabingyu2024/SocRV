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

    // Drain CoreMark's ee_printf output (a four-byte hardware FIFO) before
    // returning to the shell, so no upstream line is lost or interleaved.
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
