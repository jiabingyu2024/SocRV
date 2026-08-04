create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# MMCME2_BASE generated clocks are derived automatically through the primitive.
# The design has one functional clock domain after the MMCM, so no asynchronous
# clock-group exception is required.
