# r6 — circular instruction buffer removes wide dequeue feedback

Status: **functional validation PASS; target cluster reduced; global post-route REJECT.**

## Batch hypothesis and coverage target

The first CoreMark-profile post-route calibration at 125 MHz (`impl-r4`) had
WNS **-0.665 ns**, TNS **-403.760 ns**, **1388** setup failures and no hold
failures.  This is a batch target rather than a single-path edit:

- `DECODE_IBUF` owns the largest clusters and the WNS path;
- the same `ib0/ib1 -> decode` cone also reaches LSU, DIV and TLU controls;
- instruction-buffer nets with fanout 160/159/142/141 occur on hundreds of
  failing paths;
- the old buffer physically shifts instruction, PC, branch packet and
  compressed-instruction metadata whenever decode consumes one or two entries.

The shared root cause is that a same-cycle decode/hazard decision drives the
write/shift muxes for roughly 117 payload bits.  The predicted result is a
large reduction in `DECODE_IBUF` failing endpoints and route delay, with a risk
that the new head-indexed read mux moves some delay to decode/LSU/DIV paths.

## RTL change

`dec_ib_ctl.sv` now implements the four-entry instruction buffer as a circular
queue:

- registered 2-bit head and tail pointers plus a 3-bit count;
- dequeue changes only head/count;
- enqueue writes a stationary physical slot selected only by the registered
  tail pointer;
- instruction, PC/error metadata, branch packet and compressed instruction
  remain together in each physical slot;
- two local 4:1 read muxes expose logical entries 0 and 1 to decode;
- flush clears head/tail/count, and the original pre-dequeue admission policy is
  retained.

This removes the wide decode-to-payload feedback instead of asking Vivado to
replicate a reconvergent combinational net.

## Functional and performance result

All checks below use one newly built model containing the circular buffer:

| Gate | Result |
|---|---:|
| filelists / generated tree / memory map / schemas / RTL lint | PASS |
| Verilator build-only | PASS |
| smoke (`opt-ib-ring-r6-smoke`) | PASS, 156834 cycles |
| ISA `current` (40 RV32UI tests) | PASS, 40/40 |
| RT-Thread + CoreMark (`opt-ib-ring-r6-coremark-1`) | PASS, CRC PASS |

Authoritative CoreMark performance window:

```text
pre-change HPM baseline  248728 cycles, 299916 commits, IPC 1.205799
ib-ring-r6               248666 cycles, 299916 commits, IPC 1.206100
delta                         -62 cycles (-0.025%)
```

The structural queue change therefore has no measurable IPC penalty.  The
single-iteration difference is below run-to-run noise and is not claimed as an
IPC improvement.

## Parallel IPC attribution

The baseline was deliberately measured against the frozen pre-r6 model while
the RTL batch was being developed.  While Vivado synthesized r6, the same two
HPM groups were rerun against the fingerprint-matched r6 model.  Every counter
was unchanged:

```text
event group        pre-r6   ib-ring-r6   delta
mcycle              248539       248539       0
minstret             299872       299872       0
fetch-stall          102166       102166       0  (41.1% of cycles)
decode-stall          43645        43645       0  (17.6% of cycles)
lsu-freeze                0            0       0
dbus-stall                0            0       0

mcycle              248401       248401       0
minstret             299872       299872       0
aligner-stall         39184        39184       0  (15.8% of cycles)
ibus-stall                0            0       0
branch-error             36           36       0
stbuf-wb-stall            0            0       0
```

Event classes can overlap, so percentages must not be summed.  The exact
before/after match confirms that r6 is a timing-only structural change.  The
next IPC batch should investigate IFU/aligner supply and decode bubbles before
LSU/dbus or branch-predictor capacity.  In particular, the current four-entry
buffer refuses new instructions based on pre-dequeue occupancy, even when the
same cycle's decode frees one or two slots; r6's stationary payload makes that
conservative admission rule or a deeper elastic queue the next measurable
front-end target.

## Synthesis timing result: target hit

Compared with the same-stage `norm-cut-r3` synthesis:

| metric | norm-cut-r3 | ib-ring-r6 | delta |
|---|---:|---:|---:|
| setup failing endpoints | 2887 | 1798 | -1089 (-37.7%) |
| TNS (ns) | -3282.251 | -1558.202 | +1724.049 (52.5% less negative) |
| `DECODE_IBUF` paths | 1860 | 739 | -1121 (-60.3%) |
| `DECODE_IBUF` worst (ns) | -1.900 | -1.333 | +0.567 |
| `DECODE_IBUF` avg levels | 17.2 | 15.5 | -1.7 |
| total LUT | 37339 | 37505 | +166 |
| FF | 27986 | 27970 | -16 |

The batch therefore removed most of the intended wide shift-feedback paths.
The new worst decode path starts at a replicated `ib_head` flop, so head/read
view localization is the remaining r6-specific timing issue.

Global synth WNS regressed from -2.303 to **-3.197 ns** because the pre-existing
LSU store-buffer-to-TLU-flush cone changed from roughly 31 to 33 logic levels.
That cone is not connected to the modified instruction-buffer payload and was
strongly rescued by the previous post-route calibration.  The regression is
too large to dismiss as noise, but synth alone cannot decide whether it is a
global flattening/optimization perturbation or a real physical regression.

Post-route calibration:

```text
synth: build/vivado/kintex7-rtthread-coremark-125mhz-ib-ring-r6/
impl:  build/vivado/kintex7-rtthread-coremark-125mhz-ib-ring-impl-r6/
```

## Post-route result: local gain, global rejection

The full all-violations implementation completed successfully, with routed DRC
clean, no unconstrained register pins, and no hold violations.  The setup result
did not beat the same-stage `impl-r4` baseline:

| metric | impl-r4 | ib-ring-impl-r6 | delta |
|---|---:|---:|---:|
| WNS (ns) | -0.665 | -0.975 | -0.310 |
| TNS (ns) | -403.760 | -516.181 | -112.421 |
| setup failing endpoints | 1388 | 1419 | +31 |
| hold failing endpoints | 0 | 0 | 0 |
| unconstrained register pins | 0 | 0 | 0 |
| `DECODE_IBUF` paths | 1138 | 592 | -546 (-48.0%) |
| `EXU_DIV` paths | 90 | 194 | +104 |
| `LSU` paths | 92 | 136 | +44 |
| `EXU_MUL` paths | 11 | 99 | +88 |
| `IFU_BHT_BP` paths | 52 | 179 | +127 |
| LUT | 37609 | 37712 | +103 |
| FF | 28059 | 27987 | -72 |

The circular queue removed nearly half of the intended decode-buffer endpoints,
but the new dynamic read selector became the common launch point for failures
across DIV, LSU, MUL, ALU and branch-packet consumers.  Representative paths
start at `ib_head_ff[0]`, contain 19--20 logic levels, and spend about 85% of
their delay in routing.  One independent 32-level DIV-to-TLU path is the WNS
path, but most of the enlarged non-DECODE clusters share the head selector and
are therefore r6-specific rather than unrelated noise.

Decision: **REJECT as a timing baseline, retain as the parent of a corrective
batch.**  Do not promote r6 to a frequency milestone.  The next timing batch
must replicate and localize the registered head/read selectors as a single
cross-cluster fix, then rerun function and full timing validation.  The
conservative-admission/deeper-elasticity idea remains a separate IPC hypothesis
and must not be mixed into that timing correction.
