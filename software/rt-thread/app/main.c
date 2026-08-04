#include <rtthread.h>

#include "soc.h"
#include "drv_uart.h"

static void worker(void *parameter)
{
    RT_UNUSED(parameter);
    rt_kprintf("SocRV RT-Thread worker PASS\n");
    uart_flush();
    mmio_write32(SOCRV_TEST_STATUS_BASE + 0x04u, 0u);
    mmio_write32(SOCRV_TEST_STATUS_BASE + 0x00u, 0x50415353u);
}

int main(void)
{
    static struct rt_thread worker_thread;
    static rt_uint8_t worker_stack[1024];
    rt_err_t result;

    rt_kprintf("SocRV RT-Thread boot\n");
    result = rt_thread_init(
        &worker_thread,
        "worker",
        worker,
        RT_NULL,
        worker_stack,
        sizeof(worker_stack),
        12,
        10
    );
    RT_ASSERT(result == RT_EOK);
    rt_thread_startup(&worker_thread);
    rt_thread_mdelay(2);
    return 0;
}
