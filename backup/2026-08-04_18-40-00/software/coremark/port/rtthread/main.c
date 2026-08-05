#include <rtthread.h>
#include <finsh.h>

#include "test_status.h"

int coremark_main(void);
int coremark_result_code(void);

static int cmd_coremark(int argc, char **argv)
{
    RT_UNUSED(argc);
    RT_UNUSED(argv);
    (void)coremark_main();
    return coremark_result_code();
}
MSH_CMD_EXPORT_ALIAS(cmd_coremark, coremark, run CoreMark functional profile);

int main(void)
{
    int result;
    rt_kprintf("SocRV RT-Thread CoreMark start\n");
    result = cmd_coremark(0, RT_NULL);
    if (result == 0) {
        test_status_pass(0u);
    }
    test_status_fail((uint32_t)result);
}
