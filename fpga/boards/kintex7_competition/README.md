# Kintex-7 competition platform

- Device: `xc7k325tffg900-2`
- Input clock: 200 MHz differential, pins `AD12/AD11`
- CPU/BRAM clock: 120 MHz from `MMCME2_BASE` CLKOUT0
- Peripheral/APB clock: fixed 50 MHz from `MMCME2_BASE` CLKOUT1
- MMIO crosses the clock boundary through a strongly ordered CDC bridge;
  UART, timer, interrupt controller and GPIO remain entirely in the 50 MHz
  domain.
- UART: RX `D18`, TX `D17`, 115200 baud
- `virtual_led[31]` is PASS, `[30]` is FAIL, `[29]` is CPU fault and
  `[28]` is MMCM lock.

The pin assignments are carried over verbatim from the previous competition
project. The SoC, memory backend and build flow are new SocRV sources.
