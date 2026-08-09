# Kintex-7 competition platform

- Device: `xc7k325tffg900-2`
- Input clock: 200 MHz differential, pins `AD12/AD11`
- SoC clock target: 250 MHz from `MMCME2_BASE`
- UART: RX `D18`, TX `D17`, 115200 baud
- `virtual_led[31]` is PASS, `[30]` is FAIL, `[29]` is CPU fault and
  `[28]` is MMCM lock.

The bitstream initializes four ICCM lanes and eight DCCM banks directly from
the selected firmware image. There is no external code/data memory interface.
The 250 MHz target must be confirmed by the implemented Vivado timing report.
