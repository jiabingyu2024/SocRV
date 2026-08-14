# AXKU062 / XCKU060-2FFVA1156I.

# Bank 0 configuration/QSPI interface is powered at 3.3 V on AXKU062.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Onboard 200 MHz differential oscillator in the DDR4 1.2 V I/O bank.
set_property PACKAGE_PIN AK17 [get_ports i_sys_clk_p]
set_property PACKAGE_PIN AK16 [get_ports i_sys_clk_n]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {i_sys_clk_p i_sys_clk_n}]

# Onboard CP2102 Mini-USB UART. Bank 64 is powered at 3.3 V.
set_property PACKAGE_PIN AJ11 [get_ports i_uart_rx]
set_property PACKAGE_PIN AM9 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports {i_uart_rx o_uart_tx}]

# User LEDs. LED1..3 are in 1.8 V Bank 66; LED4 is in 3.3 V Bank 65.
set_property PACKAGE_PIN E12 [get_ports {o_led[0]}]
set_property PACKAGE_PIN F12 [get_ports {o_led[1]}]
set_property PACKAGE_PIN L9  [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {o_led[0] o_led[1] o_led[2]}]
set_property PACKAGE_PIN H23 [get_ports {o_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_led[3]}]

# Onboard LM75/24LC04 shared I2C bus in 1.8 V Bank 66. The top level is
# open-drain and relies on the pull-ups already installed on the board.
set_property PACKAGE_PIN L13 [get_ports sensor_i2c_scl_io]
set_property PACKAGE_PIN K13 [get_ports sensor_i2c_sda_io]
set_property IOSTANDARD LVCMOS18 [get_ports {sensor_i2c_scl_io sensor_i2c_sda_io}]
