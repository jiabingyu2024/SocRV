# Core 100 MHz 至 10 秒目标优化计划

日期：2026-08-10  
适用工程：SocRV  
状态：执行稿；已配套精简仿真门禁、Vivado 分阶段构建、全违例导出、时序聚类和一键迭代脚本

## 1. 目标与边界

本计划从 core 100 MHz 稳定版本起步。每轮读取 Vivado 时序报告，分类关键路径，修改 CPU 或 TCM，并用精简的 RV32IMF-Zicsr 回归和 RT-Thread + CoreMark 验证。最终目标是固定工作量的 CoreMark 在 FPGA 上运行不超过 10 秒。

允许修改 EH1 CPU、ICCM、DCCM、CPU/TCM 接口以及必要的综合和物理约束。外设时钟固定为 50 MHz，UART、GPIO、machine timer、SYSCTRL 均在 50 MHz 域运行；CDC、复位和外设时钟契约不能因 core 提频而简化。性能比较期间固定软件、编译选项、CoreMark 迭代次数和 RT-Thread 配置，架构验证范围固定为 RV32IMF-Zicsr。

10 秒作为硬目标，不预先判断能否实现。每轮接受或拒绝修改，以时序、IPC 和实际 CoreMark 时间为依据。

### 1.1 面向大模型的读取边界

本计划把仿真和 Vivado 工程侧当作**固定基础设施**。正常 RTL 优化轮次中，大模型不应反复阅读 `tb/`、`sim/`、Vivado 工程生成目录或整份 `.rpt`；优先读取以下小文件：

0. **每轮第一条命令固定为 `make iter-status`**（见 10.7）。它把仿真门禁、ISA 门禁、CoreMark 性能窗口和 Vivado 时序/资源摘要合成一页，替代逐个打开 result JSON 和报告。只有这一页指向某个具体瓶颈时，才继续往下读。
1. RTL 变更文件及其直接上下游接口。
2. 仿真机器结果：`build/result/soc/<test>.json`、`build/regression/<suite>/summary.json`、`build/regression/isa/<gate>/summary.json`。
3. Vivado 聚类结果：`build/vivado/<run>/analysis/timing_summary.md` 和 `timing_summary.json`。
4. 需要某条代表路径的门级细节时，用 `scripts/show_timing_path.py` 按 index/endpoint/category 单独抽取该路径（见 10.7），**不要**按 source/destination 去原始 `.rpt` 里翻块，也不要整份读入。
5. 仅当仿真失败且 JSON 中的 `reproduce`、`failure`、`checker` 仍不足以定位时，才读取对应 `build/log/soc/<test>.log`；波形只用于最小失败用例。

一条硬规则：**任何单个文件超过约 500 行就不整份读**。10.4 给出了每个大报告的体积和对应的替代命令。

## 2. 固定评价口径

### 2.1 每轮记录

| 指标 | 来源 | 用途 |
|---|---|---|
| Core frequency | Vivado 参数 | 目标频率 |
| WNS/TNS | timing report | setup 时序 |
| WHS/THS | timing report | hold 时序 |
| Core cycles | `mcycle` 差值 | 执行周期 |
| Retired instructions | `minstret` 差值 | 有效指令数 |
| IPC | `minstret / mcycle` | 流水线效率 |
| Peripheral ticks | 50 MHz machine timer | 实际时间 |
| CoreMark wall time | ticks / 50 MHz | 最终性能 |
| CoreMark CRC | 固定参考值 | 功能正确性 |
| LUT/FF/BRAM/DSP | utilization report | 资源变化 |

最终 10 秒结果必须使用固定 CoreMark 工作量和 50 MHz machine timer 测量，不使用 UART 打印时间、仿真器运行时间或主机脚本时间。总时间按 `CoreMark cycles / core frequency` 比较。

### 2.2 IPC 边界

- 单轮 IPC 下降原则上不超过 3%。
- 到达 200 MHz 时累计 IPC 下降原则上不超过 8%。
- IPC 下降超过 3% 的修改，只有预计总时间至少改善 5% 时才保留。
- 200 MHz 以后，提高频率但使 CoreMark 总时间变差的修改直接拒绝。

## 3. 100 MHz 基线

优化前冻结 100 MHz 基线，记录：

- post-route WNS、TNS、WHS、THS。
- top 100 setup paths、top 50 hold paths、clock interaction、unconstrained paths 和 CDC。
- CoreMark `mcycle`、`minstret`、IPC、timer ticks、CRC。
- RT-Thread 启动周期、CoreMark 完成周期和 FPGA 实测时间。
- LUT、FF、BRAM、DSP 使用量。

基线结果至少包含：

```text
baseline_frequency
baseline_coremark_cycles
baseline_instructions
baseline_ipc
baseline_ticks
baseline_wall_time
baseline_wns
baseline_resources
```

后续每轮同时与 100 MHz 基线和上一轮稳定版本比较。

## 4. 关键路径分析

### 4.1 采集与聚类

不能只处理 timing report 中的第一条路径。每次至少读取 top 100 setup paths，并记录 startpoint、endpoint、launch/capture clock、slack、requirement、logic/net delay、logic levels、单元类型、hierarchy、高扇出信号和跨层级组合链。top hold paths、clock interaction、unconstrained paths 和 CDC 单独检查。

top paths 按时钟对、起止 hierarchy、逻辑功能和路径签名聚类。每个 cluster 记录路径数量、worst slack、逻辑/布线占比和主要单元；优化后重新生成 cluster，确认路径确实缩短，而不是迁移到相邻寄存器。

### 4.2 分类

#### IFU 与取指

检查 PC mux、branch/jump redirect、ICCM 地址和 bank 选择、ICCM 输出、fetch valid/stall/flush，判断 redirect、ICCM 访问和 decode 是否串在同一周期。

#### Decode 与控制

检查指令译码、CSR、异常、hazard、stall/flush、operand select 和高扇出控制。大型 mux、跨流水级组合信号和全核 stall/flush 是优先目标。

#### EXU 与整数路径

检查 ALU、compare/branch、multiplier、bypass、forwarding、result select 和 writeback mux。普通整数快速路径不应被 FPU、M、CSR、LSU 的复杂结果选择拖慢。

#### LSU 与 DCCM

检查地址生成、对齐、byte enable、bank decode、DCCM read、store-to-load forwarding、load data mux 和 load bypass。地址计算、检查、bank decode、BRAM read 和 forwarding 不应全部堆在一个周期。

#### FPU

检查 classify、format conversion、FMA、divide/sqrt、rounding、exception flags 和 result mux。可以增加 FPU latency，但必须保持 RV32F、precise exception、flush、stall 和 writeback 顺序正确；FPU 长路径不能拖慢普通整数指令。

#### ICCM/DCCM 结构

确认 BRAM inference、bank 划分、地址译码、输出 mux、ECC/parity 和 wrapper 层级，减少多 bank 大 mux 和跨层级长连线。

#### 高扇出控制

检查 reset、stall、flush、clock enable、pipeline valid、debug halt 和 exception valid。可采用寄存器复制、局部 enable 和分级控制。

#### CDC

MMIO request/response、timer/software IRQ、test status/code、UART RX 和 GPIO input 单独审查。不得为了频率删除 synchronizer、toggle handshake 或 payload 稳定窗口。

## 5. 频率迭代路线

建议检查点：

```text
100 → 125 → 150 → 175 → 200 MHz
200 MHz 后：200 → 210/225 → 240/250 → 更高
```

正 slack 较大时可以跳档；负 slack 集中时缩小步长。

### 5.1 100～150 MHz

优先采用低风险、低 IPC 损失的方法：清理大组合 mux，分级 FPU/M/CSR/LSU result mux，复制高扇出 stall/flush/enable，简化地址 decode 和 bank select，确认 ICCM/DCCM 推断 BRAM，缩短跨 hierarchy 组合链，分离普通整数快速路径与异常/FPU 路径。此阶段原则上不接受明显 IPC 下降。

### 5.2 150～200 MHz

处理 IFU/ICCM 输出寄存切分、DCCM bank decode 前移、load data mux 分级、branch compare/redirect 切分、decode/hazard 预译码、LSU 地址生成与 DCCM access 分离、FPU result/exception 独立流水、multiplier pipeline、writeback mux、TCM registered output 和 forwarding 网络局部化。

增加流水级时必须同步检查 valid、stall、flush、kill、forwarding、load-use hazard、exception、interrupt、FPU completion 和 writeback arbitration。每次只进行一种流水级变更。

### 5.3 200 MHz 决策点

关键路径仍集中、一次结构修改预计还能提升至少约 5%、IPC 未明显下降且 post-synth/post-place/post-route 趋势一致时，继续提频。连续两轮频率提升低于约 3%～5%、关键路径在不相关模块间迁移、频率收益需要额外流水级、周期增长抵消频率收益，或 net delay 已成为主导时，转向 IPC 优化。

## 6. 200 MHz 后的 IPC 优化

先统计 `mcycle`、`minstret`、branch redirect/mispredict、load-use/ICCM/DCCM stall、multiplier/FPU stall、writeback conflict、pipeline flush 和 interrupt/RTOS 开销。优先使用 EH1 performance counters 或标准 CSR，确实缺少信息时才增加轻量计数器。

优化顺序：

1. 减少 DCCM wait、bank conflict 和 load-use penalty。
2. 提前 bank select，尽早 forwarding load result。
3. 缩短 branch redirect，减少不必要的前端 flush。
4. 消除保守 hazard 和 valid/stall 传播造成的气泡。
5. 避免 FPU/M busy 阻塞无关整数指令。
6. 优化 writeback arbitration。
7. 根据 CoreMark 热点 PC 判断 list、matrix、state machine、CRC 中的真实瓶颈。

不为某个固定 PC 或某段 CoreMark 地址编写硬件特例。

## 7. 单轮优化流程

每轮只允许一个主要假设，或一组紧密相关的修改。例如：

```text
假设：DCCM bank-select 与 read-data mux 位于同一周期，构成 38% 的 top-100 negative paths。
修改：把 bank decode 前移一拍，保持 load response 接口不变。
预测：关键路径降低 0.5～0.8 ns；load hit CPI 不变；资源增加少于 1%。
```

没有路径报告依据，不开始修改。固定执行顺序：

1. 修改 RTL。
2. 运行 Level 0 静态门禁和 Verilator build-only。
3. 复用同一个 Verilator model，运行 smoke、精简 RV32IMF-Zicsr gate 和一次 RT-Thread + CoreMark。
4. 仅读取仿真 JSON；通过后才进入 Vivado。
5. 运行带唯一 `--run-tag` 的 Vivado synth/impl，自动生成 top paths 或全违例报告。
6. 自动生成 `analysis/timing_summary.{md,json}` 和 setup/hold CSV，比较目标 cluster、WNS/TNS、hold、CDC 和资源。
7. 比较 CoreMark performance window 的 cycles、commits、IPC；不要用包含 RT-Thread 启动和 UART 等待的全程 IPC 代替 CoreMark IPC。
8. 标记 ACCEPT、REJECT 或 SPLIT，并把下一主要瓶颈写入 `docs/iterations/<tag>.md/.json`。

推荐的一键入口：

```powershell
python -B scripts/run_optimization_iteration.py `
  --tag fma-decode-r2 `
  --core-mhz 125 `
  --jobs 8 `
  --isa-gate current `
  --coremark-iterations 1 `
  --vivado-stage synth `
  --vivado-all-violations
```

该命令 fail-fast 执行“静态门禁 → smoke → ISA → CoreMark → Vivado → 聚类”，每一步日志写到 `build/iterations/<tag>/logs/`，最终小结写到 `docs/iterations/<tag>.md/.json`。首次使用或软件发生合法变化时加 `--build-software`；纯 RTL 迭代默认复用冻结的软件镜像。先用 `--dry-run` 可只打印全部命令和预期路径。

接受条件：功能通过，目标 cluster 明确改善，预计 Fmax 上升，IPC 在边界内，CoreMark 总时间预计改善，并且没有引入 CDC、reset、异常或顺序风险。

## 8. 精简回归

### Level 0：编译门禁

每次 RTL 修改运行 Verilator build-only、lint、filelist、generated-tree 和 memory-map/schema。编译门禁失败时，不进入 ISA、RT-Thread 或 Vivado。

### Level 1：RV32IMF-Zicsr

覆盖 RV32I arithmetic/shift/compare/branch/load-store，M 的 multiply/divide/remainder，F 的算术、转换、compare、rounding、fflags/fcsr，Zicsr 的读写、非法访问和 trap/return，以及 timer/software interrupt、exception/flush、forwarding/hazard。

采用 fail-fast、固定 timeout；默认不生成波形、不打开完整 commit trace，不运行目标 ISA 之外的扩展测试。

### Level 2：RT-Thread + CoreMark

```text
RT-Thread 启动
→ CoreMark command-1
→ 检查 CRC
→ 读取 cycles/instructions/ticks
→ 检查 test status
```

每轮不运行多条重复 CoreMark command、长时间 UART 文本比对和多个相近 RT-Thread profile。

### Level 3：里程碑回归

到达 150、175、200 MHz，增减流水级，修改 hazard/forwarding/flush、TCM latency、exception/interrupt 顺序，或准备 bitstream 时，运行完整 RV32IMF-Zicsr 精简集合、trap timer、store-load-forward、必要的 FPU corner cases，以及两次 RT-Thread + CoreMark。

### 8.1 仿真侧固定命令、参数和结果路径

以下命令从仓库根目录运行。纯 RTL 迭代禁止修改命令语义；需要更长 timeout 或 trace 时，只对失败的最小用例使用。

| 目的 | 固定命令 | 关键参数 | 首读结果 | 失败时再读 |
|---|---|---|---|---|
| Verilator 编译门禁 | `python -B scripts/run_verilator.py --profile smoke --build-only` | `--force-rtl-build` 仅用于排除缓存疑问；默认无 trace | `build/verilator/soc/build_manifest.json` | 构建命令终端输出 |
| smoke | `python -B scripts/run_verilator.py --profile smoke --no-rtl-build --no-software-build` | 复用刚构建 model 和冻结镜像 | `build/result/soc/baremetal-smoke.json` | `build/log/soc/baremetal-smoke.log` |
| 当前 ISA gate | `python -B scripts/run_isa_tests.py --gate current --no-rtl-build` | `--max-cycles 300000` 为默认；默认不加 `--trace` | `build/regression/isa/current/summary.json` | 首个失败的 `build/result/soc/isa-*.json` 与对应 `.log` |
| 里程碑 ISA gate | `python -B scripts/run_isa_tests.py --gate final-base --no-rtl-build` | 150/175/200 MHz、流水级/异常顺序变更时使用 | `build/regression/isa/final-base/summary.json` | 同上 |
| RT-Thread 启动 | `python -B scripts/run_verilator.py --profile rtthread --no-rtl-build --no-software-build` | 默认 checker 校验启动文本、prompt 和 test status | `build/result/soc/rtthread-smoke.json` | `build/log/soc/rtthread-smoke.log` |
| 每轮 CoreMark | `python -B scripts/run_verilator.py --profile rtthread-coremark --test opt-<tag>-coremark-1 --benchmark-iterations 1 --uart-command "coremark 1" --no-rtl-build --no-software-build` | 不追加 `ps/help`；默认 checker 已检查 CRC、prompt、test status 和 performance window | `build/result/soc/opt-<tag>-coremark-1.json` | 同名 `.log` |
| 失败局部波形 | 在 JSON 的 `reproduce` 命令后加 `--trace` | 只用于单个失败测试，不给整套回归开波形 | `build/wave/soc/<test>.vcd` | 对应 `.log` 和 `failure` 字段 |

批量回归的机器汇总固定在以下位置，比逐个读单测 JSON 更省上下文：

```text
build/regression/correctness/summary.json   # smoke + trap-timer + rtthread + CoreMark，含性能窗口
build/regression/coremark/summary.json      # CoreMark 功能性（仅 cycles，无性能窗口）
build/regression/performance/summary.json   # 多迭代性能趋势
build/regression/isa/<gate>/summary.json    # gate ∈ current / final / final-base / fp-single / fp-double / rv32ui
```

汇总 JSON 的读取顺序固定为：`status` → `tests[].status` → 失败项的 `checker`/`failure` → `performance` → `reproduce`。

关于性能窗口有三条容易踩的规则：

- 性能数据在 **`performance` 子对象**里，字段为 `cycles`、`commits`、`ipc`、`iterations`、`cycles_per_iteration`、`complete`。顶层 `cycles/commits/ipc` 覆盖从复位到退出的完整仿真（含 RT-Thread 启动和 UART 等待），**不能**用来判断性能。同一条 CoreMark 测试的两个数会差一倍以上，例如顶层 `cycles=11508527` 而窗口 `performance.cycles=7136021`。
- `performance` 可以合法缺失：`build/verilator/soc/run/<test>/result.json` 和 `build/regression/coremark/summary.json` 里都没有该子对象。读取方必须容忍 `None`，不要因为缺字段就判定回归失败。
- 只接受 `performance.complete == true` 的窗口；`complete=false` 表示 CoreMark 没跑完，此时的 IPC 无意义。

`make iter-status` 已按以上规则挑选"最新且 complete"的窗口并换算成各频率下的墙钟时间，正常轮次无需手工读这些 JSON。

静态门禁的直接命令为：

```powershell
python -B scripts/check_filelists.py
python -B scripts/check_generated_tree.py
python -B scripts/check_memory_map.py
python -B scripts/validate_schemas.py
python -B scripts/lint_rtl.py
python -B scripts/run_verilator.py --profile smoke --build-only
```

这些脚本的输入、filelist 和 testbench 实现已固定。除非门禁脚本自身报错且需要修基础设施，否则 RTL 优化模型不读取其源码。

## 9. Bug 定位边界

### ISA 失败

获取第一条失败指令、PC 和 expected/actual register，缩成最小 ELF/汇编，只打开失败前后 100～500 条 commit trace，检查 valid、stall、flush、operand、forwarding、result 和 writeback。trace 仍无法定位时才开局部波形；基础 ISA bug 不用 RT-Thread 定位。

### ISA 通过、RT-Thread 启动失败

按 reset release、TCM image、first trap、`mtvec/mepc/mcause`、timer、stack/global pointer、第一次 scheduler switch 和 UART 配置定位，用启动 marker 缩小范围，不抓全程波形。

### RT-Thread 启动、CoreMark 失败

检查 CRC、数据区、heap/stack、multiply/divide、load/store forwarding、timer/interrupt，以及未对齐或 alias 行为。

### Timeout 或偶发错误

先判断死锁、请求未返回、pipeline valid 丢失、flush 后错误提交、MMIO CDC、timer interrupt 风暴或 UART 阻塞。只保留 timeout 前最后 2k～10k commit events。无法快速定位时回退并拆小，不在未知 bug 上继续叠加优化。

## 10. Vivado 分阶段策略

### 10.1 前期

100～200 MHz 的多数迭代只运行 synthesis；需要观察布线相关性时运行完整 implementation 但不生成 bitstream。生成 timing summary、setup/hold paths、clock interaction、hierarchical utilization、CDC 和可选全违例报告。前期关注逻辑结构和路径 cluster，不追逐单条物理 net delay。

完整 implementation 只在 100 MHz 基线、第一个稳定的 150 MHz 候选、第一个稳定的 200 MHz 候选，或 post-synth 与已有 post-route 相关性明显失效时执行。

### 10.2 后期

接近 10 秒或准备交付后，对候选执行完整 implementation/bitstream，读取 timing、DRC、methodology、CDC、utilization、clock utilization 和 high-fanout/拥塞线索。

详细检查所有 clock pair 的 setup/hold、top 100 setup/hold、logic/net delay、clock skew、拥塞、TCM BRAM 与 IFU/LSU 距离、DSP 与 M/F pipeline 距离、跨 clock region 路径、unconstrained paths、pulse width 和 recovery/removal。

后期可尝试 Pblock、寄存器复制、模块物理聚合、incremental implementation、不同 place/route directives 和少量 seed。物理手段只用于最终收敛，不能代替 RTL 结构修正。

### 10.3 分阶段构建命令

`run_vivado.py` 统一建立工程、设置 core 时钟、运行阶段、导出报告并调用聚类脚本。所有性能迭代都使用唯一 `--run-tag`，避免新旧报告混用。

| 场景 | 命令 | 输出根目录 |
|---|---|---|
| 快速综合、top 100/50 | `python -B scripts/run_vivado.py --profile rtthread-coremark --core-mhz 125 --jobs 8 --stage synth --run-tag <tag> --no-software-build` | `build/vivado/kintex7-rtthread-coremark-125mhz-<tag>/` |
| 综合并导出全部负 slack endpoint | 上式增加 `--all-violations` | 同上；额外生成 `post_synth_*_violations.rpt` |
| 完整实现但不生成 bitstream | 把 `--stage synth` 改为 `--stage impl` | 同上；报告前缀为 `post_impl_` |
| 最终 bitstream | 把 `--stage` 改为 `bitstream` | bitstream 位于 `project/socrv.runs/impl_1/fpga_top.bit` |
| 只检查既有 bitstream 签核 | `python -B scripts/run_vivado.py --profile rtthread-coremark --core-mhz <MHz> --check-only` | 对应 run 的 `result.json` |

`--core-mhz` 当前允许 `100/125/150/175/200/250`；`--jobs` 是 Vivado run 并行数；`--no-software-build` 复用 `build/images/rtthread-coremark/`；如果软件镜像不存在或软件/链接脚本确实变化，删除该参数。`150/175 MHz` 使用固定 1 GHz VCO 下最近的合法 1/8 分频值，最终以 timing report 中实际 clock requirement 为准。

### 10.4 原始报告固定路径

对于 `<run>=kintex7-rtthread-coremark-<MHz>mhz-<tag>`：

```text
build/vivado/<run>/project/socrv.xpr
build/vivado/<run>/project/reports/post_synth_timing_summary.rpt
build/vivado/<run>/project/reports/post_synth_setup_paths.rpt       # top 100
build/vivado/<run>/project/reports/post_synth_hold_paths.rpt        # top 50
build/vivado/<run>/project/reports/post_synth_setup_violations.rpt  # --all-violations
build/vivado/<run>/project/reports/post_synth_hold_violations.rpt   # --all-violations
build/vivado/<run>/project/reports/post_synth_utilization.rpt
build/vivado/<run>/project/reports/post_synth_clock_interaction.rpt
build/vivado/<run>/project/reports/post_synth_clock_utilization.rpt
build/vivado/<run>/project/reports/post_synth_cdc.rpt
```

`--all-violations` 的全量导出放在单独子目录：

```text
build/vivado/<run>/project/reports/all_violations/all_setup_violations.rpt
build/vivado/<run>/project/reports/all_violations/all_hold_violations.rpt
build/vivado/<run>/project/reports/all_violations/all_setup_timing_summary.rpt
build/vivado/<run>/project/reports/all_violations/all_hold_timing_summary.rpt
build/vivado/<run>/project/reports/all_violations/all_clock_interaction.rpt
build/vivado/<run>/project/reports/all_violations/all_cdc.rpt
```

`impl` 阶段使用同名 `post_impl_*` 文件，并额外有 `post_impl_drc.rpt`、`post_impl_methodology.rpt`。Vivado 运行日志主要位于 `<run>/vivado.log`、`project/socrv.runs/synth_1/runme.log` 和 `project/socrv.runs/impl_1/runme.log`；只有构建失败且聚类结果未生成时才读这些日志。

#### 禁止整份读取的报告与替代命令

以下体积取自 125 MHz 实测 run，量级随设计规模变化但相对关系稳定。**左列文件一律不整份读**，用右列命令取等价信息：

| 原始报告 | 实测体积 | 替代命令 | 替代输出体积 |
|---|---|---|---|
| `all_violations/all_setup_violations.rpt` | 30.8 MB / 274507 行 | `make fpga-path VIVADO_BUILD=<run> PATH_MODE=hotspots` 或 `show_timing_path.py --kind setup-violations --category <CAT>` | 单条路径约 45 行 |
| `post_synth_setup_paths.rpt` | 3.3 MB / 19954 行 | `make fpga-paths VIVADO_BUILD=<run>` → `analysis/setup_paths.csv` | 91 KB / 101 行 |
| `post_synth_utilization.rpt` | 2.0 MB / 8832 行 | `make fpga-util VIVADO_BUILD=<run>` | 约 30 行表格 |
| `all_violations/all_hold_violations.rpt` | 0.79 MB / 9626 行 | `show_timing_path.py --kind hold-violations` | 单条路径约 45 行 |
| `post_synth_hold_paths.rpt` | 0.27 MB / 3317 行 | `analysis/hold_paths.csv` | 23 KB / 51 行 |
| `post_synth_timing_summary.rpt` | 0.11 MB / 1409 行 | `analysis/timing_summary.md` 或 `make iter-status` | 4.1 KB / 62 行 |

`post_synth_cdc.rpt`（19 行）、`post_synth_clock_interaction.rpt`（26 行）和 `post_synth_clock_utilization.rpt`（199 行）本身够小，但其内容已经进入 `timing_summary.json` 的 `cdc` 和 `clock_interaction` 字段，正常轮次仍然不必单独打开。

### 10.5 聚类脚本和紧凑输出

每次 `run_vivado.py` 成功后默认自动运行：

```powershell
python -B scripts/analyze_vivado_reports.py `
  --build-root build/vivado/<run> `
  --stage synth
```

对已经存在、但只有普通报告的工程，可一键补导出全部违例并聚类：

```powershell
python -B scripts/analyze_vivado_reports.py `
  --build-root build/vivado/<run> `
  --stage synth `
  --export-all
```

与上一轮比较：

```powershell
python -B scripts/analyze_vivado_reports.py `
  --build-root build/vivado/<current-run> `
  --stage synth `
  --compare build/vivado/<previous-run>/analysis/timing_summary.json
```

紧凑输出固定为：

```text
build/vivado/<run>/analysis/timing_summary.md    # 人和大模型首读
build/vivado/<run>/analysis/timing_summary.json  # 自动比较/迭代记录
build/vivado/<run>/analysis/setup_paths.csv      # 每条路径一行，可按 cluster/slack 筛选
build/vivado/<run>/analysis/hold_paths.csv
build/vivado/<run>/analysis/raw/*.rpt            # 仅 --export-all 的补导出原文
```

聚类脚本提取 WNS/TNS/WHS/THS、失败 endpoint 数、LUT/FF/BRAM/DSP、clock interaction、CDC unsafe/unknown、source/destination、clock pair、requirement、logic/route delay、logic levels、主要 primitive 和高扇出线索，并按 IFU/ICCM、decode/ibuf、EXU DIV/MUL、LSU/DCCM、FPU FMA/cast/divsqrt、TLU/CSR 等功能和 hierarchy 聚类。大模型先比较 cluster 数量、worst slack、logic/route 比例和代表路径；不要直接把一个数 MB 到数十 MB 的 `.rpt` 整体放入上下文。

CSV 每行的字段顺序固定为：

```text
kind, status, slack_ns, category, cluster, source, destination,
source_scope, destination_scope, launch_clock, capture_clock, path_group,
requirement_ns, datapath_delay_ns, logic_delay_ns, route_delay_ns,
logic_percent, route_percent, logic_levels, clock_skew_ns,
clock_uncertainty_ns, max_fanout, max_fanout_net, cell_counts
```

`max_fanout` / `max_fanout_net` 以及 `timing_summary.json` 中 cluster 的 `high_fanout_nets` **只统计数据路径区间**。Vivado 的每个路径块含四条虚线分隔的三段（source clock path、datapath、destination clock path），时钟段里的 BUFG 时钟网扇出可达数万，一旦把整块拿去扫描，每条路径的 `max_fanout` 都会退化成同一个时钟网数字，从而失去定位价值。因此扫描范围限定在第 2 与第 3 条分隔线之间。`scripts/tests/test_analyze_vivado_reports.py` 用一条含 `fo=27332` 时钟网和 `fo=141` 数据网的路径固定了这个行为。

### 10.6 Makefile 快捷入口

构建与聚类：

```text
make fpga-synth CORE_MHZ=125 ITER_TAG=fma-r2 JOBS=8
make fpga-impl  CORE_MHZ=150 ITER_TAG=milestone150 JOBS=8
make fpga-analyze VIVADO_BUILD=build/vivado/<run> VIVADO_STAGE=synth
make fpga-analyze VIVADO_BUILD=build/vivado/<run> VIVADO_STAGE=synth ANALYZE_ALL=1
make rtl-iteration ITER_TAG=fma-r2 CORE_MHZ=125 JOBS=8 VIVADO_STAGE=synth
```

读取与下钻（全部只产生紧凑输出，不打开原始 `.rpt`）：

```text
make iter-status  VIVADO_BUILD=build/vivado/<run>
make iter-trend
make fpga-paths   VIVADO_BUILD=build/vivado/<run> PATH_GROUP=category PATH_LIMIT=15
make fpga-path    VIVADO_BUILD=build/vivado/<run> VIVADO_STAGE=synth PATH_INDEX=1 PATH_MODE=hotspots
make fpga-util    VIVADO_BUILD=build/vivado/<run> UTIL_DEPTH=3
make fpga-util    VIVADO_BUILD=build/vivado/<run> UTIL_FILTER=fpu UTIL_DIFF=build/vivado/<previous-run>
```

相关变量默认值：`VIVADO_BUILD=build/vivado/kintex7-$(PROFILE)-$(CORE_MHZ)mhz`、`VIVADO_STAGE=synth`、`PATH_GROUP=category`、`PATH_LIMIT=15`、`PATH_INDEX=1`、`PATH_MODE=chain`、`UTIL_STAGE=auto`、`UTIL_DEPTH=4`、`UTIL_METRIC=luts`、`UTIL_LIMIT=30`、`COREMARK_TARGET_ITERATIONS=2000`。`ITER_TAG` 传给 `run_vivado.py --run-tag`，不要和 `VIVADO_BUILD` 混用：前者建新 run，后者读已有 run。

其中 `fpga-synth/fpga-impl` 默认导出全部违例；直接调用 `run_vivado.py` 时可不加 `--all-violations`，只生成 top 100/50 以缩短早期探索时间。

### 10.7 分析工具箱

四个脚本只读已有报告，不重跑 Vivado，都是纯 Python 3 标准库、流式解析，秒级返回。它们共同的目的是：**让每轮的阅读量与设计规模无关**。

#### `iteration_status.py` — 每轮第一条命令

把仿真门禁、ISA 门禁、CoreMark 性能窗口、Vivado 时序与资源摘要合成一页，并给出 BLOCKED/CLEAR 结论。

| 参数 | 含义 |
|---|---|
| `--build-root <dir>` | 指定 Vivado run；省略时自动选 `analysis/timing_summary.json` 最新的 run |
| `--iterations N` | CoreMark 墙钟时间换算所用迭代数，默认 2000 |
| `--core-mhz A B C` | 换算频率列表，默认 `100 125 150 175 200` |
| `--clusters N` | 显示的 setup cluster 条数，默认 6 |
| `--trend` | 改为输出跨 run / 跨迭代趋势表，对应第 11 节 |

输出四段：仿真门禁表、ISA 门禁表、CoreMark 窗口与频率换算表、Vivado 时序摘要（含每个 clock pair 的 `achieved MHz = 1000 / (requirement - WNS)`、worst setup clusters、CDC）。频率换算表里 `iters in 10 s` 与工作量无关，可直接判断"当前 IPC 下该频率最多能跑多少次迭代"；`seconds` 列才依赖 `--iterations`。

#### `show_timing_path.py` — 单条路径门级细节

替代在 30 MB 报告里翻块。`--build-root` 与 `--report` 二选一。

| 参数 | 含义 |
|---|---|
| `--kind {setup,hold,setup-violations,hold-violations}` | 选报告族；`*-violations` 读 `all_violations/` |
| `--mode {chain,hotspots,fanout,full}` | `chain` 逐单元链（默认）、`hotspots` 按类型/层级归并延时、`fanout` 只列高扇出网、`full` 原始块 |
| `--index N` / `--count N` | 报告内 1-based 路径序号与最多打印条数 |
| `--source` / `--dest` / `--contains` | 起点/终点/任意位置子串过滤 |
| `--category CAT` | 按 cluster 类别过滤，如 `FPU_FMA`、`LSU_DCCM`、`DECODE_IBUF` |
| `--max-slack` / `--min-incr` / `--top` / `--fanout-threshold` | slack 上限、增量延时阈值（默认 0.05 ns）、hotspots 条数（默认 8）、扇出阈值（默认 100） |
| `--list` | 只列出候选路径的 slack 与端点，不展开 |

#### `query_timing_paths.py` — 在 CSV 上聚合与筛选

只读 `analysis/{setup,hold}_paths.csv`，不碰 `.rpt`。

| 参数 | 含义 |
|---|---|
| `--kind {setup,hold}` | 选 CSV |
| `--group {category,cluster,source_scope,destination_scope,launch_clock,capture_clock}` | 聚合维度，替代逐条阅读 |
| `--category` / `--cluster` / `--scope` | 类别（逗号分隔）、cluster 标签子串、层级子串 |
| `--max-slack` / `--violated` | slack 上限、只看 VIOLATED |
| `--fanout N` | 改为列出 `max_fanout >= N` 的网（已是数据路径口径） |
| `--diff <other build root>` | 与上一轮比较各 cluster 的 worst slack |
| `--limit N` | 默认 15 |

#### `summarize_utilization.py` — 资源归因

把 8832 行、2 MB 的层级 utilization 报告压成一张表，并支持跨 run 求差，用于 ACCEPT/REJECT 时判断面积代价落在哪个模块。

| 参数 | 含义 |
|---|---|
| `--build-root <dir>` | 必填 |
| `--stage {auto,synth,impl}` | `auto` 优先 impl |
| `--depth N` | 层级深度上限，默认 4；深度由报告中 Instance 单元格的前导空格决定 |
| `--filter SUBSTR` | 只保留 instance 或 module 含该子串的行，例如 `--filter fpu` |
| `--metric {luts,ffs,ramb,dsp}` | 排序列，默认 `luts` |
| `--limit N` | 默认 30 |
| `--diff <other build root>` | 输出 `LUTs old->new / dLUT / FFs old->new / dFF`，按 dLUT 绝对值排序 |

`--diff` 会把对比 run 的 stage 钉在基准 run 实际解析到的 stage 上，避免 `auto` 把 post_synth 和 post_impl 混比——两者面积差异与 RTL 改动无关，混比会得出完全错误的归因结论。

#### 与仿真侧的对应关系

Vivado 侧四个脚本对应 8.1 的仿真侧命令表：仿真侧靠 `build/regression/*/summary.json` 收敛阅读量，Vivado 侧靠 `analysis/*` 和上述脚本收敛阅读量，两边在 `make iter-status` 汇合成一页。脚本自身的行为由 `make test-scripts` 保护（当前 21 个用例），修改脚本必须先跑通该门禁。

## 11. 迭代记录

每轮保存 Markdown 和机器可读 JSON。使用 `run_optimization_iteration.py` 时自动写入：

```text
docs/iterations/<tag>.md
docs/iterations/<tag>.json
build/iterations/<tag>/logs/<step>.log
```

记录至少包含：

```text
Iteration/tag:
Git revision:
Target frequency:
Primary hypothesis:
Modified modules:
Critical path clusters before:
Critical path clusters after:
Post-synth WNS/TNS/WHS/THS:
Post-impl WNS/TNS/WHS/THS:
CoreMark cycles:
Retired instructions:
CoreMark IPC:
Peripheral ticks / actual board time:
Resource delta:
ISA result path/status:
RT-Thread/CoreMark result path/status:
Vivado compact summary path:
Decision: ACCEPT / REJECT / SPLIT
Next bottleneck:
```

汇总 frequency、CoreMark IPC、CoreMark time、WNS、资源和关键路径 cluster 随迭代的变化。跨轮趋势不用手工维护表格：

```text
make iter-trend
```

它按 `analysis/timing_summary.json` 的时间顺序列出每个 run 的 stage、requirement、WNS/TNS、`achieved MHz`、失败 endpoint 数和 LUT/FF，再列出 `docs/iterations/*.json` 中每轮的 tag、status、目标频率、stage、git revision 和步骤通过情况（`steps` 是长度 11 的列表：check_filelists、check_generated_tree、check_memory_map、validate_schemas、lint_rtl、verilator-build、sim-smoke、sim-isa、sim-coremark、vivado、vivado-analysis）。

脚本自动记录命令和日志位置，但 `Primary hypothesis`、`Decision` 和 `Next bottleneck` 仍由优化者在看完 compact summary 后填写，不能由”命令运行成功”代替工程判断。

## 12. 最终交付门槛

1. 固定 CoreMark 工作量在 FPGA 上连续运行三次，中位数不超过 10 秒。
2. 三次 CRC 一致。
3. RV32IMF-Zicsr 精简回归全部通过。
4. RT-Thread + CoreMark 仿真通过。
5. post-route setup/hold 全部满足。
6. DRC 无 Error/Critical Warning。
7. CDC 无新增不安全 crossing。
8. core 达到最终频率，peripheral 保持 50 MHz。
9. IPC 损失有记录，最终运行时间确实改善。
10. bitstream、软件镜像、Vivado 报告、Git revision 和 SHA-256 一致。

执行主线：

```text
100 MHz 基线
→ 时序路径聚类
→ 低风险逻辑优化
→ 125/150 MHz
→ TCM/LSU/IFU 结构优化
→ 175/200 MHz
→ 判断继续提频或转向 IPC
→ 接近 10 秒
→ 完整 place/route 和物理收敛
→ FPGA 三次实测
→ 最终交付
```


## 13. 每轮给大模型的最小上下文包

开始下一轮 RTL 优化时，先跑一条命令，再按需读四类文件：

```text
make iter-status VIVADO_BUILD=build/vivado/<previous-run>
```

```text
1. 上面这条命令的输出（替代原来的 result JSON + ISA summary + timing summary 三处翻阅）
2. 本文档第 7、8、10、11 节
3. docs/iterations/<previous-tag>.md/.json
4. 本轮拟修改 RTL 文件及其直接接口
```

只有当 `iter-status` 指向某个具体瓶颈时，才继续下钻，且下钻同样用命令而不是读文件：

```text
瓶颈是某个 cluster    → make fpga-paths VIVADO_BUILD=<run> PATH_GROUP=cluster
瓶颈是某条代表路径    → make fpga-path  VIVADO_BUILD=<run> PATH_INDEX=<n> PATH_MODE=hotspots
怀疑高扇出           → python -B scripts/query_timing_paths.py --build-root <run> --fanout 500
面积/资源需要归因    → make fpga-util VIVADO_BUILD=<run> UTIL_DIFF=<previous-run>
仿真失败             → 失败项 JSON 的 reproduce/failure/checker，最后才是 .log 和波形
```

禁止默认读取：整个 `tb/`、整个 `sim/`、`project/socrv.runs/`、完整 utilization hierarchy、完整 timing `.rpt`、完整 UART log、完整波形。只有 compact JSON/Markdown 指向某个失败或代表路径时，才按需打开对应原始片段。这样每轮上下文集中在”RTL 假设、功能结果、关键路径 cluster 和性能差值”四件事上。
