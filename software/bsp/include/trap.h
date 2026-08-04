#ifndef SOCRV_TRAP_H
#define SOCRV_TRAP_H

#include <stdint.h>

struct trap_frame;
typedef void (*trap_isr_t)(struct trap_frame *frame);

void trap_install(uint32_t cause, trap_isr_t handler);
void trap_handler(struct trap_frame *frame);

#endif
