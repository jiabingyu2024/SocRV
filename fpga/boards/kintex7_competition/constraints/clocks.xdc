create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# MMCME2_BASE generated clocks are derived automatically through the primitive:
# CLKOUT0 is the performance-oriented CPU/BRAM clock and CLKOUT1 is the fixed
# 50 MHz peripheral clock.
