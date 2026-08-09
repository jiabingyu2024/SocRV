# Stage D review: TCM-only local-MMIO SoC

## Result

Stage D replaces the active EH1 external-memory path with one local,
single-outstanding 32-bit MMIO transaction and adds the initial FPGA MCU shell.
The active build has no AHB/AXI build macro, no bus converter in its file list,
and no PIC, DMA controller, or legacy LSU bus buffer instance.

## Fixed address map

| Range | Function |
|---|---|
| `0x0000_0000-0x0001_FFFF` | 128 KiB ICCM, instruction fetch only |
| `0x0002_0000-0x0002_FFFF` | 64 KiB DCCM |
| `0x1000_0000-0x1000_0FFF` | machine timer |
| `0x1000_1000-0x1000_1FFF` | UART |
| `0x1000_2000-0x1000_2FFF` | GPIO |
| `0x1000_3000-0x1000_3FFF` | system control |

Every other data address raises a load/store access fault. MMIO halfword and
word accesses must be naturally aligned. The core has no external-memory
fallback.

## LSU ordering contract

- A load request is captured in DC2 and holds DC3 until `ready`.
- Read data is right-justified before the existing byte/halfword extension logic.
- A store is not presented to a peripheral until its instruction commits in DC5.
- Backpressure starts when the MMIO instruction occupies DC1, preventing a second
  local transaction from entering behind it.
- Nonblocking external loads, posted writes, and write combining are inactive.

This deliberately favours precise state over MMIO throughput; CoreMark executes
from ICCM/DCCM and therefore does not pay this serialization cost in its loop.

## Peripherals

- `machine_timer.sv`: 64-bit `mtime/mtimecmp`, count and interrupt enable.
- `uart.sv`: 4-entry TX/RX FIFOs, 8-N-1 TX/RX, programmable clock-enable divider.
- `gpio.sv`: synchronized inputs plus OUT/OE/SET/CLR/TOGGLE registers.
- `sysctrl.sv`: SoC ID, clock frequency, reset cause, test status and build ID.
- `local_peripheral_subsystem.sv`: address decoder and response mux.
- `soc_top.sv`: generic FPGA-facing clock/reset/UART/GPIO top level.

Only the machine timer interrupt is connected to the CPU. UART and GPIO are
polled in the first software target.

## Removed from the active RTL set

- `pic_ctrl.sv`
- `dma_ctrl.sv`
- `lsu_bus_buffer.sv`
- AHB/AXI converter files

The old conditional bus port text that remains in inherited wrapper sources is
inactive because neither `RV_BUILD_AHB_LITE` nor `RV_BUILD_AXI4` is defined. It
is not part of the selected elaboration and will be physically trimmed further
when the core wrapper is finalized around RV32F.

## Static checks performed

- Stage-D file list: 41 source entries, no missing or duplicate paths.
- Preprocessor conditional counts balanced in the selected files.
- No selected source instantiates PIC, DMA, or the legacy LSU bus buffer.
- MMIO address bounds agree between the LSU checker and peripheral decoder.

Per the RTL-authoring workflow boundary, no compile, simulation, timing, lint,
or CDC claim is made by this review.
