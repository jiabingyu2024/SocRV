#include <rtthread.h>
#include <finsh.h>

#include "drv_bh1750.h"
#include "drv_i2c.h"
#include "drv_oled.h"

static int cmd_light_read(int argc, char **argv)
{
    bh1750_measurement_t measurement;
    int result;

    RT_UNUSED(argv);
    if (argc != 1) {
        rt_kprintf("usage: light_read\n");
        return -RT_EINVAL;
    }

    result = bh1750_read_once(&measurement);
    if (result == I2C_OK) {
        rt_kprintf(
            "light_read: addr=0x%02x raw=0x%04x lux=%u.%02u status=ok\n",
            measurement.address,
            measurement.raw,
            (unsigned int)(measurement.lux_x100 / 100u),
            (unsigned int)(measurement.lux_x100 % 100u)
        );
    } else {
        rt_kprintf(
            "light_read: addr=0x%02x raw=n/a lux=n/a status=%s\n",
            BH1750_DEFAULT_ADDRESS,
            i2c_result_string(result)
        );
    }
    /* The command itself completed; the structured status above carries the
     * device or bus error without adding FinSH's generic "command failed". */
    return 0;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_light_read,
    light_read,
    read BH1750 illuminance once
);

static int cmd_oled_start(int argc, char **argv)
{
    uint8_t address;
    int result;

    RT_UNUSED(argv);
    if (argc != 1) {
        rt_kprintf("usage: oled_start\n");
        return -RT_EINVAL;
    }

    result = oled_start_rtthread();
    address = oled_address();
    if (result == OLED_ALREADY_RUNNING) {
        rt_kprintf(
            "oled_start: addr=0x%02x controller=%s state=running "
            "status=already_running\n",
            address,
            oled_controller_name()
        );
        return 0;
    }
    if (result == OLED_OK) {
        rt_kprintf(
            "oled_start: addr=0x%02x controller=%s state=running status=ok\n",
            address,
            oled_controller_name()
        );
        return 0;
    }

    if (address == 0u) {
        rt_kprintf(
            "oled_start: addr=n/a controller=%s state=stopped status=%s\n",
            oled_controller_name(),
            result == OLED_ERR_NOT_FOUND ? "not_found" :
                                           i2c_result_string(result)
        );
    } else {
        rt_kprintf(
            "oled_start: addr=0x%02x controller=%s state=stopped status=%s\n",
            address,
            oled_controller_name(),
            i2c_result_string(result)
        );
    }
    return 0;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_oled_start,
    oled_start,
    show RTThread on OLED
);

static int cmd_oled_stop(int argc, char **argv)
{
    uint8_t address;
    int result;

    RT_UNUSED(argv);
    if (argc != 1) {
        rt_kprintf("usage: oled_stop\n");
        return -RT_EINVAL;
    }

    result = oled_stop();
    address = oled_address();
    if (result == OLED_ALREADY_STOPPED) {
        if (address == 0u) {
            rt_kprintf(
                "oled_stop: addr=n/a state=stopped status=already_stopped\n"
            );
        } else {
            rt_kprintf(
                "oled_stop: addr=0x%02x state=stopped "
                "status=already_stopped\n",
                address
            );
        }
        return 0;
    }
    if (result == OLED_OK) {
        rt_kprintf(
            "oled_stop: addr=0x%02x state=stopped status=ok\n",
            address
        );
        return 0;
    }

    rt_kprintf(
        "oled_stop: addr=0x%02x state=stopped status=%s\n",
        address,
        i2c_result_string(result)
    );
    return 0;
}
MSH_CMD_EXPORT_ALIAS(
    cmd_oled_stop,
    oled_stop,
    stop OLED display
);
