# Core 100 MHz 至 10 秒目标优化计划

日期：2026-08-10  
适用工程：SocRV  
状态：规划稿，尚未开始本计划中的 RTL 优化

## 1. 目标与边界

本计划从 core 100 MHz 稳定版本起步。每轮读取 Vivado 时序报告，分类关键路径，修改 CPU 或 TCM，并用精简的 RV32IMF-Zicsr 回归和 RT-Thread + CoreMark 验证。最终目标是固定工作量的 CoreMark 在 FPGA 上运行不超过 10 秒。

允许修改 EH1 CPU、ICCM、DCCM、CPU/TCM 接口以及必要的综合和物理约束。外设时钟固定为 50 MHz，UART、GPIO、machine timer、SYSCTRL 均在 50 MHz 域运行；CDC、复位和外设时钟契约不能因 core 提频而简化。性能比较期间固定软件、编译选项、CoreMark 迭代次数和 RT-Thread 配置，架构验证范围固定为 RV32IMF-Zicsr。

10 秒作为硬目标，不预先判断能否实现。每轮接受或拒绝修改，以时序、IPC 和实际 CoreMark 时间为依据。

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
2. 运行 Verilator build-only、lint、filelist/schema/generated-tree。
3. 运行精简 RV32IMF-Zicsr 回归。
4. 运行 RT-Thread + CoreMark command-1。
5. 运行 Vivado synthesis 或 opt/coarse place。
6. 重新生成关键路径 cluster。
7. 比较频率、IPC、周期、资源和预计时间。
8. 标记 ACCEPT、REJECT 或 SPLIT。

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

100～200 MHz 的多数迭代只运行到 synthesis、`opt_design` 或 coarse `place_design`。生成 timing summary、setup/hold paths、clock interaction、hierarchical utilization、high-fanout、logic-level/congestion 和 QoR suggestions。前期关注逻辑结构和路径 cluster，不追逐单条物理 net delay。

完整实现只在 100 MHz 基线、第一个稳定的 150 MHz 候选、第一个稳定的 200 MHz 候选，或 post-place 与已有 post-route 相关性明显失效时执行。

### 10.2 后期

接近 10 秒或准备交付后，对候选执行完整 opt/place/phys-opt/route，读取 timing、DRC、methodology、CDC、utilization、congestion、clock utilization 和 high-fanout reports。

详细检查所有 clock pair 的 setup/hold、top 100 setup/hold、logic/net delay、clock skew、拥塞、TCM BRAM 与 IFU/LSU 距离、DSP 与 M/F pipeline 距离、跨 clock region 路径、unconstrained paths、pulse width 和 recovery/removal。

后期可尝试 Pblock、寄存器复制、模块物理聚合、incremental implementation、不同 place/route directives 和少量 seed。物理手段只用于最终收敛，不能代替 RTL 结构修正。

## 11. 迭代记录

每轮保存 Markdown 和机器可读 JSON：

```text
Iteration:
Target frequency:
Primary hypothesis:
Modified modules:
Critical path clusters before:
Critical path clusters after:
Post-synth WNS:
Post-place WNS:
Post-route WNS:
CoreMark cycles:
Retired instructions:
IPC:
Peripheral ticks:
Projected/actual time:
Resource delta:
ISA result:
RT-Thread/CoreMark result:
Decision: ACCEPT / REJECT / SPLIT
Next bottleneck:
```

汇总 frequency、IPC、CoreMark time、WNS、资源和关键路径 cluster 随迭代的变化。

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
