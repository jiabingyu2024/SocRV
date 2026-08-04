#include <stdint.h>
#include "test_status.h"

void platform_exit(int code)
{
    if (code == 0) {
        test_status_pass(0u);
    }
    test_status_fail((uint32_t)code);
}
