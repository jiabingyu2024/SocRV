create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# The MMCM uses a 1 GHz VCO: CLKOUT0 is selected by the CORE_CLKOUT_DIVIDE_F
# build generic (10.0/6.6666666667/5.0 for 100/150/200 MHz), while CLKOUT1 is
# always divide-by-20 = 50 MHz. Vivado derives both clocks from the MMCM
# primitive; every frequency is therefore checked against its actual generated
# clock rather than against a relaxed 50 or 100 MHz surrogate constraint.
