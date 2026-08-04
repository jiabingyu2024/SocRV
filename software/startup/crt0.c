#include <stdint.h>

extern uint32_t _bss_start;
extern uint32_t _bss_end;
extern int main(void);
extern void platform_exit(int code);

void crt0(void)
{
    for (uint32_t *word = &_bss_start; word < &_bss_end; ++word) {
        *word = 0;
    }
    platform_exit(main());
    for (;;) {
    }
}
