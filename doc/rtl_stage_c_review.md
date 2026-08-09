# EH1F RTL Stage-C structural review

Date: 2026-08-09

## Outcome

Stage-C RTL authoring has replaced the active cache/ECC memory datapaths with
plain FPGA-oriented TCM arrays. The active core remains the intermediate
RV32IM_Zicsr baseline; floating point is still gated off until the complete F
architectural state is integrated.

Compilation, simulation and FPGA inference reports remain later verification
gates and were not run in this RTL-generation stage.

## Recoverability

- Stage A: `backup/20260809_160500_eh1_stage_a`
- Stage B: `backup/20260809_162200_eh1_stage_b`

The Stage-B backup contains 66 files and was checked before any Stage-C edit.

## ICCM implementation

- Capacity: 128 KiB.
- Organization: four independent 8192 x 32-bit lanes.
- Read contract: one synchronous 128-bit line per accepted fetch.
- Runtime write compatibility: one word, or a naturally aligned doubleword,
  for loader/debug bring-up.
- Stored check bits: none.
- Tag lookup/refill/replacement: none.
- FPGA intent: each lane carries `ram_style = "block"`.

## DCCM implementation

- Capacity: 64 KiB.
- Organization: eight independent 2048 x 32-bit banks.
- Read contract: synchronous read; adjacent words can be obtained from two
  banks for EH1 unaligned-load/store handling.
- Write contract: one merged 32-bit word from the store buffer.
- Stored check bits: none; `RV_DCCM_FDATA_WIDTH` is 32.
- FPGA intent: every bank carries `ram_style = "block"`.

Partial stores still use the original EH1 store-buffer forwarding policy, but
the old ECC module's byte-merge function has been reimplemented directly on
raw 32-bit TCM data. No correction or scrub transaction remains.

## Removed active logic

- `ifu/ifu_ic_mem.sv` and all active I-Cache RAM/tag/refill logic.
- `lsu/lsu_ecc.sv` and active ECC encode/decode instances.
- 39-bit DCCM storage and 156-bit ICCM storage contracts.
- Aligner parity checking on the TCM-only path.
- I-Cache/ICCM/DCCM error counter registers.
- Cache diagnostic CSR state and legal CSR decode.

The original large cache/ECC controller bodies are currently retained behind
the inactive `RV_TCM_ONLY` alternate branch to make review against upstream
easy. They do not participate in the active configuration and will be deleted
when the minimal no-bus SoC boundary replaces the compatibility wrapper.

## Static evidence

- Active Stage-C RTL entries: 41.
- Missing active filelist paths: 0.
- Duplicate active filelist entries: 0.
- Active cache memory module in filelist: no.
- Active LSU ECC module in filelist: no.
- ICCM interface: 64-bit optional write / 128-bit read, with no check bits.
- DCCM write/read interface: 32 bit.
- Conditional-preprocessor directive counts are balanced in every edited
  controller.
- ECC/cache counter and diagnostic CSR selectors are forced illegal in the
  TCM-only configuration.

## Required verification gate

1. Compile the Stage-C filelist and inspect every width/port diagnostic.
2. Verify reset-vector fetch and sustained two-instruction ICCM delivery.
3. Verify ICCM line offsets 0, 4, 8 and 12 and the 128 KiB upper boundary.
4. Verify DCCM byte, halfword, word and cross-word accesses with store-buffer
   forwarding.
5. Verify DCCM load-use forwarding and freeze/hold behavior.
6. Inspect synthesis RAM reports: four ICCM lanes and eight DCCM banks must
   infer block RAM with no 39-bit or ECC memory.
7. Confirm cache/ECC CSR addresses trap as illegal.

## Next architectural edit

Stage D removes DMA, PIC and external AXI/AHB paths, deletes the inactive
compatibility controller bodies, and introduces a minimal core/TCM/local-MMIO
SoC boundary.
