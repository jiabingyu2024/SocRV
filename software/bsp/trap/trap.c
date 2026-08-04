#include <stdint.h>
#include "soc.h"

void trap_handler(uint32_t cause, uint32_t epc)
{
    mmio_write32(SOCRV_TEST_STATUS_BASE + 0x04u, cause ^ epc);
    mmio_write32(SOCRV_TEST_STATUS_BASE + 0x00u, 0x4641494cu);
    for (;;) {
    }
}
