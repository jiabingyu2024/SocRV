# Iteration r2: pre-add pipeline cut in `fpnew_fma.sv`

Single hypothesis, per §7 of the optimization plan.

## Hypothesis

`fpnew_fma.sv` (the module actually synthesized on the FP32 ADDMUL path) had no
pre-add register. Classification, exponent alignment, the 24x24 mantissa multiply,
the variable addend shift, both adders and the LZA all sat in one INP->MID cone,
measured at 42 logic levels / 22 CARRY4 / -3.624 ns.

Inserting a cut between the addend shift and the adder, and reallocating the three
available registers so total latency is unchanged, should roughly halve that cone.

```text
before:  INP=1              MID=1 (mul + align + add + LZA)   OUT=1
after:   INP=0   PRE=1      MID=1 (add + LZA only)            OUT=1
```

`ExtRegEnaWidth == NumPipeRegs == 3` bounds INP+PRE+MID+OUT, which is why INP drops
to 0 instead of PRE being stacked on top.

## Change

`rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_fma.sv` only. One file.

- `NUM_INP_REGS` for DISTRIBUTED becomes 0; new `NUM_PRE_REGS = (NumPipeRegs+2)/3`;
  `NUM_MID_REGS` for DISTRIBUTED becomes `(NumPipeRegs+1)/3`. BEFORE / INSIDE / AFTER
  behaviour is untouched.
- New `gen_preadd_pipeline` stage with the same ready/valid/flush protocol as the
  existing stages.
- `reg_ena_i` index bases shifted: mid uses `NUM_INP_REGS + NUM_PRE_REGS + i`, out uses
  `NUM_INP_REGS + NUM_PRE_REGS + NUM_MID_REGS + i`.
- Flop cost kept to 2 x (3p+4) bits by registering `addend_after_shift` rather than
  both polarities, then recomputing on the far side:

```systemverilog
assign addend_shifted  = (eff_sub_pre_q) ? ~addend_after_shift_q : addend_after_shift_q;
assign inject_carry_in = eff_sub_pre_q & ~sticky_before_add_pre_q;
```

Register allocation stays consistent at other depths: N=1 -> PRE=1 only (the register
lands on the longest cone); N=2 -> PRE=1, MID=1; N=4 -> PRE=2, MID=1, OUT=1.

## Functional result: PASS

`run_optimization_iteration.py --tag verify-fma-cut-r2 --isa-gate final --skip-vivado`

9/9 steps PASS, `checker_passed = True`. Perf window bit-identical to
`decode-revert-r1`:

```text
perf_cycles  250728 -> 250728   (+0)
perf_commits 299890 -> 299890   (+0)
perf_ipc     1.196077024 -> 1.196077024   (+0)
```

Caveat on what that proves: CoreMark is integer-only, so the identical IPC confirms
the change is inert for integer code but says nothing about FP. The FP correctness
evidence is the ISA `final` gate (72 tests, F extension included), which passed.
Latency-neutrality is a structural argument -- register count is unchanged at 3 --
not something CoreMark measured.

## Timing result: ACCEPT

All figures from `analysis/timing_summary.json` -> `timing` / `utilization`, which is
the design-level block. (Not `clock_interaction[i].wns_ns` -- that is a rounded
per-clock-pair value and reading it recursively is how an earlier draft of this file
got -2.664 instead of -2.656.)

```text
| metric                  | cast-pipe-r1 | decode-revert-r1 | fma-cut-r2 |
| WNS ns                  | -3.509       | -3.624           | -2.656     |
| TNS ns                  | -2083.214    | -3547.042        | -3333.073  |
| setup failing endpoints | 2277         | 2923             | 2922       |
| setup total endpoints   | 79560        | 79678            | 79787      |
| WHS ns                  | -0.144       | -0.144           | -0.144     |
| THS ns                  | -19.822      | -19.842          | -19.842    |
| hold failing endpoints  | 146          | 146              | 146        |
| total LUTs              | 37425        | 37242            | 37221      |
| FF                      | 27898        | 27897            | 27932      |
| achieved MHz            | 86.9         | 86.0             | 93.8       |
```

WNS **+0.968 ns** against the previous round, far outside the 0.15 ns noise floor
established in `stacked-r1.md`. Hold is bit-identical (WHS, THS and hold endpoints all
unchanged), so nothing was traded away on that axis.

Two results worth noting because they contradict the naive cost model:

- **LUTs went down 21.** Shortening the cones let Vivado restructure more than the new
  stage cost.
- **FF went up only 35**, against a predicted ~152 for two 3p+4 = 76 bit banks. Most of
  the new register bank was absorbed by retiming/merging elsewhere; the `addend_shifted`
  recompute trick means only one of the two 76-bit vectors is genuinely new.

Against `cast-pipe-r1` (the pre-stack baseline) WNS is +0.853 ns better and LUTs are
204 lower, but TNS is 1249.86 worse and there are +645 more failing endpoints. That
TNS/endpoint gap belongs to the still-unattributed LSU/TLU/EXU/IFU batches, not to this
change -- this round moved TNS in the *good* direction by 213.97.

FPU_FMA cone, before -> after:

```text
worst slack   -3.624  ->  -2.656
mean slack    -2.823  ->  -0.937
levels avg     36.8   ->   22.6
paths          113    ->   112
```

The mean improving by 1.9 ns is the real signal: this is the whole cone getting
shorter, not one path being shuffled.

Achieved frequency: 1000/(8.0-(-2.656)) = **93.8 MHz** against the 125 MHz target.
Still failing the round's frequency goal, so the acceptance is on the hypothesis,
not on the target.

## Where the FMA path went

The cut moved the FMA's own worst path from INP->MID to MID->OUT:

```text
mid_pipe_sum_q_reg[1][41]/C -> out_pipe_status_q_reg[1][UF]/D
29 levels, logic 2.345 + route 8.138
cells: CARRY4 x10, LUT6 x13, LUT5 x1, LUT4 x1, LUT3 x2, LUT2 x2
```

That stage is normalization + LZC shift + rounding + classification. So the FMA is now
roughly balanced across its stages rather than having one dominant cone.

## Fresh bottleneck ranking

```text
| category     | paths | worst  | mean   | levels | route% |
| FPU_FMA      |  112  | -2.656 | -0.937 |  22.6  |  77.8  |
| LSU          |  186  | -2.148 | -1.285 |  19.5  |  83.6  |
| DECODE_IBUF  | 1860  | -1.900 | -1.284 |  17.2  |  85.9  |
| EXU_DIV      |  169  | -1.582 | -0.905 |  17.1  |  85.2  |
| EXU_MUL      |  122  | -1.405 | -0.832 |  17.0  |  85.1  |
| TLU_CSR_TRAP |  155  | -1.206 | -0.578 |  15.6  |  85.6  |
| IFU_BHT_BP   |  163  | -1.085 | -0.885 |  15.9  |  85.8  |
| FPU_OTHER    |  155  | -0.725 | -0.721 |  15.0  |  85.9  |
```

Two different problems now, and they want different treatment:

- **WNS** is owned by FPU_FMA (-2.656) then LSU (-2.148). Both are deep-logic paths
  (22.6 and 19.5 levels, 10-11 CARRY4) where a structural cut is the lever.
- **TNS / endpoint count** is owned by DECODE_IBUF: 1860 of 2922 violating paths at
  only 17.2 levels and 85.9% route. Shallow and wide. This is the cluster that will
  keep TNS high after WNS is fixed, and its 86% route share means the synth-stage
  number is soft -- it is the one most likely to change under real placement.

LSU worst path for the next round's reference:

```text
lsu/stbuf/stbuf_fwddata_lo_dc3ff/.../dout_reg[15]/C -> dec/tlu/flush_lower_ff/dout_reg[27]/D
31 levels, logic 2.48 + route 7.495
cells: CARRY4 x11, LUT6 x14, LUT5 x2, LUT4 x2, LUT3 x2
```

Store-buffer forwarding data reaching a TLU flush decision in one cycle.

## Standing constraints carried forward

- Do not quote per-category worst slack across runs with different export depths.
  Full exports only, or use the global-WNS bounding argument.
- No single-run WNS delta below ~0.15 ns counts as an improvement.
- `keep` + `max_fanout` replication of identical expressions on reconvergent cones is
  a measured anti-pattern here (see `stacked-r1.md`).
- `fpnew_fma_multi.sv` and the multifmt slice are only reachable for MERGED formats
  (DIVSQRT, CONV). Editing them cannot affect the FP32 ADDMUL path. Check the
  instantiation chain before assuming a vendor file is live.
