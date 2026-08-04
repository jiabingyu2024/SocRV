#ifndef SOCRV_TEST_STATUS_H
#define SOCRV_TEST_STATUS_H

#include <stdint.h>

void test_status_pass(uint32_t code) __attribute__((noreturn));
void test_status_fail(uint32_t code) __attribute__((noreturn));

#endif
