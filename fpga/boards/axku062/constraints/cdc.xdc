# The core and 50 MHz peripheral clocks are related MMCM outputs, so Vivado
# must continue timing the bundled payload paths. Functional crossings use
# toggle handshakes or two-flop synchronizers marked ASYNC_REG; do not cut the
# domains with set_clock_groups. Reset is asynchronously asserted and
# synchronously released after MMCME3 locks.
