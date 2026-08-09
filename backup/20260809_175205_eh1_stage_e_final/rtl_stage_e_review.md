# Stage E review: RV32IMF TCM-only FPGA SoC

## Result

Stage E establishes the intended implementation boundary: VeeR EH1 with
RV32IMF_Zicsr, fixed 32-bit instructions, 128 KiB ICCM, 64 KiB DCCM, local
MMIO and no active cache, ECC or external-memory transport. The active list is
`rtl/filelist_stage_e.f` and contains 67 source entries, including the licensed
FPnew subset used for RV32F.

The final Stage-E RTL snapshot is
`backup/20260809_175205_eh1_stage_e_final/rtl`.

## Core and memory

- `misa` advertises RV32IMF; C is absent and control-transfer alignment is 4 B.
- The original dual-issue integer core, M extension and high-performance branch
  predictor configuration are retained.
- ICCM is four synchronous 8192 x 32-bit lanes (128 KiB total).
- DCCM is eight synchronous 2048 x 32-bit banks (64 KiB total).
- Both TCMs store data bits only. Cache RAM/refill logic, syndrome generation,
  correction and scrub paths are absent from the active implementation.
- The dead cache/refill/AXI implementation in `ifu_mem_ctl.sv` was removed;
  compatibility outputs that remain on inherited hierarchy boundaries are
  tied inactive.

## RV32F

Stage E adds an independent 32 x 32-bit FPR, single-precision FPnew execution,
FPR hazard tracking, FLW/FSW, GPR/FPR result routing, fflags/frm/fcsr and
mstatus.FS handling. FPU completion participates in flush and retirement rather
than updating architectural state when the request is merely accepted.

The software contract is `-march=rv32imf_zicsr -mabi=ilp32f`. RT-Thread's
compiler-selected single-precision context path saves all 32 FPRs and fcsr.

## SoC integration

The only data path outside DCCM is a commit-safe, single-outstanding local MMIO
request. The fixed map is:

| Range | Function |
| --- | --- |
| `0x0000_0000-0x0001_FFFF` | ICCM |
| `0x0002_0000-0x0002_FFFF` | DCCM |
| `0x1000_0000-0x1000_0FFF` | machine timer |
| `0x1000_1000-0x1000_1FFF` | UART |
| `0x1000_2000-0x1000_2FFF` | GPIO |
| `0x1000_3000-0x1000_3FFF` | SYSCTRL |

The timer and SYSCTRL software request share machine interrupt cause 7. UART
and GPIO are polled; no PIC is instantiated. SYSCTRL STATUS is at absolute
address `0x1000_3014` and CODE at `0x1000_3018`.

## FPGA and software image

The Kintex-7 top is frozen to one 250 MHz clock. Firmware conversion produces
four ICCM lane files and eight DCCM bank files, all passed to the FPGA top as
initialization generics. Old generic code/data memory backends and unused
AHB/AXI converters were deleted.

CoreMark defaults to 10000 iterations and reads the 250 MHz machine timer.
RT tick interrupts are disabled inside the measurement window and rearmed
afterward. CoreMark/MHz > 4 and approximately 10 seconds are sign-off targets,
not results established by this static review.

## Static checks performed

- Generated SoC headers and linker constants match the JSON contract.
- All JSON schemas and registered data documents validate.
- Memory-map cross-check passes for six regions and four peripherals.
- Active, simulation and FPGA file lists contain no missing or duplicate path.
- Python sources parse successfully.
- ICCM/DCCM interleaving logic was checked with a synthetic lane/bank split.
- `git diff --check` reports no whitespace errors.
- The image checker rejects pre-Stage-E images whose memory-map hash, TCM
  ranges or test-status address do not match the current contract.
- The rewritten architecture document is valid UTF-8 with no replacement
  characters.

No SystemVerilog compilation, simulation, lint, CDC, synthesis, timing closure
or board measurement was run in this RTL-authoring stage. The checked-in ISA
images and old build outputs predate the final memory map and must be rebuilt;
they are not valid Stage-E evidence.
