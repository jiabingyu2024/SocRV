# PYNQ-Z2 correctness-test platform

- Device: `xc7z020clg400-1`
- PL input clock: 125 MHz single-ended `SYSCLK`, pin `H16`
- SoC clocks: fixed 50 MHz core and 50 MHz peripheral clocks
- UART: PL UART on Raspberry Pi header pin 10 (`Y19`, RX) and pin 8
  (`Y18`, TX), 115200 baud
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

The 125 MHz PL clock is supplied by the Ethernet PHY and stops if `PHYRSTB` is
held low. The current top level does not drive `PHYRSTB`; the board's normal
power-up state must leave the PHY clock running.
