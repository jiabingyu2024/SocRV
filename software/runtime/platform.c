#include <stdint.h>
#include "soc.h"

void platform_exit(int code)
{
    mmio_write32(SOCRV_TEST_STATUS_BASE + 0x04u, (uint32_t)code);
    mmio_write32(
        SOCRV_TEST_STATUS_BASE + 0x00u,
        code == 0 ? 0x50415353u : 0x4641494cu
    );
    for (;;) {
    }
}
