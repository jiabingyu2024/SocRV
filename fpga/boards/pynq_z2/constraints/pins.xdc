# PYNQ-Z2 R10 / XC7Z020-1CLG400C. All PL user I/O below is 3.3 V.
set_property PACKAGE_PIN H16 [get_ports i_sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_sys_clk]

# PL UART on the Raspberry Pi header. The Micro-USB UART uses PS MIO14/15
# and is not reachable from this PL-only top level.
set_property PACKAGE_PIN Y19 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]
set_property PACKAGE_PIN Y18 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]

set_property PACKAGE_PIN R14 [get_ports {o_led[0]}]
set_property PACKAGE_PIN P14 [get_ports {o_led[1]}]
set_property PACKAGE_PIN N16 [get_ports {o_led[2]}]
set_property PACKAGE_PIN M14 [get_ports {o_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[*]}]

# Shared open-drain sensor bus on PMODB. External pull-ups must target 3.3 V.
set_property PACKAGE_PIN W14 [get_ports sensor_i2c_scl_io]
set_property PACKAGE_PIN Y14 [get_ports sensor_i2c_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports {sensor_i2c_scl_io sensor_i2c_sda_io}]
