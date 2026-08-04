extern void crt_init_memory(void);
extern void rtthread_startup(void);

void rtthread_crt0(void)
{
    crt_init_memory();
    rtthread_startup();
    for (;;) {
    }
}
