#include <rtthread.h>
#include <finsh.h>

#include "soc.h"

static int cmd_socrv_info(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    rt_kprintf(
        "SocRV march=%s mabi=%s clock=%u timer=%u uart=%u\n",
        SOCRV_MARCH,
        SOCRV_MABI,
        SOCRV_SOC_CLOCK_HZ,
        SOCRV_TIMER_CLOCK_HZ,
        SOCRV_UART_BAUD
    );
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_socrv_info, socrv_info, show SocRV contract);

static int cmd_uptime(int argc, char **argv)
{
    const rt_tick_t ticks = rt_tick_get();

    (void)argc;
    (void)argv;
    rt_kprintf(
        "uptime: %u ticks (%u seconds)\n",
        (unsigned int)ticks,
        (unsigned int)(ticks / RT_TICK_PER_SECOND)
    );
    return 0;
}
MSH_CMD_EXPORT_ALIAS(cmd_uptime, uptime, show system uptime);
