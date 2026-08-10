# The core and 50 MHz peripheral clocks are related MMCM outputs, so Vivado
# must continue timing the bundled payload paths.  Functional crossings use
# toggle handshakes or two-flop level synchronizers marked ASYNC_REG; do not
# cut the domains with set_clock_groups, which would hide real payload timing.
# Reset is asynchronously asserted and synchronously released in each domain.
