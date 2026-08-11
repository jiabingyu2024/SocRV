# RTL optimization iteration: structural-150-r9-vivado

- Started: `2026-08-11T07:50:38.194792+00:00`
- Git revision: `eae3dd1d35324cc3a88c51425ae80a975d5d6af0`
- Target core frequency: **150 MHz**
- Vivado stage: `impl`
- Overall status: **PASS**

## Commands and logs

| Step | Status | Log |
|---|---|---|
| `vivado` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r9-vivado/logs/vivado.log` |
| `vivado-analysis` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r9-vivado/logs/vivado-analysis.log` |

## Compact results

### Vivado

- AI summary JSON: `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/vivado/kintex7-rtthread-coremark-150mhz-structural-150-r9-vivado/analysis/timing_summary.json`
- AI summary Markdown: `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/vivado/kintex7-rtthread-coremark-150mhz-structural-150-r9-vivado/analysis/timing_summary.md`
- WNS / TNS / WHS / THS: `-2.64` / `-4056.045` / `0.04` / `0.0`
- Top setup cluster: `CLOCK_RESET_CDC | peripherals/timer/mtime_reg[*] -> timer_irq_meta_q_reg | clk_peripheral_unbuffered->clk_core_unbuffered`

## Next action

Read the compact Vivado summary and simulation JSON first. Open raw `.rpt`/`.log` only for the selected representative path or a failure reproduction.
