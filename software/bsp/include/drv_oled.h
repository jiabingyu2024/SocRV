#ifndef SOCRV_DRV_OLED_H
#define SOCRV_DRV_OLED_H

#include <stdint.h>

typedef enum {
    OLED_OK = 0,
    OLED_ALREADY_RUNNING = 1,
    OLED_ALREADY_STOPPED = 2,
    OLED_ERR_NOT_FOUND = -32
} oled_result_t;

int oled_start_rtthread(void);
int oled_stop(void);
uint8_t oled_address(void);
int oled_is_running(void);
const char *oled_controller_name(void);

#endif
