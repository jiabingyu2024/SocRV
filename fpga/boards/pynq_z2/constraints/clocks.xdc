create_clock -name sys_clk_125mhz -period 8.000 -waveform {0.000 4.000} [get_ports i_sys_clk]

# The MMCM VCO is 1 GHz. CLKOUT0 and CLKOUT1 both divide by 20 to generate
# the fixed 50 MHz core and peripheral clocks used for correctness testing.
