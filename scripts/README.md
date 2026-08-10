# SocRV scripts

根目录 `Makefile` 是稳定的人类入口，`scripts/` 负责参数检查、工具调用、内存镜像生成以及结果 manifest。当前唯一目标配置是：

- ISA：`RV32IMF_Zicsr`
- ABI：`ilp32f`
- ICCM：128 KiB
- DCCM：64 KiB
- 无 C、无 cache、无 ECC、无 AXI/AHB 外部存储
- FPGA 默认 core 目标频率：100 MHz；外设固定 50 MHz

主要链路：

```text
fetch_dependencies.py
  -> 固定 RT-Thread / riscv-tests / CoreMark 依赖

generate_soc_contract.py
  -> 根据 data/soc/ 生成 BSP 头文件和 linker 常量

generate_isa_data.py
  -> 生成官方 riscv-tests 的 ICCM/DCCM 镜像与 manifest

build_software.py
  -> 编译 RV32 ELF
  -> 生成 ICCM 四个 lane 与 DCCM 八个 bank 的初始化文件

run_verilator.py
  -> 构建/运行 SoC 仿真模型并记录 UART、状态和结果

run_regression.py
  -> 按 data/tests/soc.json 运行受控回归

run_vivado.py
  -> 构建/复用软件镜像，分阶段运行 synth/impl/bitstream
  -> 自动生成 top-path 或全违例报告和 AI 紧凑摘要

analyze_vivado_reports.py
  -> 解析 setup/hold、summary、utilization、clock interaction、CDC
  -> 按功能/hierarchy/clock pair 聚类并输出 Markdown/JSON/CSV

run_optimization_iteration.py
  -> fail-fast 串联静态门禁、smoke、ISA、CoreMark、Vivado 和聚类
  -> 保存每步日志及 docs/iterations/<tag>.md/.json
```

推荐入口：

```text
make doctor
make check
make sim-quick
make sim-full
make software-fpga
make fpga-build
```

注意：仓库中旧的 `data/isa/` 或 `build/images/` 只有在 `check_images.py` 同时确认内存映射哈希、CODE/DATA 范围和测试状态地址后才可使用。更改 `data/soc/` 后必须重新生成镜像，不能继续使用旧 `.mem` 文件。


## RTL 优化专用入口

```powershell
# 只分析已有报告，不重新运行 Vivado
python -B scripts/analyze_vivado_reports.py `
  --build-root build/vivado/<run> --stage synth

# 已有工程补导出所有负 slack endpoint，再聚类
python -B scripts/analyze_vivado_reports.py `
  --build-root build/vivado/<run> --stage synth --export-all

# 一键 RTL 迭代
python -B scripts/run_optimization_iteration.py `
  --tag <tag> --core-mhz 125 --jobs 8 `
  --vivado-stage synth --vivado-all-violations
```

聚类输出位于 `build/vivado/<run>/analysis/`。大模型默认先读 `timing_summary.md`、`timing_summary.json`、仿真 `build/result/soc/*.json` 和 ISA `build/regression/isa/*/summary.json`；不要先读完整 `.rpt`、UART log、波形或 Vivado run 目录。

### 紧凑报告工具

四个只读脚本，用于把大报告压成可进上下文的小输出。完整参数说明见 `docs/core_100mhz_to_10s_optimization_plan.md` 第 10.7 节。

| 脚本 | 作用 | 替代的原始文件 | Make 入口 |
|---|---|---|---|
| `iteration_status.py` | 每轮第一条命令：仿真 + ISA + CoreMark 窗口 + 时序资源摘要合成一页，给出 BLOCKED/CLEAR | 多个 result/summary JSON 与 `timing_summary.*` | `make iter-status`、`make iter-trend` |
| `show_timing_path.py` | 按 index / endpoint / category 抽取单条路径的门级链、延时热点或高扇出网 | `*_setup_paths.rpt`（3.3 MB）、`all_setup_violations.rpt`（30.8 MB） | `make fpga-path` |
| `query_timing_paths.py` | 在 `analysis/*_paths.csv` 上按 cluster / 层级 / 扇出聚合筛选，支持跨 run diff | 同上 | `make fpga-paths` |
| `summarize_utilization.py` | 层级资源表 + 跨 run 资源差，用于面积归因 | `*_utilization.rpt`（2.0 MB / 8832 行） | `make fpga-util` |

```powershell
# 每轮起手
make iter-status VIVADO_BUILD=build/vivado/<run>

# 定位到 cluster，再看代表路径
make fpga-paths VIVADO_BUILD=build/vivado/<run> PATH_GROUP=cluster
make fpga-path  VIVADO_BUILD=build/vivado/<run> PATH_INDEX=1 PATH_MODE=hotspots

# ACCEPT/REJECT 前做资源归因
make fpga-util VIVADO_BUILD=build/vivado/<run> UTIL_DIFF=build/vivado/<previous-run>
```

这些脚本的行为由 `make test-scripts` 保护（当前 23 个用例，覆盖时钟树扇出误判、utilization 层级深度解析、性能窗口缺失容错和 markdown 列数一致性）。修改脚本必须先跑通该门禁。
