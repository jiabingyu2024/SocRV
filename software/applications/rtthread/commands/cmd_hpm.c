/*
 * Hardware performance monitor access for cycles/iteration attribution.
 *
 * EH1 exposes four programmable counters (mhpmcounter3..6) whose event is
 * selected by mhpmevent3..6.  Nothing in the core disables them at build time,
 * so they can be armed from the shell and read back after a workload without
 * touching the benchmark's own timed code.
 *
 * Usage:
 *   hpm_arm 28 30 33 48     select four events, zero the counters
 *   coremark 3              run the workload
 *   hpm_read                dump minstret/mcycle plus the four counters
 *
 * Event numbers come from rtl/core/eh1f/dec/dec_tlu_ctl.sv (MHPME_* localparams).
 * The ones that matter for stall attribution:
 *   25 branch mispredict     26 branch taken        27 branch not predicted
 *   28 fetch stall           29 aligner stall       30 decode stall
 *   31 postsync stall        32 presync stall       33 LSU freeze
 *   34 store-buffer WB stall 40 flush lower         41 branch error
 *   47 ibus stall            48 dbus stall
 */

#include <rtthread.h>
#include <finsh.h>
#include <stdint.h>

#define HPM_NUM_COUNTERS 4u

/* Event selectors currently armed, kept so the dump can label its rows. */
static uint32_t hpm_events[HPM_NUM_COUNTERS];

static const char *hpm_event_name(uint32_t event)
{
    switch (event) {
    case 0:  return "disabled";
    case 25: return "branch-mispredict";
    case 26: return "branch-taken";
    case 27: return "branch-not-predicted";
    case 28: return "fetch-stall";
    case 29: return "aligner-stall";
    case 30: return "decode-stall";
    case 31: return "postsync-stall";
    case 32: return "presync-stall";
    case 33: return "lsu-freeze";
    case 34: return "stbuf-wb-stall";
    case 40: return "flush-lower";
    case 41: return "branch-error";
    case 47: return "ibus-stall";
    case 48: return "dbus-stall";
    default: return "event";
    }
}

/*
 * mhpmcounter/mhpmevent are not encodable with a runtime index, so every access
 * is a switch over literal CSR names.
 */
static void hpm_write_event(uint32_t idx, uint32_t event)
{
    switch (idx) {
    case 0: __asm volatile("csrw mhpmevent3, %0" :: "r"(event)); break;
    case 1: __asm volatile("csrw mhpmevent4, %0" :: "r"(event)); break;
    case 2: __asm volatile("csrw mhpmevent5, %0" :: "r"(event)); break;
    case 3: __asm volatile("csrw mhpmevent6, %0" :: "r"(event)); break;
    default: break;
    }
}

static void hpm_zero_counter(uint32_t idx)
{
    switch (idx) {
    case 0:
        __asm volatile("csrw mhpmcounter3, zero");
        __asm volatile("csrw mhpmcounter3h, zero");
        break;
    case 1:
        __asm volatile("csrw mhpmcounter4, zero");
        __asm volatile("csrw mhpmcounter4h, zero");
        break;
    case 2:
        __asm volatile("csrw mhpmcounter5, zero");
        __asm volatile("csrw mhpmcounter5h, zero");
        break;
    case 3:
        __asm volatile("csrw mhpmcounter6, zero");
        __asm volatile("csrw mhpmcounter6h, zero");
        break;
    default:
        break;
    }
}

static uint32_t hpm_read_counter(uint32_t idx)
{
    uint32_t value = 0;

    switch (idx) {
    case 0: __asm volatile("csrr %0, mhpmcounter3" : "=r"(value)); break;
    case 1: __asm volatile("csrr %0, mhpmcounter4" : "=r"(value)); break;
    case 2: __asm volatile("csrr %0, mhpmcounter5" : "=r"(value)); break;
    case 3: __asm volatile("csrr %0, mhpmcounter6" : "=r"(value)); break;
    default: break;
    }
    return value;
}

/* The image builds freestanding, so parse decimals locally instead of strtoul. */
static int hpm_parse_u32(const char *text, uint32_t *out)
{
    uint32_t value = 0;

    if (text == RT_NULL || *text == '\0') {
        return -1;
    }
    while (*text != '\0') {
        if (*text < '0' || *text > '9') {
            return -1;
        }
        value = (value * 10u) + (uint32_t)(*text - '0');
        if (value > 0x3ffu) {
            return -1;
        }
        text++;
    }
    *out = value;
    return 0;
}

static int cmd_hpm_arm(int argc, char **argv)
{
    uint32_t i;

    if (argc < 2 || argc > (int)(HPM_NUM_COUNTERS + 1)) {
        rt_kprintf("usage: hpm_arm <event> [event] [event] [event]\n");
        rt_kprintf("common: 28 fetch 29 aligner 30 decode 33 lsu-freeze\n");
        rt_kprintf("        25 br-mispredict 40 flush-lower 47 ibus 48 dbus\n");
        return -1;
    }

    for (i = 0; i < HPM_NUM_COUNTERS; i++) {
        uint32_t event = 0;

        if ((int)i < argc - 1) {
            if (hpm_parse_u32(argv[i + 1], &event) != 0) {
                rt_kprintf("hpm_arm: bad event '%s'\n", argv[i + 1]);
                return -1;
            }
        }

        hpm_events[i] = event;
        /* Stop counting before zeroing so the reset cannot race an increment. */
        hpm_write_event(i, 0);
        hpm_zero_counter(i);
        hpm_write_event(i, event);
    }

    rt_kprintf("hpm armed:");
    for (i = 0; i < HPM_NUM_COUNTERS; i++) {
        rt_kprintf(" c%u=%s", i + 3, hpm_event_name(hpm_events[i]));
    }
    rt_kprintf("\n");
    return 0;
}

static int cmd_hpm_read(int argc, char **argv)
{
    uint32_t cycle_lo = 0;
    uint32_t instret = 0;
    uint32_t i;

    (void)argc;
    (void)argv;

    __asm volatile("csrr %0, mcycle" : "=r"(cycle_lo));
    __asm volatile("csrr %0, minstret" : "=r"(instret));

    rt_kprintf("hpm mcycle=%u minstret=%u\n", cycle_lo, instret);
    for (i = 0; i < HPM_NUM_COUNTERS; i++) {
        if (hpm_events[i] == 0u) {
            continue;
        }
        rt_kprintf("hpm c%u %s=%u\n", i + 3, hpm_event_name(hpm_events[i]),
                   hpm_read_counter(i));
    }
    return 0;
}

MSH_CMD_EXPORT_ALIAS(cmd_hpm_arm, hpm_arm, arm HPM counters with event ids);
MSH_CMD_EXPORT_ALIAS(cmd_hpm_read, hpm_read, dump HPM counters);
