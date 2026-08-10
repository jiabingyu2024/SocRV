# 125 MHz iteration: FMA/decode batch plus LSU-to-TLU cone isolation

Date: 2026-08-10

## Timing clusters addressed

- FMA: 113 setup violations, worst slack -3.509 ns. The common cone ran from the FMA input pipeline through multiplication/alignment, the adders, and the LZA into the legacy internal register bank.
- Instruction buffer/decode: 2111 setup violations, worst slack -1.605 ns. The dominant common sources were decode source-enable signals and instruction-buffer write enables.
- This batch deliberately leaves the 30-path LSU-to-TLU cluster and the smaller DIV/IFU clusters for the next RTL batch.

## RTL changes

### FMA distributed pipeline

For the EH1F `NumPipeRegs=3, DISTRIBUTED` configuration, the three existing stages are redistributed as:

1. multiplication, operand classification, and addend alignment to `pre_pipe`;
2. positive/negative addition and LZA to `mid_pipe`;
3. normalization, rounding, classification, and result selection to `out_pipe`.

The general allocation is `ceil(N/3) + floor((N+1)/3) + floor(N/3) = N`, so no pipeline register is added or removed. Data, special-case status, format, rounding mode, tag, mask, aux, valid, ready, busy, and `reg_ena_i` indexing all follow the relocated cut points.

### Decode dependency cones

The four source-enable expressions are replicated into nonblocking-load, early dependency (E1/E2), and late dependency (E3/E4/WB) consumer regions. The copies use identical Boolean expressions and are protected with Vivado `keep`/`max_fanout` attributes. High-fanout decode outputs and E1-E4 control enables also carry bounded-fanout guidance.

### Instruction-buffer write enables

The former shared `ibwrite[3:0]` cone is replaced by four equivalent local cones for compressed-instruction, PC, branch-packet, and instruction register banks. Each bank now receives a physically independent OR cone with unchanged write conditions.

## Static closure completed

- No `NUM_NORM`, `norm_pipe`, `*_norm_q`, or removed pre-round signal references remain in the FMA.
- The ready chain has exactly four boundaries: input to pre-add, pre-add to mid, mid to output, and output to downstream.
- The external register-enable indices cover input, pre-add, mid, and output stages without overlap; for distributed configurations from 0 through 10 registers, the allocated stage count always sums to `NumPipeRegs`.
- Decode replicas are expression-equivalent to the architectural decode outputs.
- All four instruction-buffer write-enable vectors are expression-equivalent.
- Parentheses, brackets, braces, and SystemVerilog block keywords are balanced in all three modified RTL files.
- `git diff --check` reports no whitespace errors (only the existing LF-to-CRLF warning).

## Required acceptance run

Run one compact regression batch only:

1. RV32UF directed ISA tests;
2. RV32IMF-Zicsr ISA regression;
3. RT-Thread + CoreMark, checking CRC, cycle count, retired instructions, and IPC against the 250,728-cycle / 299,890-retired / 1.196077024 IPC baseline.

If those pass, run one 125 MHz synth-only build, export all setup violations, and re-cluster the complete report. Accept this batch only if the FMA and decode/ibwrite clusters materially contract without a meaningful CoreMark IPC regression.

## Follow-up batch: LSU-to-TLU public cone

The full report showed a separate 30-path cluster with worst slack about `-1.592 ns`. The common path was not an architectural LSU data dependency; it was a shared synthesized cone from the store-buffer forward-data clocked region through `lsu_lsc_ctl` packed-packet/valid logic, `lsu_pkt_vlddc5ff`, and the TLU halt/flush register bank. Logic depth was approximately 24--30 levels and the synth-only report attributed roughly 73% of the delay to route.

This batch modifies three RTL files without adding a pipeline stage:

1. `lsu_lsc_ctl.sv` computes `lsu_pkt_dc1_valid_d` through `lsu_pkt_dc5_valid_d` as dedicated `keep`/`max_fanout` signals and connects the valid flops directly to those signals. The packet payload still uses the original packed structure assignments.
2. `lsu.sv` splits `lsu_halt_idle_any` into a five-stage non-DMA pipe-busy cone and a buffer-busy cone. `lsu_halt_idle_any = ~pipe_busy & bus_empty & stbuf_nodma_empty` remains algebraically unchanged.
3. `dec_tlu_ctl.sv` gives the halt-state register and `core_empty` check separate equivalent LSU-idle copies, limiting fanout without changing the cycle-level halt protocol.

The next timing run must export all setup violations again, not only top-100 paths. The acceptance criterion is contraction of the LSU-to-TLU cluster and no new validity/flush cluster. DIV-to-TLU and IFU branch-predictor clusters remain explicitly tracked for the next batch.

## Static closure for the follow-up batch

- Valid next-state signals are assigned on every `always_comb` path and cover all five packet stages.
- The valid flops use the dedicated signals for DC1--DC5; packed payload flops remain unchanged.
- The halt-idle refactor preserves the original Boolean equation.
- No port, reset, clock, pipeline depth, or architectural timing interface changed.
- Backup: `backup/20260810_171500/`.

## Follow-up batch: DIV and IFU residual clusters

The remaining full-report clusters were:

- DIV-related: 164 paths touching `exu/div_e1`, including a worst `-1.605 ns` instruction-buffer-to-`miscf` path and broad clock-enable/data cones around `mff`, `qff`, and `aff`.
- IFU BHT: 16 paths from `ifu/bp/coll_ff` to `bht_dataoutf`, worst `-0.120 ns`; the synth-only report showed 12 logic levels and 88% route delay.

This batch makes three no-latency changes:

1. `dec_decode_ctl.sv` creates bounded-fanout local replicas for the divider packet's valid, unsigned, and remainder bits.
2. `exu.sv` rewrites the divider operand selection as a two-level i0/i1 and bypass mux. The old four masked terms and the new mux select the same operand under the legal one-divider-at-a-time decode contract.
3. `ifu_bp_ctl.sv` keeps the BHT read-mux outputs and merged GHR as local physical cones. The predictor still has the same `bht_dataoutf` stage and no added latency.

The next run must re-export all setup paths and verify that the DIV and BHT clusters contract without creating a new decode or predictor-validity cluster.

Backup: `backup/20260810_173459/`.
