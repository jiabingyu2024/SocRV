# core_clk and periph_clk come from the same MMCM but intentionally run at
# independent rates (100/150/200 MHz versus fixed 50 MHz). All crossings are
# through hxi_async_bridge FIFOs or cdc_sync_level instances; analysing them
# as phase-related synchronous paths creates false setup/hold failures.
set_clock_groups -asynchronous \
  -group [get_clocks -quiet clk_core_unbuffered] \
  -group [get_clocks -quiet clk_periph_unbuffered]

# Reset is asynchronously asserted and synchronously released by the
# ASYNC_REG-marked reset synchronizers. No data-path exception is applied
# within either clock domain.
