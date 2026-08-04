#include <stdint.h>

extern uint32_t __data_load_start;
extern uint32_t __data_start;
extern uint32_t __data_end;
extern uint32_t __bss_start;
extern uint32_t __bss_end;
extern int main(void);
extern void platform_exit(int code);

void crt_init_memory(void)
{
    uint32_t *source = &__data_load_start;
    for (uint32_t *word = &__data_start; word < &__data_end; ++word) {
        if (source != word) {
            *word = *source;
        }
        ++source;
    }
    for (uint32_t *word = &__bss_start; word < &__bss_end; ++word) {
        *word = 0;
    }
}

void crt0(void)
{
    extern void board_init(void);
    crt_init_memory();
    board_init();
    platform_exit(main());
    for (;;) {
    }
}
