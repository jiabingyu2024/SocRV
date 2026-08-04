#ifndef SOCRV_DRV_TIMER_H
#define SOCRV_DRV_TIMER_H

#include <stdint.h>

uint64_t timer_read(void);
void timer_set_compare(uint64_t deadline);
void timer_disable_compare(void);
void timer_start(int irq_enable);
uint64_t timer_init_tick(uint32_t tick_hz);
uint64_t timer_schedule_next_tick(void);

#endif
