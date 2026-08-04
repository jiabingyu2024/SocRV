# CoreMark integration

`upstream/` is the unmodified EEMBC CoreMark v1.01 source checkout.  All SocRV
timer, console, memory and RT-Thread integration belongs under `port/`.

Two result classes are kept separate:

- `coremark-baremetal`: standalone benchmark for formal FPGA measurements;
- `coremark-rtthread`: benchmark executed as an RT-Thread application.

The short `coremark-smoke` profile is only a functional simulation gate.  Its
iteration count is intentionally below the official validity threshold and it
must never be reported as a CoreMark score.

Typical entry points:

```text
make sim-coremark-smoke
make sim-coremark-rtthread
make software-coremark
make fpga-bitstream PROFILE=coremark-baremetal
```

The formal profile uses the 50 MHz hardware timer and 2000 iterations. A score
is reportable only after the FPGA run satisfies CoreMark's validity rules; the
build manifest records compiler, flags, sources and the locked upstream commit.
