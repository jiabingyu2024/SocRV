#include "soc.h"
#include "test_status.h"

static void test_status_report(uint32_t status, uint32_t code)
{
    test_status_set_code(code);
    mmio_write32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_STATUS_OFFSET,
        status
    );
}

void test_status_report_pass(uint32_t code)
{
    test_status_report(SOCRV_TEST_PASS_MAGIC, code);
}

void test_status_report_fail(uint32_t code)
{
    test_status_report(SOCRV_TEST_FAIL_MAGIC, code);
}

static void test_status_finish(uint32_t status, uint32_t code)
    __attribute__((noreturn));

static void test_status_finish(uint32_t status, uint32_t code)
{
    test_status_report(status, code);
    for (;;) {
        __asm volatile("nop");
    }
}

void test_status_set_code(uint32_t code)
{
    mmio_write32(
        SOCRV_SYSCTRL_BASE + SOCRV_SYSCTRL_CODE_OFFSET,
        code
    );
}

void test_status_pass(uint32_t code)
{
    test_status_finish(SOCRV_TEST_PASS_MAGIC, code);
}

void test_status_fail(uint32_t code)
{
    test_status_finish(SOCRV_TEST_FAIL_MAGIC, code);
}
