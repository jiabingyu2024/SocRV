create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# The MMCM VCO is 1 GHz. CLKOUT0 is configurable (divide 10.0 for the
# default 100 MHz core or 4.0 for the optional 250 MHz core), while CLKOUT1
# always divides by 20 for the fixed 50 MHz peripheral domain. Vivado derives
# both generated clocks from the MMCM primitive.
