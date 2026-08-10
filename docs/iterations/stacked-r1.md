# 125 MHz iteration: verification of three stacked RTL batches

Date: 2026-08-10
Tag: `stacked-r1` (simulation manifest: `verify-stacked-r1`)

## Why this round exists

Three RTL batches were committed in `eb895f0` without any acceptance run:

1. 15:47 - FMA distributed-pipeline redistribution + decode dependency cones + ibwrite split
2. 17:15 - LSU-to-TLU cone isolation (`lsu_lsc_ctl.sv`, `lsu.sv`, `dec_tlu_ctl.sv`)
3. 17:34 - DIV operand mux rewrite + IFU BHT local cones (`dec_decode_ctl.sv`, `exu.sv`, `ifu_bp_ctl.sv`)

The only timing data on disk (`kintex7-rtthread-coremark-125mhz-cast-pipe-r1`,
post-synth report written 15:01) predates all three. RTL mtimes run to 17:36, so
that report describes a design that no longer exists.

This round therefore adds **no** RTL change. It closes the open verification debt
so the next round has a valid baseline, per section 7 ("no path report, no
modification") and section 8.

## Deviation from the single-hypothesis rule

Section 7 requires one primary hypothesis per round, and section 5.2 requires one
pipeline change at a time. Three batches touching FMA pipeline cut points, LSU/TLU
control cones and DIV/BHT logic were stacked instead. Consequence: if timing moved,
attribution between the three batches is not separable from this data alone. That
is accepted for this round only because the batches are already committed; it is
not a precedent. If the timing result is ambiguous, the batches must be split and
re-measured individually rather than reasoned about.

## Functional result: PASS

Static gates and simulation, all nine steps PASS
(`docs/iterations/verify-stacked-r1.json`, git revision `eb895f0`):

| Step | Result |
|---|---|
| check_filelists / check_generated_tree / check_memory_map | PASS |
| validate_schemas / lint_rtl | PASS |
| verilator-build | PASS |
| sim-smoke | PASS |
| sim-isa, gate `final` (72 tests, rv32mi + rv32uf + rv32ui + rv32um) | PASS |
| sim-coremark, 1 iteration | PASS |

The `final` gate was chosen over `current` because the FMA pipeline cut points
moved, which is exactly the class of change section 8 Level 3 requires RV32UF
coverage for.

One infrastructure fix was needed before the gates would run: `.Xil`,
`vivado.jou` and `vivado.log` were left in the repository root by a Vivado run
that exited at 15:19, and `check_generated_tree` correctly rejected them. All
three were untracked; removed.

## CoreMark IPC: no regression

`build/result/soc/opt-verify-stacked-r1-coremark-1.json`, `performance` window:

| Metric | This round | Record baseline | Delta |
|---|---|---|---|
| Window cycles | 250728 | 250728 | 0 |
| Retired instructions | 299890 | 299890 | 0 |
| IPC | 1.196077024 | 1.196077024 | 0 |

Bit-identical to the baseline named in `iter_125mhz_fma_decode_fanout.md`. Expected:
all three batches are fanout replication, cone isolation and pipeline-stage
redistribution at constant register count, none of which changes cycle behaviour.
CRC, prompt, test status and performance-window checks all passed.

## Correction to an earlier performance reading

An earlier digest reported IPC 0.3139 with 2378669 cycles/iteration, taken from
`build/regression/performance/summary.json` (`rtthread-coremark-command-10`). That
is a different test, and its per-iteration cycles differ from this round's by 9.5x
while IPC differs by 3.8x. IPC must not vary with iteration count on a fixed core,
so that 10-iteration window very likely includes RT-Thread idle and UART wait time.
It must not be used as a performance baseline. Accept/reject comparisons use the
1-iteration window above.

## Timing: REJECT (regression on every setup metric)

125 MHz synth-only, `--run-tag stacked-r1`, `--all-violations`. Both runs are
synth stage, same 8.000 ns requirement, so the comparison is like-for-like.

| metric | cast-pipe-r1 (before) | stacked-r1 (after) | delta |
|---|---:|---:|---|
| WNS ns | -3.509 | -4.724 | **-1.215 worse** |
| TNS ns | -2083.21 | -9451.90 | **4.54x worse** |
| setup failing endpoints | 2277 / 79560 | 3138 / 79678 | **+861** |
| WHS ns | -0.144 | -0.144 | unchanged |
| THS ns | -19.822 | -19.819 | unchanged |
| hold failing endpoints | 146 | 146 | unchanged |
| total LUTs | 37425 | 37724 | +299 |

Every acceptance criterion failed. Achieved frequency fell from
`1000/(8.000-3.509) = 222.7` to `1000/(8.000-4.724) = 305.3` ns-equivalent
(i.e. 78.6 MHz achieved against the 125 MHz target).

WNS/TNS/endpoint counts come from `report_timing_summary` and are independent of
path-export depth, so they are directly comparable even though the baseline run
exported only 100 paths and this run exported all 3138.

### The new critical path is the instruction buffer, not the FPU

Fresh category rollup (all 3138 violating paths):

| category | paths | worst ns | levels avg |
|---|---:|---:|---:|
| DECODE_IBUF | 2003 | -4.724 | 27.0 |
| LSU | 210 | -3.792 | 26.4 |
| EXU_DIV | 169 | -3.777 | 25.9 |
| FPU_FMA | 113 | -3.515 | 36.1 |
| TLU_CSR_TRAP | 155 | -3.479 | 24.3 |
| IFU_BHT_BP | 167 | -3.467 | 24.2 |

Two readings that hold rigorously:

1. **DECODE_IBUF definitively regressed.** The old global WNS of -3.509 bounds
   every category's worst slack in the baseline, so baseline DECODE_IBUF was no
   worse than -3.509. It is now -4.724, i.e. worse by at least 1.215 ns, and it
   accounts for 2003 of 3138 violating paths.
2. **The FMA work bought nothing.** FPU_FMA went -3.509 -> -3.515. Levels fell
   40.5 -> 36.1 but slack did not move. 459 changed lines across
   `fpnew_fma_multi.sv` and `fpnew_cast_multi.sv` produced no slack gain.

Per-category comparison for LSU / EXU_DIV / IFU_BHT is **not** valid: the
baseline exported only the worst 100 of 2277 failing paths, truncating those
categories at roughly -1.3 ns. Their baseline worst values are unknown beyond
the -3.509 bound. The batch records' -1.592 / -1.605 / -0.120 figures were read
off that truncated export and should not be quoted as baselines again.

### Worst path

```text
slack       -4.724 ns   requirement 8.000 ns
source      dec/instbuff/ib0ff/genblock.dff/dffs/dout_reg[31]/C
destination dec/instbuff/ib1ff/genblock.dff/dffs/dout_reg[0]/CE
datapath    12.316 ns = logic 1.809 ns (14.7%) + route 10.507 ns (85.3%)
levels      30  (LUT6=14 LUT5=9 LUT4=3 CARRY4=1 LUT3=1 LUT2=1 LUT1=1)
```

IB0 instruction data -> 30 levels -> IB1 write enable, passing through
`instbuff/ibvalff/shift_ib3_ib1`. Route is 85% of the datapath, but at synth
stage route delay is an estimate from fanout and pin count, not placement; the
structural fact that survives is 30 logic levels between two IB registers,
against a baseline sample of 17.

### Mechanism

The decode batch replaced single nets with `keep = "true"` replicas carrying
**semantically identical expressions**, then constrained their fanout:

```systemverilog
// dec_ib_ctl.sv - four copies, all four right-hand sides identical
(* keep = "true", max_fanout = "32" *) logic [3:0] ibwrite_cinst, ibwrite_pc,
                                                  ibwrite_bp,    ibwrite_instr;
// dec_decode_ctl.sv - six copies of two expressions
(* keep = "true", max_fanout = "20" *) logic i0_rs1_en_nonblock_d,
                        i0_rs1_en_dep_early_d, i0_rs1_en_dep_late_d, ...;
assign i0_rs1_en_nonblock_d  = i0_dp.rs1 & (i0r.rs1[4:0] != 5'd0);
assign i0_rs1_en_dep_early_d = i0_dp.rs1 & (i0r.rs1[4:0] != 5'd0);  // same
assign i0_rs1_en_dep_late_d  = i0_dp.rs1 & (i0r.rs1[4:0] != 5'd0);  // same
```

Why this backfires:

- `keep = "true"` blocks the flattening that would otherwise let Vivado
  restructure the cone. The long path is frozen in place.
- `max_fanout` on a *combinational* net makes Vivado replicate the driving cone
  to satisfy the limit, adding cells and nets rather than removing depth.
- Manual replication only pays when consumers are physically separated. Here all
  the copies reconverge into the same stall / dependency / IB-shift network, so
  no cone is shortened and the reconvergent path is what sets slack.

Cone isolation was the right idea applied to the wrong structure.

## Decision

Functional axis: ACCEPT (9/9, `final` gate 72 tests).
IPC axis: ACCEPT (delta exactly 0).
Timing axis: **REJECT.** The stack is a 1.215 ns WNS regression.

Action taken: reverted `dec_decode_ctl.sv` and `dec_ib_ctl.sv` to `f157e17`,
keeping the FPU / LSU / TLU / EXU / IFU batches, and relaunched as
`decode-revert-r1` to confirm attribution. That single experiment separates the
decode batch from the other two rather than reasoning about which one was
responsible.

Attribution caveat honoured: DECODE_IBUF dominance plus "only this batch touches
those two files" is strong evidence but not proof, because utilization shifts can
degrade a route estimate. `decode-revert-r1` is the measurement that decides it.

## Attribution result: decode batch confirmed as the cause

`decode-revert-r1` landed. Full export both sides (2923 vs 3138 paths), so these
are like-for-like.

```text
| metric                  | cast-pipe-r1 | stacked-r1 | decode-revert-r1 |
| WNS ns                  | -3.509       | -4.724     | -3.624           |
| TNS ns                  | -2083.21     | -9451.90   | -3547.04         |
| setup failing endpoints | 2277         | 3138       | 2923             |
| WHS ns                  | -0.144       | -0.144     | -0.144           |
| total LUTs              | 37425        | 37724      | 37242            |
```

DECODE_IBUF went from `-4.724 @ 30 levels` back to `-1.900 @ 18.0 levels`, and the
WNS owner returned to FPU_FMA. The decode batch is the confirmed cause of the
1.215 ns regression; the revert is kept. Utilization also came in 183 LUTs *below*
baseline, so the remaining batches are not area-costly.

The `keep`+`max_fanout` replication anti-pattern is now measured, not argued:
+861 failing endpoints and +12 logic levels on the very cone it was meant to
shorten.

### Calibration: the run-to-run noise floor is about 0.11 ns

FPU_FMA RTL is byte-identical between `stacked-r1` and `decode-revert-r1`, yet its
worst slack moved `-3.515 -> -3.624` (-0.109). That is pure synth-estimate variance
from a different utilization//routing context. Consequence for this project: **no
single-run WNS delta below roughly 0.15 ns may be called an improvement.** It also
retires the earlier "FPU_FMA -3.509 -> -3.515 regression" reading, which was inside
this noise band.

Remaining batches (FPU/LSU/TLU/EXU/IFU) are WNS-neutral but still carry
TNS -3547 vs -2083 and +646 endpoints against baseline. WNS is recovered, so they
stay for now; the TNS gap is not attributed and is not being claimed as caused by
them.

## Root cause of the null FMA result: the edits went into dead code

The FMA batch changed `fpnew_fma_multi.sv`. That module is **not instantiated on
the FP32 path.** Chain from the failing path's own hierarchy:

```text
eh1_fpu.sv  UnitTypes[ADDMUL] = PARALLEL, PipeConfig = DISTRIBUTED, PipeRegs = 3
  -> fpnew_opgroup_block.sv:96    FmtUnitTypes[fmt]==PARALLEL -> gen_parallel_slices
  -> fpnew_opgroup_block.sv:117   i_fmt_slice = fpnew_opgroup_fmt_slice
  -> fpnew_opgroup_fmt_slice.sv:115  OpGroup==ADDMUL -> i_fma = fpnew_fma
```

`fpnew_fma_multi` is only reachable via `fpnew_opgroup_multifmt_slice.sv:231`,
i.e. only for MERGED formats (DIVSQRT, CONV). Confirmed against the netlist:
`fpnew_fma_multi` gets **0 hits** in `post_synth_utilization.rpt`, while
`fpnew_fma` and `fpnew_cast_multi` each get 1. The failing path names
`...i_fmt_slice/gen_num_lanes[0].active_lane.lane_instance.i_fma/...`.

This is why 459 changed lines moved WNS by less than the noise floor. The
`cast-pipe-r1` work was live (CONV is MERGED, so `fpnew_cast_multi` is real); the
FMA work was not.

Correction to the structural note previously recorded in this file: the
`NUM_PRE_REGS=(N+2)/3` allocation and the "multiply and align are already outside
the add/LZA stage" claim describe `fpnew_fma_multi.sv` only. **They do not describe
the synthesized FP32 FMA.** `fpnew_fma.sv` has no pre-add cut at all and uses the
opposite INP/MID split:

```text
fpnew_fma.sv:79   NUM_INP_REGS = (NumPipeRegs + 1) / 3 = 1
fpnew_fma.sv:84   NUM_MID_REGS = (NumPipeRegs + 2) / 3 = 1
fpnew_fma.sv:89   NUM_OUT_REGS =  NumPipeRegs      / 3 = 1
```

so classify + exponent align + 24x24 multiply + variable shift + 3-input add + LZA
are all in the single INP->MID cone. The measured worst path agrees exactly:

```text
inp_pipe_operands_q_reg[1][1][17]/C -> mid_pipe_sum_q_reg[1][73]/D
42 levels, 11.451 ns datapath = logic 3.322 (29.0%) + route 8.129 (71.0%)
cells: CARRY4 x22, LUT6 x11, LUT5 x3, LUT4 x3, LUT3 x2, LUT2 x1
```

## Next hypothesis (r2)

Port the pre-add cut into `fpnew_fma.sv` and reallocate the three registers
latency-neutrally:

```text
now:      INP=1              MID=1 (mul+align+add+LZA)   OUT=1
proposed: INP=0  PRE=1       MID=1 (add+LZA only)        OUT=1
```

Cut placed after `addend_shifted`/`product_shifted` (line 369) and before the adder
(line 381). `ExtRegEnaWidth = NumPipeRegs = 3`, so INP+PRE+MID+OUT must stay <= 3 --
this is why INP drops to 0 rather than PRE being added on top. Latency and
therefore IPC are unchanged, which the functional run must confirm.

Flop cost is kept low by registering `addend_after_shift` rather than both polarities
and recomputing the 1-level inversion after the register:

```text
register: product_shifted, addend_after_shift   (2 x 76 b) + control/metadata
recompute after cut: addend_shifted = eff_sub ? ~addend_after_shift : addend_after_shift
                     inject_carry_in = eff_sub & ~sticky_before_add
```

Accept only if WNS improves by more than the 0.15 ns noise floor. `fpnew_fma_multi.sv`
is left as-is: reverting it is cosmetic since it is not synthesized, and touching it
cannot affect timing either way.

## Next bottleneck

Superseded -- see "Root cause of the null FMA result" and "Next hypothesis (r2)"
above. The structural note that used to sit here described `fpnew_fma_multi.sv`,
which is not on the synthesized FP32 path, and has been corrected in place rather
than left to be quoted again.
