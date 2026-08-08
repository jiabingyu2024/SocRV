#include <rtthread.h>

#include "test_status.h"

static void worker(void *parameter)
{
    RT_UNUSED(parameter);
    test_status_pass(0u);
    rt_kprintf("SocRV RT-Thread worker PASS\n");
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
    RT_ASSERT(result == RT_EOK);
    rt_thread_startup(&worker_thread);
    rt_thread_mdelay(2);
    return 0;
}
