create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# The frozen build uses a 1 GHz MMCM VCO and CLKOUT0 divide 4.0, giving
# 250 MHz. Vivado derives that generated clock from the MMCM primitive.
