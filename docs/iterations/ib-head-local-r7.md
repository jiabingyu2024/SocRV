# r7 — localize circular-buffer head selectors

Status: **functional PASS; global post-route REJECT.**

## Hypothesis and batch scope

The r6 circular queue removed 48% of post-route `DECODE_IBUF` endpoints, but
replaced the wide shifting cone with one registered `ib_head` source that
launched failures into DIV, LSU, MUL, ALU and branch-packet consumers.  The
representative r6 paths contained 19--20 logic levels and spent about 85% of
their delay in routing.

r7 treats those paths as one physical root-cause cluster.  It adds eight
functionally identical registered head copies, one for each i0/i1 instruction,
PC/error, compressed-instruction and branch-packet read view.  Each copy is
kept independent and carries a `max_fanout=16` hint.  Queue count, tail,
enqueue/dequeue, flush and admission behavior are unchanged, so this remains a
timing-only batch with no expected IPC effect.

## Functional result

| Gate | Result |
|---|---:|
| filelists / generated tree / memory map / schemas / RTL lint | PASS |
| Verilator build-only | PASS |
| smoke | PASS, 156834 cycles |
| ISA `current` | PASS, 40/40 RV32UI |
| RT-Thread + CoreMark | PASS, CRC/checker PASS |

CoreMark remained bit-for-bit performance neutral against r6:

```text
r6  248666 cycles, 299916 commits, IPC 1.206099748
r7  248666 cycles, 299916 commits, IPC 1.206099748
```

The r6 parent also passed the broader `final-base` gate, 61/61
RV32UI/RV32MI/RV32UM tests, before r7 was applied.

## Synthesis result

Compared with r6 synthesis:

| metric | r6 | r7 | delta |
|---|---:|---:|---:|
| WNS (ns) | -3.197 | -2.303 | +0.894 |
| TNS (ns) | -1558.202 | -2217.055 | -658.853 |
| setup failing endpoints | 1798 | 1944 | +146 |
| `DECODE_IBUF` paths | 739 | 891 | +152 |
| `DECODE_IBUF` worst (ns) | -1.333 | -2.298 | -0.965 |
| LUT | 37505 | 37308 | -197 |
| FF | 27970 | 28012 | +42 |

Vivado did create replicated head flops (for example `_rep__20`), and the old
extreme LSU WNS disappeared.  However, its synthesis placement estimate still
grouped many replicated selector cones under the same physical region, growing
TNS and endpoint count.  Because r6 showed a large synth-to-route reversal,
this mixed result is not accepted or rejected until one all-violations
post-route calibration completes.

Implementation run:

```text
build/vivado/kintex7-rtthread-coremark-125mhz-ib-head-local-impl-r7/
```

## Post-route result and decision

| metric | r6 | r7 | delta |
|---|---:|---:|---:|
| WNS (ns) | -0.975 | -1.004 | -0.029 |
| TNS (ns) | -516.181 | -583.696 | -67.515 |
| setup failing endpoints | 1419 | 1458 | +39 |
| hold failing endpoints | 0 | 0 | 0 |
| unconstrained register pins | 0 | 0 | 0 |
| `DECODE_IBUF` paths | 592 | 437 | -155 (-26.2%) |
| `LSU` paths | 136 | 435 | +299 |
| LUT | 37712 | 37521 | -191 |
| FF | 27987 | 28034 | +47 |

The copies did achieve their local purpose: the common head startpoint largely
disappeared from DIV/LSU/MUL, and `DECODE_IBUF` fell another 26%.  The global
placement nevertheless moved a large number of LSU paths into violation.  The
new WNS cluster is an independent 30-level
`stbuf_fwddata_lo_dc3ff -> flush_lower_ff` cone, and LSU category count grew
from 136 to 435.  Route and DRC completed, hold is clean, and no register pins
are unconstrained.

Decision: **REJECT and remove the eight explicit head copies.**  All three
global setup measures are worse than r6, so the local cluster reduction is not
enough to retain the physical hint.  Preserve the result as evidence that
source replication changes startpoint distribution but is too placement
sensitive in this flattened design.  The next batch should pursue a measured
IPC/front-end change or a real pipeline boundary, not add more replication
attributes.
