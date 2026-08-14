# Kintex-7 competition platform

- Device: `xc7k325tffg900-2`
- Input clock: 200 MHz differential, pins `AD12/AD11`
- Core clock target: configurable from `MMCME2_BASE`, default 100 MHz
- Peripheral clock: fixed 50 MHz from the same `MMCME2_BASE`
- UART: RX `D18`, TX `D17`, 115200 baud
- Shared sensor I2C: J10 pin 9 / DEBUG_39 / `F22` is SCL and J10 pin 10 /
  DEBUG_40 / `G22` is SDA. Both are open-drain ports.
- `virtual_led[31]` is PASS, `[30]` is FAIL, `[29]` is CPU fault and
  `[28]` is MMCM lock.

Before connecting the BH1750 or OLED, measure TP5 and confirm that Bank 17
`VADJ1` is 3.3 V, matching `LVCMOS33` in `constraints/pins.xdc`. Connect both
modules in parallel to SCL/SDA, power them from J10 pin 20 (3.3 V), and use any
J10 pin 11 through 19 as common ground. If neither module provides pull-ups,
add approximately 4.7 kohm from SCL and SDA to the verified 3.3 V rail.

The bitstream initializes four ICCM lanes and eight DCCM banks directly from
the selected firmware image. There is no external code/data memory interface.
The 100 MHz core and 50 MHz peripheral targets, including their CDC paths,
must be confirmed by the implemented Vivado timing and CDC reports.
