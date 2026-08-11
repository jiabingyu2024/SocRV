# The core and 50 MHz peripheral clocks are related MMCM outputs, so Vivado
# must continue timing the bundled payload paths.  Functional crossings use
# toggle handshakes or two-flop level synchronizers marked ASYNC_REG; do not
# cut the domains with set_clock_groups, which would hide real payload timing.
# Reset is asynchronously asserted and synchronously released in each domain.

# The two generated clocks have a non-integer phase relationship at some core
# frequencies (150 MHz produces a 0.125 ns nearest-edge requirement).  The SoC
# bridges do not consume payload on that nearest edge: request/response payload
# is held stable by a toggle handshake until the destination acknowledges it.
# Constrain every inter-domain datapath to one core period.  This keeps the
# bundled data and synchronizer inputs timed, but models the actual multi-cycle
# transfer protocol instead of an unrelated MMCM phase coincidence.
set core_cdc_period_ns [get_property PERIOD [get_clocks clk_core_unbuffered]]
set_max_delay $core_cdc_period_ns -datapath_only \
   -from [get_clocks clk_core_unbuffered] \
   -to   [get_clocks clk_peripheral_unbuffered]
set_max_delay $core_cdc_period_ns -datapath_only \
   -from [get_clocks clk_peripheral_unbuffered] \
   -to   [get_clocks clk_core_unbuffered]
