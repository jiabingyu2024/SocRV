#include <finsh.h>
#include <rtthread.h>
#include <stdlib.h>

#include "sht30.h"

#define TEMP_DEFAULT_PERIOD_MS 1000u
#define TEMP_MIN_PERIOD_MS       10u
#define TEMP_MAX_PERIOD_MS    60000u
#define TEMP_THREAD_STACK_SIZE 1536u

static struct rt_thread temp_thread;
static struct rt_semaphore temp_wakeup;
static rt_uint8_t temp_stack[TEMP_THREAD_STACK_SIZE];
static volatile rt_bool_t temp_running;
static rt_uint32_t temp_period_ms = TEMP_DEFAULT_PERIOD_MS;

static void print_temperature(int32_t temperature_mc)
{
    uint32_t magnitude;

    if (temperature_mc < 0) {
        magnitude = (uint32_t)(-temperature_mc);
        rt_kprintf("Temperature: -%u.%03u C\n",
                   magnitude / 1000u,
                   magnitude % 1000u);
    } else {
        magnitude = (uint32_t)temperature_mc;
        rt_kprintf("Temperature: %u.%03u C\n",
                   magnitude / 1000u,
                   magnitude % 1000u);
    }
}

static void temperature_worker(void *parameter)
{
    uint8_t announced_address = 0u;

    RT_UNUSED(parameter);
    for (;;) {
        rt_sem_take(&temp_wakeup, RT_WAITING_FOREVER);
        while (temp_running) {
            int32_t temperature_mc;
            int result = sht30_read_millicelsius(&temperature_mc);

            if (result == SHT30_OK) {
                if (announced_address != sht30_address()) {
                    announced_address = sht30_address();
                    rt_kprintf("SHT30 detected at 0x%02x\n",
                               announced_address);
                }
                print_temperature(temperature_mc);
            } else if (result == SHT30_ERR_CRC) {
                rt_kprintf("SHT30 CRC error\n");
            } else {
                rt_kprintf("SHT30 read failed; check power, wiring and address\n");
            }

            if (temp_running) {
                rt_tick_t delay = rt_tick_from_millisecond(temp_period_ms);
                if (delay == 0) {
                    delay = 1;
                }
                rt_sem_take(&temp_wakeup, delay);
            }
        }
        rt_kprintf("Temperature monitor stopped\n");
    }
}

static int temperature_monitor_init(void)
{
    rt_err_t result;

    result = rt_sem_init(&temp_wakeup, "tempwake", 0, RT_IPC_FLAG_FIFO);
    if (result != RT_EOK) {
        return result;
    }
    result = rt_thread_init(&temp_thread,
                            "tempmon",
                            temperature_worker,
                            RT_NULL,
                            temp_stack,
                            sizeof(temp_stack),
                            22,
                            10);
    if (result != RT_EOK) {
        return result;
    }
    return rt_thread_startup(&temp_thread);
}
INIT_APP_EXPORT(temperature_monitor_init);

static int cmd_temp_start(int argc, char **argv)
{
    unsigned long period = TEMP_DEFAULT_PERIOD_MS;
    char *end;

    if (argc == 2) {
        period = strtoul(argv[1], &end, 10);
        if (*argv[1] == '\0' || *end != '\0' ||
            period < TEMP_MIN_PERIOD_MS || period > TEMP_MAX_PERIOD_MS) {
            rt_kprintf("usage: temp_start [period_ms]\n");
            rt_kprintf("period_ms: %u..%u, default %u\n",
                       TEMP_MIN_PERIOD_MS,
                       TEMP_MAX_PERIOD_MS,
                       TEMP_DEFAULT_PERIOD_MS);
            return -RT_EINVAL;
        }
    } else if (argc != 1) {
        rt_kprintf("usage: temp_start [period_ms]\n");
        return -RT_EINVAL;
    }
    if (temp_running) {
        rt_kprintf("Temperature monitor is already running\n");
        return -RT_EBUSY;
    }
    if (sht30_init() != SHT30_OK) {
        rt_kprintf("I2C controller initialization failed\n");
        return -RT_ERROR;
    }
    temp_period_ms = (rt_uint32_t)period;
    temp_running = RT_TRUE;
    rt_sem_release(&temp_wakeup);
    rt_kprintf("Temperature monitor started, period=%u ms\n",
               temp_period_ms);
    return RT_EOK;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_temp_start,
    temp_start,
    start SHT30 monitor: temp_start [period_ms]
);

static int cmd_temp_stop(int argc, char **argv)
{
    RT_UNUSED(argv);
    if (argc != 1) {
        rt_kprintf("usage: temp_stop\n");
        return -RT_EINVAL;
    }
    if (!temp_running) {
        rt_kprintf("Temperature monitor is not running\n");
        return RT_EOK;
    }
    temp_running = RT_FALSE;
    rt_sem_release(&temp_wakeup);
    rt_kprintf("Temperature monitor stop requested\n");
    return RT_EOK;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_temp_stop,
    temp_stop,
    stop SHT30 temperature monitor
);
