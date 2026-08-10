# r4 — methodology gap, goal arithmetic, and the dual-track plan

Status: **in progress.** Two background jobs running (HPM attribution sim, r3 impl
calibration). This note records the findings that reframe the campaign so the
direction survives a context reset.

## 1. The goal arithmetic (governs everything)

- Authoritative CoreMark window: **249,055.6 cyc/iter, IPC 1.204** (refreshed
  10-iter regression, linearity confirmed: fixed overhead 1546 cyc, commit ratio
  exactly 2.000).
- Goal: 10,000 iterations in 10 s → 2.4906e9 cycle budget → **249.1 MHz required
  at today's IPC**.
- Best synth-estimated achieved: **97.1 MHz** (r3, WNS -2.303 @ 8.000 ns).
- Plan ceiling is 200 MHz; Kintex-7 -2 physically tops out near there for logic
  this deep. **Frequency alone cannot reach the goal.** Even at a perfect
  200 MHz, cyc/iter must fall 249,056 → 200,000, i.e. **IPC 1.204 → 1.499.**

Conclusion: the IPC/microarchitecture track is load-bearing, not optional. This
is the user's 「不要陷入局部死角，考虑进行微架构调整」.

## 2. The methodology gap (biggest finding this session)

**Every round so far — cast-pipe-r1 through norm-cut-r3 — is `stage: synth`.**
Every MHz number reported (86.0 → 97.1) is a *synthesis estimate* using Vivado's
crude wire-load route model. Confirmed by reading each `timing_summary.json`
(`"stage": "synth"`).

The only impl/route data in the repo is the **baremetal** profile, and it ran at
**50 MHz core** (`CLKOUT0_DIVIDE_F = 20.0` → 1000/20), where it met timing
trivially. So there is **zero impl/route data for this design at any competitive
frequency.** The number that actually judges the goal (post-route) has never been
measured on the CoreMark design.

Why this matters for *what* to optimize — the route% column at r3:

| category    | worst slack | levels | route% |
|-------------|------------:|-------:|-------:|
| FPU_FMA     |      -2.303 |   21.6 |  78.3  |
| LSU         |      -2.148 |   19.5 |  83.6  |
| DECODE_IBUF |      -1.900 |   17.2 |  85.9  |
| EXU_DIV     |      -1.582 |   17.1 |  85.3  |
| EXU_MUL     |      -1.399 |   17.0 |  85.2  |
| TLU_CSR_TRAP|      -1.206 |   15.6 |  85.6  |
| IFU_BHT_BP  |      -1.085 |   15.9 |  85.8  |

Everything is 83–86% route **except FPU_FMA at 78.3%**. Synth route estimates are
pessimistic exactly for high-fanout, physically-scattered nets — and impl
placement + `phys_opt` (AggressiveExplore is enabled) recovers much of that. So
**LSU/DECODE/EXU may largely dissolve at impl, while FPU_FMA (logic-depth-bound)
will not.** Optimizing the 83–86%-route categories at synth risks chasing route
noise that impl already fixes. The r3 impl calibration run resolves this.

### Decode-IBUF root cause (for reference if impl doesn't rescue it)
WNS owner is a **combinational net, fanout 141, driving 552 timing paths**:
`dec/instbuff/ib0ff/.../dout[36]_i_4__1_n_0` (-1.900), plus siblings at fanout
159/137. Chain: `bp3ff/CE = ibwrite[3] ← write_i*_ib3 ← shift_ibval ← shift1/2 ←
dec_i0/i1_decode_d`. The IB write/shift control fans out to ~141 register CE pins
scattered across cinst/pc/bp/ib × 4 slots. The earlier `keep`+`max_fanout` fix
regressed because it was on a *combinational* net (Vivado replicated the driving
cone and it reconverged). The IPC-neutral fix, if still needed post-impl, is
source-flop replication, not combinational-net attributes.

## 3. r4 change — ready, held pending impl confirmation

FMA depth 4 → 5. The four current cuts are PRE (post-multiply), MID (post-add),
NORM (post-normalize), OUT (post-round). The deepest remaining *logic* segment is
**MID→NORM: LZC over the lower sum + shift-amount calc + the large barrel
shifter** (`fpnew_fma.sv` lines 646–683). A 5th cut registers `norm_shamt`,
`normalized_exponent`, and `sum_q` **between the shift-amount calc (line 661–680)
and `sum_shifted = sum_q << norm_shamt` (line 683)**, splitting the LZC/priority
logic from the barrel-shifter mux.

Why this is the right hedge: FMA is the one category that is logic-bound, so it is
the change impl placement will NOT make redundant; and FP latency is proven
IPC-free for CoreMark (r2, r3 each added a stage at 0 cycle cost, ISA `final`
gate passing). Requires bumping `eh1_fpu.sv` ADDMUL PipeRegs 4 → 5.

**Do not apply until r3 impl shows FMA is the surviving post-impl bottleneck** —
otherwise it is optimizing the synth proxy again.

## 4. IPC track — infrastructure landed

Added `hpm_arm`/`hpm_read` FinSH commands (`cmd_hpm.c`) that program EH1's four
programmable counters (mhpmevent3..6) and dump mcycle/minstret + counters, so the
~249k cyc/iter can be attributed to fetch/decode/LSU-freeze/dbus stalls and
branch mispredicts instead of guessed at. First attribution run
(`hpm_arm 28 30 33 48` = fetch/decode/lsu-freeze/dbus) is in flight.

BP config (context for IPC work): BTB 512 (depth 64), BHT 2048, GHR 9-bit gshare,
return-stack 4 — already healthy for EH1. CoreMark's ~4.0 CoreMark/MHz is near
this core's architectural design point, so the IPC lift is genuinely hard and
must be data-driven off the HPM breakdown.
