#ifndef SOCRV_DRV_IRQ_H
#define SOCRV_DRV_IRQ_H

#include <stdint.h>

void irq_controller_init(void);
uint32_t irq_pending(void);
void irq_clear(uint32_t mask);
void irq_enable_sources(uint32_t mask);
void irq_disable_sources(uint32_t mask);
void irq_trigger_software(void);
void irq_clear_software(void);

#endif
