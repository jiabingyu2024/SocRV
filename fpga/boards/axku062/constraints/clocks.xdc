create_clock -name sys_clk_200mhz -period 5.000 -waveform {0.000 2.500} [get_ports i_sys_clk_p]

# The default MMCM VCO is 1 GHz. CLKOUT0 divides by 10 for the 100 MHz core,
# while CLKOUT1 divides by 20 for the fixed 50 MHz peripheral domain. Vivado
# derives both generated clocks from the MMCME3_BASE primitive.
