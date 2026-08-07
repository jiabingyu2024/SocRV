#include <stdint.h>

#include "drv_uart.h"

static int check_unsigned_byte(uint32_t value, uint32_t offset)
{
    uint32_t observed;
    uint32_t slot = 0xa55aa55au;
    volatile uint8_t *address = (volatile uint8_t *)&slot + offset;

    __asm__ volatile (
        "sb %[value], 0(%[address])\n\t"
        "lbu %[observed], 0(%[address])"
        : [observed] "=&r" (observed), "+m" (*address)
        : [value] "r" (value), [address] "r" (address)
        : "memory"
    );
    return observed == (value & 0xffu);
}

static int check_signed_byte(uint32_t value, uint32_t offset)
{
    int32_t observed;
    uint32_t slot = 0x5aa55aa5u;
    volatile int8_t *address = (volatile int8_t *)&slot + offset;

    __asm__ volatile (
        "sb %[value], 0(%[address])\n\t"
        "lb %[observed], 0(%[address])"
        : [observed] "=&r" (observed), "+m" (*address)
        : [value] "r" (value), [address] "r" (address)
        : "memory"
    );
    return observed == (int32_t)(int8_t)value;
}

int main(void)
{
    static const uint32_t values[] = {0x00u, 0x20u, 0x7fu, 0x80u, 0xffu};

    uart_init();
    for (uint32_t offset = 0; offset < 4u; ++offset) {
        for (uint32_t index = 0; index < sizeof(values) / sizeof(values[0]); ++index) {
            if (!check_unsigned_byte(values[index], offset) ||
                !check_signed_byte(values[index], offset)) {
                uart_puts("SocRV byte store-load forwarding FAIL\n");
                uart_flush();
                return 1;
            }
        }
    }
    uart_puts("SocRV byte store-load forwarding PASS\n");
    uart_flush();
    return 0;
}
