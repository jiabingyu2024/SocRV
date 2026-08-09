# improve_v3 true-170 MHz final comparison

Both candidates were rebuilt with one consistent 170 MHz contract covering the MMCM, RTL SoC/UART constant, board metadata, timer, CoreMark timebase, software, ELF and BRAM images. The earlier mixed-contract v3.1 archive is excluded from this comparison.

| Metric | v3.1 | v3.2 | v3.2 change |
|---|---:|---:|---:|
| CoreMark 10 performance-window cycles | 3,951,849 | 3,952,563 | +714 (+0.0181%) |
| Predicted CoreMark 10000 at 170 MHz | 23.246171 s | 23.250371 s | +0.004200 s |
| Post-synth WNS | -3.254 ns | -3.254 ns | unchanged |
| Post-synth TNS | -3461.238 ns | -2720.091 ns | 741.147 ns less violation |
| Routed WNS | -1.169 ns | -1.131 ns | +0.038 ns |
| Routed TNS | -2893.260 ns | -2464.566 ns | 428.694 ns less violation |
| Final post-route Explore WNS | -0.921 ns | -0.826 ns | +0.095 ns |
| Final post-route Explore TNS | -2270.284 ns | -1947.764 ns | 322.520 ns less violation |
| Final failing setup endpoints | 5,630 | 5,469 | -161 |
| Final WHS / THS | +0.068 / 0 ns | +0.061 / 0 ns | both clean |
| Estimated timing-limited Fmax | 146.99 MHz | 149.07 MHz | +2.08 MHz |

v3.2 is selected as the final `improve_v3` release. Its CoreMark cost is negligible and remains 47,437 cycles below the four-million-cycle limit, while every final setup metric improves. The predictor's GShare policy, history, counters and update behavior are preserved; only BTB capacity changes from 128 to 512 entries.

The v3.2 automatic optional post-route Explore run crashed with a Vivado access violation. A clean standalone recovery reopened the complete routed DCP, completed the same directive, generated a fresh checkpoint and reports, passed bitstream DRC with 0 errors / 54 warnings, and exported the final bitstream. No v3.3 iteration is planned.
