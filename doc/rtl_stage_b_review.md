# EH1F RTL Stage-B structural review

Date: 2026-08-09

## Outcome

Stage-B RTL authoring is structurally complete. The active core is an
intermediate RV32IM_Zicsr implementation with fixed 32-bit instructions and
IALIGN=32 exception handling. The final F extension is deliberately not
advertised until the FPU, floating-point register file and FCSR are integrated
as one architectural change.

Compilation and simulation remain an external gate; they were not run during
this RTL-generation stage.

## Recoverability

The complete Stage-A baseline is preserved at:

- `backup/20260809_160500_eh1_stage_a`

The backup contains 62 source/configuration files. The upstream checkout is
also unchanged, so both removed compressed-decode files are recoverable.

## Implemented changes

- Removed `ifu/ifu_compress_ctl.sv` from the active tree and filelist.
- Removed the generated `dec/cdecode` compressed decode table.
- Forced both aligned instruction slots to 32-bit instructions.
- Forced `pc4` metadata for both issue slots.
- Removed compressed instruction expansion from the active aligner path.
- Disabled compressed-length selection in the branch predictor.
- Cleared `misa.C`; Stage B reports `misa = 0x40001100` (RV32IM).
- Added taken-target bit-1 detection for branch, JAL and JALR operations.
- Pipelined target-misalignment metadata from the primary ALUs to E4 and
  selected it against the secondary-ALU result.
- Added precise instruction-address-misaligned exception cause 0.
- Preserved dual-issue precision: a slot-0 exception kills both slots, while a
  slot-1 exception allows the older slot-0 instruction to commit.
- Captured the faulting control-flow instruction in `mepc` and the bad target
  address in `mtval`.

## Static evidence

- Active Stage-B RTL entries: 43 (41 SystemVerilog and 2 Verilog).
- Missing active filelist paths: 0.
- Duplicate active source entries: 0.
- Active references to the compressed decoder: 0.
- `ifu_compress_ctl.sv` absent from the active source tree.
- `dec/cdecode` absent from the active source tree.
- All four ALU instances connect the new `target_misaligned` output.
- Each new EXU-to-DEC/TLU signal has a producer, top-level interconnect,
  consumer port and consuming logic.
- The active filelist selector is `rtl/filelist_stage_b.f`.

The historical `rtl/filelist_stage_a.f` and copied upstream `flist.questa`
still name the compressor because they are retained as Stage-A/upstream
inventories. Neither is selected by the active Stage-B filelist.

## Required verification gate

1. Compile `veer_wrapper` using `rtl/filelist.f`.
2. Run RV32I and RV32M directed tests with `-march=rv32im_zicsr`.
3. Confirm every 16-bit opcode is rejected rather than expanded.
4. Test taken/not-taken branch, JAL and JALR targets with address bit 1 set.
5. Check cause 0, `mepc`, `mtval`, slot-0/slot-1 commit precision and return
   from the trap handler.
6. Re-run the original integer smoke test before starting the no-ECC memory
   rewrite.

## Next architectural edit

Stage C replaces the ECC-protected ICCM/DCCM paths with plain 32-bit TCM
storage contracts, removes active cache logic, and then removes DMA/PIC/bus
dependencies in preparation for the local SoC wrapper.
