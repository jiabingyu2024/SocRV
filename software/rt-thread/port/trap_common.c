#include <rthw.h>
#include <rtthread.h>

#include "rt_hw_stack_frame.h"

#define ISR_NUMBER 32

static volatile struct rt_hw_stack_frame *stack_frame;
static struct rt_irq_desc irq_table[ISR_NUMBER];

static void unhandled_interrupt(int vector, void *parameter)
{
    (void)parameter;
    rt_kprintf("Unhandled interrupt %d occurred\n", vector);
}

void rt_hw_interrupt_init(void)
{
    int vector;

    for (vector = 0; vector < ISR_NUMBER; vector++)
    {
        irq_table[vector].handler = unhandled_interrupt;
        irq_table[vector].param = RT_NULL;
    }
}

rt_isr_handler_t rt_hw_interrupt_install(int vector,
                                         rt_isr_handler_t handler,
                                         void *parameter,
                                         const char *name)
{
    rt_isr_handler_t old_handler = RT_NULL;

    (void)name;
    if (vector >= 0 && vector < ISR_NUMBER)
    {
        old_handler = irq_table[vector].handler;
        if (handler != RT_NULL)
        {
            irq_table[vector].handler = handler;
            irq_table[vector].param = parameter;
        }
    }

    return old_handler;
}

void rt_rv32_system_irq_handler(rt_uint32_t mcause)
{
    const rt_uint32_t vector = mcause & 0x1fu;

    if ((mcause & 0x80000000u) == 0u)
    {
        rt_ubase_t mscratch;

        __asm volatile("csrr %0, mscratch" : "=r"(mscratch));
        stack_frame = (volatile struct rt_hw_stack_frame *)mscratch;
        rt_kprintf("Exception %d at 0x%08x\n", vector, stack_frame->epc);
        while (1)
        {
        }
    }

    irq_table[vector].handler((int)vector, irq_table[vector].param);
}
