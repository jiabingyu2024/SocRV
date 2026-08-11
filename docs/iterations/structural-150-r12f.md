# RTL optimization iteration: structural-150-r12f

- Started: `2026-08-11T13:16:25.139443+00:00`
- Git revision: `eae3dd1d35324cc3a88c51425ae80a975d5d6af0`
- Target core frequency: **150 MHz**
- Vivado stage: `impl`
- Overall status: **PASS**

## Commands and logs

| Step | Status | Log |
|---|---|---|
| `check_filelists` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/check_filelists.log` |
| `check_generated_tree` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/check_generated_tree.log` |
| `check_memory_map` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/check_memory_map.log` |
| `validate_schemas` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/validate_schemas.log` |
| `lint_rtl` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/lint_rtl.log` |
| `verilator-build` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/verilator-build.log` |
| `sim-smoke` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/sim-smoke.log` |
| `sim-isa` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/sim-isa.log` |
| `sim-coremark` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/sim-coremark.log` |
| `vivado` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/vivado.log` |
| `vivado-analysis` | **PASS** | `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/iterations/structural-150-r12f/logs/vivado-analysis.log` |

## Compact results

### Simulation

- Result: `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/result/soc/opt-structural-150-r12f-coremark-1.json`
- Status: **PASS**
- Full run cycles / commits / IPC: `10112852` / `2233981` / `0.220905141`
- CoreMark cycles / retired / IPC: `293172` / `299916` / `1.023003561`
- CoreMark CRC/checker: **True**

### Vivado

- AI summary JSON: `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/vivado/kintex7-rtthread-coremark-150mhz-structural-150-r12f/analysis/timing_summary.json`
- AI summary Markdown: `E:/Resources/03_competitions/26_03_jcs/2608round/SocRV/build/vivado/kintex7-rtthread-coremark-150mhz-structural-150-r12f/analysis/timing_summary.md`
- WNS / TNS / WHS / THS: `-1.322` / `-1528.911` / `0.077` / `0.0`
- Top setup cluster: `DECODE_IBUF | dec/instbuff/ib_front0_ff -> dec/instbuff/ib_front0_ff | clk_core_unbuffered->clk_core_unbuffered`

## Next action

Read the compact Vivado summary and simulation JSON first. Open raw `.rpt`/`.log` only for the selected representative path or a failure reproduction.
