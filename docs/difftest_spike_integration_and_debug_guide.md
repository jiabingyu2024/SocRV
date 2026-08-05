# SocRV Spike DiffTest 接入与调试说明

## 1. 作用和边界

SocRV 的 DiffTest 在 CPU 产生架构提交事件时，让 Spike 执行同一条指令，然后比较 PC、指令、
通用寄存器写回、同步异常、访存和关键 Machine CSR。它用于回答“第一条与标准模型不同的指令
在哪里”，不是 HXI 总线协议检查器，也不是性能模型。

```text
CPU commit_trace_t ──> SocDutAdapter ──> DiffTestChecker ──> SpikeRefModel
       │
       └───────────────────────────────> HXI assertions/checker（独立）
```

取指预取、乱序执行、推测 load 和 HXI 请求时间均不与 Spike 比较。CPU 必须按架构顺序输出
提交事件；当前 RTL 只有一个提交槽，C++ checker 已使用事件数组，后续双发射可在同一周期按
`order` 提供两条事件。

参考模型固定为：

- lowRISC `riscv-isa-sim` 的 `ibex-cosim-v0.3`，commit
  `9af9730baf7b956c3072c1b436d867aca5ef8f4c`；
- Ibex co-sim 适配代码固定为 commit
  `e1f614887eef3ae089292d2ce8470c6eb80a1ae9`，该版本与 Spike v0.3
  的公开接口匹配；
- SocRV 从地址零复位，因此构建时会应用受指纹管理的
  `socrv_debug_window.patch`，把旧版 Spike 硬编码的零地址调试窗口移出
  SoC Memory Map；
- Spike 只在 WSL/Verilator 中链接，不进入 FPGA filelist，不会被综合。

## 2. 第一次构建

在 `SocRV/` 根目录执行：

```text
make deps
make difftest-build

# 验证 checker 确实能识别故意注入的四类差异
make difftest-selftest
```

`make deps` 按 lock 文件取得 Spike 和 Ibex co-sim 的固定源码。`make difftest-build`：

1. 在 WSL 临时 Linux 文件系统中恢复 Git 符号链接；
2. 使用 `--enable-commitlog --enable-misaligned` 构建 Spike；
3. 安装到 `build/reference/spike/install`；
4. 把最小 Ibex co-sim 适配层生成到 `build/reference/spike/ibex_cosim`；
5. 构建独立的 `build/verilator/soc-diff/obj_dir/soc_sim`。

不会执行 `sudo make install`，也不会写 `/usr/local`。首次 Spike 构建较慢，后续由输入指纹复用。
`difftest-selftest` 是验证专用入口，会分别注入 order、下一 PC、GPR 写回和
memory mask 错误，并要求结果严格分类为 `ORDER/NEXT_PC/GPR/MEM`。故障注入
参数不出现在正常 Make 流程中。

## 3. 常用命令

```text
# 当前 ISA 快速门
make diff-isa ISA_GATE=current

# 单个裸机 SoC smoke（包含 UART/TestStatus，使用 soc-mmio）
make diff-smoke

# RT-Thread、Timer、UART、MMIO
make diff-rtthread

# 原命令临时打开差分
make sim-smoke DIFFTEST=1
make sim-isa ISA_GATE=current DIFFTEST=1
make sim-rtthread DIFFTEST=1
```

CoreMark 性能仿真默认不启用 DiffTest：

```text
make sim-coremark COREMARK_ITERATIONS=3
```

若只想用少量轮次做正确性 soak，可显式执行：

```text
make sim-coremark COREMARK_ITERATIONS=1 DIFFTEST=1
```

`make diff-rtthread` 会等待首次 `msh >` 后注入 `socrv_info`，检查命令
输出，并且只有再次看到 `msh >` 才算命令完成。测试程序即使已经写入
TestStatus PASS，仿真也会继续到第二个提示符，避免“只发送、未执行”的
假通过。

`make diff-isa` 默认把参考模型固定为
`rv32im_zicsr_zicntr_zifencei`，而不是随单个测试 ELF 的最小 `-march`
变化；可通过 `DIFFTEST_ISA=...` 显式覆盖。这样 `misa` 等架构状态始终
对应待验证 CPU 的真实能力。

10000 轮 FPGA 性能运行不应启用 Spike。DiffTest 会显著降低仿真速度，并且 DUT 的 MMIO 时间
仍是环境输入，不能用于产生 FPGA 性能结论。

## 4. 比较模式

`ram-strict` 用于 riscv-tests：

- CODE/DATA 从同一个 `image.json` 和 `.mem` 文件加载；
- load/store 地址、mask 和数据严格比较；
- PC、下一 PC、指令、GPR、同步异常和 Machine CSR 严格比较。

Spike 按计划保留 `--enable-misaligned`。如果 DUT 选择对非对齐 half/word
访问产生 4/6 号异常，checker 会独立解码指令并重新计算有效地址，验证对齐、
`cause` 和 `tval` 后才把标准 trap 转移同步到 Spike；不会无条件相信或跳过
DUT 异常。因此，后续 CPU 既可选择硬件完成非对齐访问，也可选择精确异常。

`soc-mmio` 用于 RT-Thread：

- CODE/DATA 仍严格比较；
- TIMER、IRQ_CTRL、UART、GPIO、TEST_STATUS 必须来自当前 Memory Map；
- MMIO store 比较地址、mask 和数据；
- MMIO load 使用 DUT 实际返回值同步 Spike 的影子设备；
- 异步中断事件按 `irq_next_order` 在下一条提交指令前送入 Spike。

不能通过扩大地址范围跳过未知 MMIO。新增外设后，应先在
`data/soc/memory_map.json` 建立非重叠叶子 region，再更新 runner 的允许列表。

## 5. CPU 替换时必须提供的提交语义

`commit_trace_t` 的 CSR 快照表示指令执行前的架构状态。普通指令：

```text
valid=1 retired=1 sync_trap=0
```

同步异常指令：

```text
valid=1 retired=0 sync_trap=1
pc_rdata = faulting PC
pc_wdata = trap target
cause/tval = 本次异常
```

异步中断发生在两条指令之间，使用：

```text
irq_valid=1
irq_next_order = 第一条中断处理程序指令的 order
irq_mip_pre/post = Spike 判定中断和处理程序看到的 MIP
```

其他要求：

- `order` 对所有普通和同步异常事件单调递增，复位后从 0 开始；
- `retired=0` 的同步异常不增加 `minstret` 或 IPC；
- `rd_wdata` 是最终架构写回值，`rs*_rdata` 是经过 forwarding/rename 后真正消费的值；
- memory 字段描述该指令的架构访存，不是任意推测 HXI transaction；
- store 在成为不可撤销的架构操作时报告；
- 乱序双发射核必须按 `order` 顺序退休；同周期多个事件由 adapter 组成数组。

## 6. 结果和定位

每个差分运行额外生成：

```text
build/result/soc/<test>-diff.json
build/log/difftest/<test>-diff.log
build/trace/difftest/<test>-diff.jsonl
build/trace/difftest/<test>-diff.spike.log   # 仅 TRACE=1
```

`result.json` 的 `difftest` 对象记录 Spike commit、模式、ISA、比较事件数、退休数、MMIO 同步数、
最后 order 和产物路径。首个差异的状态为 `DIFF_MISMATCH`，`failure.kind` 为：

- `ORDER`：提交丢失、重复或顺序错误；
- `PC`/`NEXT_PC`：当前 PC 或分支、跳转、trap 目标错误；
- `INSN`：DUT 提交的指令与参考内存不同；
- `GPR`：写回寄存器或数据不同；
- `CSR`：Machine CSR 的执行前状态不同；
- `TRAP`：同步异常类型或是否发生异常不同；
- `MEM`：load/store 地址、mask、值或总线错误不同；
- `IRQ`：中断排序或 MIP 同步错误；
- `REFERENCE_ERROR`：Spike 后端本身无法继续。

失败后重放：

```text
make diff-replay RESULT=build/result/soc/<test>-diff.json TRACE=1
```

先查看 `failure.kind/message`，再查看 JSONL 中失败前 64 条提交和 32 条访存。只有退休级信息不足
以确定流水级根因时，才打开 VCD，把失败 `order` 反向追到 ROB/写回/执行/译码。

## 7. 当前阶段验收

建议按以下顺序推进自研 CPU：

```text
make diff-smoke
make difftest-selftest
make diff-isa ISA_GATE=current
make diff-isa ISA_GATE=final-base
make diff-rtthread
make sim-coremark COREMARK_ITERATIONS=3
```

本次验收结果：

- RV32UI：41/41 严格差分通过；
- RV32UM：8/8 严格差分通过；
- RV32MI：16/16 严格差分通过；
- smoke、trap/timer、RT-Thread 启动、`socrv_info` 命令和第二次 shell
  提示符均严格差分通过；
- RT-Thread 中输入 `coremark 3` 的非差分性能流程通过，CRC 正确并返回 shell。

固定的旧版 Ibex Spike co-sim 不会把地址 trigger 命中暴露为可比较的同步
trap。适配层因此独立维护两个 trigger 槽，只在 type/mode/operation/address
确实命中时要求 DUT 报告 cause=3，并检查 `tval` 与 trap target 后同步参考状态。
漏报、误报和地址错误都会失败；`rv32mi/breakpoint` 已纳入 16/16 的严格验收。

当前 demo core 仍只是功能框架参考，其中 RV32M 的乘除为组合实现，不能作为
最终 FPGA 频率设计。F/FD 尚未确定，因此当前提交协议没有 FPR/`fcsr` 比较；
选择浮点方案后再扩展版本化事件。本次接入和验收没有调用 Vivado。
