# SHT30 temperature monitor

This application is linked into the `rtthread-coremark` FPGA profile beside
the CoreMark command. It uses the APB I2C controller at `0x30003000` and tries
the two SHT3x addresses, `0x44` followed by `0x45`.

From the FinSH/MSH prompt:

```text
temp_start
temp_start 500
temp_stop
```

The optional argument is the sample period in milliseconds. The default is
1000 ms and the accepted range is 10 through 60000 ms. The monitor runs in a
background RT-Thread thread so the shell remains available for `temp_stop`.

The board wiring is:

| SHT30 | Board header | FPGA pin |
| --- | --- | --- |
| VCC | J10 pin 20, +3.3 V | - |
| GND | J10 pin 11-19 | - |
| SCL | J10 pin 9, DEBUG_39 | F22 |
| SDA | J10 pin 10, DEBUG_40 | G22 |

Do not power a breakout from 5 V because its I2C pull-ups may then expose the
FPGA pins to 5 V. The board schematic sets Bank 17/VADJ1 to 3.3 V and places a
100 ohm series resistor on each DEBUG signal. Use a breakout with 3.3 V SDA/SCL
pull-ups; for a bare SHT30, add about 4.7 kohm from each bus line to 3.3 V.
