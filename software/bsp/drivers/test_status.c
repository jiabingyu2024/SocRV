#include "soc.h"
#include "test_status.h"

static void test_status_finish(uint32_t status, uint32_t code)
    __attribute__((noreturn));

static void test_status_finish(uint32_t status, uint32_t code)
{
    mmio_write32(
        SOCRV_TEST_STATUS_BASE + SOCRV_TEST_STATUS_CODE_OFFSET,
        code
    );
    mmio_write32(
        SOCRV_TEST_STATUS_BASE + SOCRV_TEST_STATUS_STATUS_OFFSET,
        status
    );
    for (;;) {
        __asm volatile("nop");
    }
}

void test_status_pass(uint32_t code)
{
    test_status_finish(SOCRV_TEST_PASS_MAGIC, code);
}

void test_status_fail(uint32_t code)
{
    test_status_finish(SOCRV_TEST_FAIL_MAGIC, code);
}
