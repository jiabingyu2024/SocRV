# Iteration r3: post-normalize cut in `fpnew_fma.sv`, ADDMUL depth 3 -> 4

Single hypothesis, continuing directly from r2.

## Hypothesis

After r2 the FMA's own worst path was MID->OUT:

```text
mid_pipe_sum_q_reg[1][41]/C -> out_pipe_status_q_reg[1][UF]/D   29 levels
```

That stage carries LZC + normalization shift amount + the large left shift + the 1-bit
small-norm fixup + sticky update + rounding + classification. Splitting it after
normalization and before rounding should shorten it.

`fpnew_fma.sv` has **four** natural cut points, not three (pre-add, post-add/LZA,
post-normalize, post-round), so DISTRIBUTED was generalized to a four-way split and
ADDMUL depth raised 3 -> 4 to put one register on each.

```text
r2:  PRE=1  MID=1 (add+LZA)  [ LZC+norm+round+classify ]  OUT=1     N=3
r3:  PRE=1  MID=1 (add+LZA)  NORM=1 (LZC+norm)  OUT=1 (round+classify)  N=4
```

Fill order is PRE, MID, NORM, OUT, so shallower pipelines still put their registers on
the longest cones first: N=1 -> PRE only; N=2 -> PRE+MID; N=3 -> PRE+MID+NORM.

## Change

Two files.

- `fpnew_fma.sv`: new `NUM_NORM_REGS = (NumPipeRegs+1)/4`; PRE/MID/OUT divisors changed
  from 3 to 4; new `gen_norm_pipeline` stage; rounding, classification, result select and
  the output pipeline rewired onto the registered copies; `reg_ena_i` base for the output
  stage extended by `NUM_NORM_REGS`.
- `eh1_fpu.sv`: ADDMUL `PipeRegs` 3 -> 4. DIVSQRT/NONCOMP/CONV untouched.

The cut is deliberately narrow. `sum_sticky_bits` is 2p+3 = 51 bits, but the rounding
block reads exactly one bit of it (`[MAN_BITS*2+4]`, the UF tie-break), so only that bit
crosses:

```text
registered: final_mantissa (25 b), final_exponent (EXP_WIDTH), sticky_after_norm (1 b),
            sum_sticky_bits[MAN_BITS*2+4] (1 b), sign, rnd_mode, eff_sub,
            result_is_special, special_result, special_status, tag, mask, aux, valid
NOT registered: the other 50 bits of sum_sticky_bits
```

## Functional result: PASS

`--tag verify-norm-cut-r3 --isa-gate final --skip-vivado` -> 9/9 PASS,
`checker_passed = True`.

```text
perf_cycles  250728 -> 250728   (+0)
perf_commits 299890 -> 299890   (+0)
perf_ipc     1.196077024 -> 1.196077024   (+0)
```

### This round settled an open question: FP latency is free against the goal metric

r3 adds a genuine cycle of FMA latency (depth 3 -> 4). CoreMark's measured window did not
move by a single cycle, while the ISA `final` gate -- which does exercise F -- still passes.

So the measured CoreMark window executes no FP that gates its critical resource, and FMA
latency does not enter the objective. **FPU pipeline depth can be spent freely on
frequency.** This retires the concern that pipelining the FPU trades IPC for MHz; for this
benchmark it does not.

Corollary worth keeping: the FPU is therefore the *cheapest* place to buy frequency, but
only while it owns WNS. Once it does not (see below), depth stops paying.

## Timing result: ACCEPT

```text
| metric                  | decode-revert-r1 | fma-cut-r2 | norm-cut-r3 |
| WNS ns                  | -3.624           | -2.656     | -2.303      |
| TNS ns                  | -3547.042        | -3333.073  | -3282.251   |
| setup failing endpoints | 2923             | 2922       | 2887        |
| WHS ns                  | -0.144           | -0.144     | -0.144      |
| THS ns                  | -19.842          | -19.842    | -19.842     |
| total LUTs              | 37242            | 37221      | 37339       |
| FF                      | 27897            | 27932      | 27986       |
| achieved MHz            | 86.0             | 93.8       | 97.1        |
```

WNS **+0.353 ns**, outside the 0.15 ns noise floor. Cost was +118 LUT and +54 FF -- this
one did not pay for itself in area the way r2 did, but it is cheap. Hold untouched.

FMA cone: worst -2.656 -> -2.303, mean -0.937 -> -0.727, levels 22.6 -> 21.6, and the
violating path count dropped 112 -> 77.

Cumulative across r2+r3: WNS -3.624 -> -2.303 (**+1.321 ns**), 86.0 -> 97.1 MHz, for
+97 LUT / +89 FF and zero IPC cost.

## The FPU has stopped being the lever

```text
| category     | paths | worst  | mean   | levels | route% |
| FPU_FMA      |   77  | -2.303 | -0.727 |  21.6  |  78.3  |
| LSU          |  186  | -2.148 | -1.284 |  19.5  |  83.6  |
| DECODE_IBUF  | 1860  | -1.900 | -1.284 |  17.2  |  85.9  |
| EXU_DIV      |  169  | -1.582 | -0.903 |  17.1  |  85.3  |
| EXU_MUL      |  122  | -1.399 | -0.827 |  17.0  |  85.2  |
| TLU_CSR_TRAP |  155  | -1.206 | -0.577 |  15.6  |  85.6  |
| IFU_BHT_BP   |  163  | -1.085 | -0.885 |  15.9  |  85.8  |
| FPU_OTHER    |  155  | -0.725 | -0.721 |  15.0  |  85.9  |
```

FPU_FMA -2.303 and LSU -2.148 are now within 0.155 ns of each other. **A perfect FMA fix
from here would move design WNS by at most 0.155 ns**, which is inside/at the noise floor.
Further FMA depth is not worth a round even though it is IPC-free.

Where the FMA path went, for the record -- it moved *upstream* of everything r2/r3 touched:

```text
dec/decode/fpu/inst_q_reg[5]/C -> i_fma/gen_preadd_pipeline[0].pre_pipe_sticky_q_reg[1]/D
23 levels, logic 1.907 + route 8.223
```

This starts in `eh1_fpu.sv`'s own instruction register, because r2 set `NUM_INP_REGS = 0`
for DISTRIBUTED. Operands and the decoded op now run from the wrapper flops straight into
classify + exponent + multiply + align. If the FPU ever owns WNS again, the fix is a
five-way split (INP as a fifth cut) at ADDMUL depth 5, which r3 has shown costs no IPC.
Caveat to check first if that is attempted: a five-way fill order must not starve OUT,
since dropping OUT to 0 makes `result_o` combinational out of rounding and pushes the path
into the wrapper's result consumer.

## Next hypothesis (r4): the LSU store-buffer to TLU flush path

New WNS owner once FMA is discounted, and the deepest logic cone left in the design:

```text
lsu/stbuf/stbuf_fwddata_lo_dc3ff/genblock.dff/dffs/dout_reg[15]/C
  -> dec/tlu/flush_lower_ff/dout_reg[27]/D
31 levels, logic 2.48 + route 7.495, slack -2.148
cells: CARRY4 x11, LUT6 x14, LUT5 x2, LUT4 x2, LUT3 x2
```

Store-buffer forwarding data reaching a TLU flush decision within one cycle, crossing a
module boundary. 11 CARRY4 means real arithmetic/compare width in the cone, not just
control. 19.5 average levels over 186 paths.

Note this is a *different kind* of target from r2/r3: those were vendor FP datapath with
clean ready/valid stage boundaries, where adding latency was provably free. LSU/TLU is
core control logic where added latency changes flush timing and therefore correctness and
IPC. The IPC-is-free result from r3 does **not** transfer.

## Standing constraints carried forward

- Read `timing_summary.json` -> `timing` / `utilization` only. `clock_interaction[i].wns_ns`
  is rounded per-clock-pair; a recursive key search hits it first and misreports deltas.
- Single-run WNS deltas below ~0.15 ns are noise.
- Compare per-category worst slack only between full (`--all-violations`) exports.
- `keep` + `max_fanout` replication on reconvergent cones is a measured anti-pattern here.
- Vendor-file check before editing: `fpnew_fma_multi.sv` and `fpnew_opgroup_multifmt_slice.sv`
  serve MERGED formats only (DIVSQRT, CONV). FP32 ADDMUL goes through
  `fpnew_opgroup_fmt_slice.sv` -> `fpnew_fma.sv`.
- DECODE_IBUF holds 1860 of 2887 violating paths at 85.9% route. It will dominate TNS after
  WNS is fixed, and being route-dominated at synth stage, its number is the softest in the
  table -- worth re-checking under real placement before investing a round in it.
