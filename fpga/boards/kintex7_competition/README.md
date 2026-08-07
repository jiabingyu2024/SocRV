# Kintex-7 competition platform

- Device: `xc7k325tffg900-2`
- Input clock: 200 MHz differential, pins `AD12/AD11`
- SoC clock: 175 MHz from `MMCME2_BASE`
- UART: RX `D18`, TX `D17`, 115200 baud
- `virtual_led[31]` is PASS, `[30]` is FAIL, `[29]` is CPU fault and
  `[28]` is MMCM lock.

The pin assignments are carried over verbatim from the previous competition
project. The SoC, memory backend and build flow are new SocRV sources.
