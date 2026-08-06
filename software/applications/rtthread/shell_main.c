#include <rtthread.h>

#include "test_status.h"

int main(void)
{
    rt_kprintf("SocRV RT-Thread ready\n");
    rt_kprintf("Use `help` to list MSH commands\n");
    rt_kprintf("FPGA target command: coremark 10000\n");
    test_status_report_pass(0u);
    return 0;
}
