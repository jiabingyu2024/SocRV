#include <rtthread.h>

#include "test_status.h"

static void worker(void *parameter)
{
    (void)parameter;
    rt_kprintf("SocRV RT-Thread worker PASS\n");
    test_status_pass(0u);
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
        25,
        10
    );
    if (result != RT_EOK)
    {
        test_status_fail((rt_uint32_t)result);
    }
    rt_thread_startup(&worker_thread);
    rt_thread_mdelay(2);
    return 0;
}
