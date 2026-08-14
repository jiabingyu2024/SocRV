# AXKU062 Kintex UltraScale platform

- Device: `xcku060-ffva1156-2-i`
- Input clock: 200 MHz differential, pins `AK17/AK16`
- Core clock target: configurable from `MMCME3_BASE`, default 100 MHz
- Peripheral clock: fixed 50 MHz from the same `MMCME3_BASE`
- UART: onboard CP2102 Mini-USB, RX `AJ11`, TX `AM9`, 115200 baud
- LEDs: `LED1`/`E12`, `LED2`/`F12`, `LED3`/`L9`, `LED4`/`H23`
- Shared I2C: onboard LM75 and 24LC04 bus, SCL `L13`, SDA `K13`

`LED1` reflects GPIO bit 0, `LED2` is the live MMCM lock state, `LED3` is
FAIL, and `LED4` is PASS. LED1 through LED3 are Bank 66 1.8 V signals;
LED4 is a Bank 65 3.3 V signal.

The I2C pins are wired to the board's LM75 temperature sensor and 24LC04
EEPROM. They are open-drain ports in the FPGA top level and use the board's
existing pull-ups. This bus is not exposed as a jumper-friendly header. Do not
attach a 3.3 V pull-up to it: Bank 66 is constrained as `LVCMOS18`.

The bitstream initializes four ICCM lanes and eight DCCM banks directly from
the selected firmware image. There is no external code/data memory interface,
and the onboard DDR4 is intentionally outside this target's first bring-up
scope.

Build the default 100 MHz core and 50 MHz peripheral target with:

```text
make fpga-build BOARD=axku062
```

The verified 50 MHz core/peripheral build uses the existing software image and
does not rebuild or modify `software/`:

```text
python scripts/run_vivado.py --board axku062 --profile rtthread-coremark --core-mhz 50
```

## Serial console and programming

Connect the board's CP2102 Mini-USB port to the host. In MobaXterm, start a
Serial session on the corresponding `COM` port with `115200`, 8 data bits, no
parity, 1 stop bit, and no flow control. The expected RT-Thread console prompt
is `msh >`; commands typed in this terminal are returned through the same USB
UART. No external USB-to-TTL adapter or FMC LPC adapter is needed.

Connect a Xilinx-compatible JTAG cable to the board JTAG header. To load a
volatile `.bit` file, open Vivado Hardware Manager, open the target, select the
`xcku060` device, choose the bitstream, and use **Program Device**. The same can
be done from the command line with `tcl/program.tcl`. Power cycling loses this
configuration; QSPI flash programming is not part of this target.

## Sensors and external wiring

This target uses the board-mounted LM75 temperature sensor and 24LC04 EEPROM on
the shared 1.8 V I2C bus (`SCL=L13`, `SDA=K13`). They require no external
wiring. These signals are not routed to a jumper-friendly connector by this
target, so do not connect a 3.3 V sensor or pull-up to them. An external BH1750,
OLED, or other competition sensor still needs a separately verified 1.8 V
header/level-shifter wiring assignment before it can be added; the absent FMC
LPC adapter is not required for the current onboard-sensor/console bring-up.

## Golden bitstream and fast image replacement

After a routed 50 MHz build, export the timing-checked golden checkpoint,
bitstream, and BRAM map with:

```text
vivado -mode batch -source fpga/boards/axku062/tcl/export_golden.tcl -tclargs <routed.dcp> <golden-dir>
python scripts/generate_manual_mmi.py --bram-map <golden-dir>/bram_map.tsv --output <golden-dir>/golden.mmi
```

Patch a new canonical `code.mem`/`data.mem` pair into that golden implementation
without rerunning synthesis or implementation:

```text
python scripts/patch_bitstream.py --golden-dir <golden-dir> --code-mem <image-dir>/code.mem --data-mem <image-dir>/data.mem --output-dir <new-empty-dir>
```

The patch flow updates all four ICCM lanes and eight DCCM banks and writes
`competition.bit` plus a per-stage `patch_result.json`. Only use an MMI exported
from the same golden DCP/bitstream pair.
