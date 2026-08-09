# EH1F RTL Stage-A structural review

Date: 2026-08-09

## Outcome

Stage-A mechanical copy is structurally complete and ready for an external compile/simulation gate.

## Evidence

- Upstream repository revision: d04b1c7ae675a63dc4307cacfd10547ec937b928
- Upstream design files checked: 50
- Copy hash mismatches: 0
- Compilable Verilog/SystemVerilog sources: 44
- Explicit filelist entries: 44
- Missing filelist paths: 0
- Duplicate filelist entries: 0
- RTL sources omitted from filelist: 0
- Generated configuration artifacts: 8, all non-empty
- Original SocRv doc/rtl_changes.json history preserved

## Stage-A configuration

- target: high_perf
- bus: AHB-Lite
- reset vector: 0x00000000
- ICCM: 128 KiB at 0x00000000
- DCCM: 64 KiB at 0x00020000
- I-Cache: disabled
- BTB: 512 entries
- BHT: 2048 entries
- FPGA optimization: enabled

Stage-A intentionally retains compressed instructions, TCM ECC, PIC, DMA and the upstream wrapper. Those are removed only after the copied baseline passes compilation and the original integer smoke tests.

## Active files

- rtl/filelist.f
- rtl/filelist_stage_a.f
- rtl/core/eh1f/config/eh1_stage_a/common_defines.vh
- rtl/core/eh1f/UPSTREAM.md
- doc/rtl_changes_20260809_155557_eh1_stage_a.json

## Required gate before Stage B

The next step changes instruction alignment, decode and branch-length behavior. Before that edit, the copied baseline must pass:

1. SystemVerilog compilation with veer_wrapper as top.
2. Original EH1 hello_world smoke test.
3. RV32I, RV32M and compressed-instruction smoke tests.
4. ICCM and DCCM access smoke tests.
5. mcycle/minstret sanity.
6. No missing module, include or width errors.

Compilation and simulation were not run in this RTL-generation stage because the selected MCU RTL development workflow explicitly separates RTL authoring from compile/simulation.

## Next architectural edit after the gate

Stage B removes the C extension:

- remove ifu_compress_ctl.sv and dec/cdecode from the active implementation;
- replace the aligner with fixed 32-bit instruction selection;
- force instruction length to four bytes;
- implement IALIGN=32 target-misalignment exceptions;
- clear misa.C;
- keep the original PC signal width initially to reduce simultaneous churn.

