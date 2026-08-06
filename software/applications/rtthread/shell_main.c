#include <rtthread.h>

int main(void)
{
    rt_kprintf("SocRV RT-Thread ready\n");
    rt_kprintf("Use: coremark [iterations]\n");
    rt_kprintf("Use: temp_start [period_ms], temp_stop\n");
    rt_kprintf("FPGA target command: coremark 10000\n");
    return 0;
}
