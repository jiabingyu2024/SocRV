# PYNQ-Z2 correctness-test platform

- Device: `xc7z020clg400-1`
- PL input clock: 125 MHz single-ended `SYSCLK`, pin `H16`
- SoC clocks: fixed 50 MHz core and 50 MHz peripheral clocks
- UART: PL UART on Raspberry Pi header pin 10 (`Y19`, RX) and pin 8
  (`Y18`, TX), 115200 baud
- Shared sensor I2C: PMODB pin 1 / `W14` is SCL and PMODB pin 2 / `Y14` is
  SDA. Both are open-drain ports; connect the BH1750 and OLED in parallel.
- Reset release: MMCM `LOCKED` must remain continuously asserted for 20 ms;
  loss of lock asserts the SoC reset immediately
- LEDs: `LED0` is GPIO bit 0, `LED1` is qualified clock stability, `LED2` is FAIL and
  `LED3` is PASS

This target is intended for functional-correctness tests, not frequency
sweeps. Build it with:

```text
make fpga-build BOARD=pynq_z2
```

The Micro-USB J8 UART is wired to the Zynq processing-system MIO pins. SocRV
runs entirely in programmable logic, so its UART cannot use J8 without adding
and configuring the processing system. Connect a 3.3 V USB-UART adapter to the
Raspberry Pi header instead: adapter TX to pin 10, adapter RX to pin 8, and a
common ground. Do not apply 5 V logic to these pins.

Power the BH1750 and OLED from PMODB pin 6 or 12 (3.3 V), and use PMODB pin 5
or 11 as common ground. If neither module provides pull-ups, add approximately
4.7 kohm from SCL and SDA to 3.3 V. Never pull either I2C signal up to 5 V.

The 125 MHz PL clock is supplied by the Ethernet PHY and stops if `PHYRSTB` is
held low. The current top level does not drive `PHYRSTB`; the board's normal
power-up state must leave the PHY clock running.
