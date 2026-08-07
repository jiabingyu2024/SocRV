# SocRV CPU 迭代、仿真、软件与 FPGA 操作说明

## 1. 目标与统一运行方式

项目最终使用同一个 `rtthread-coremark` 固件完成两件事：

- Verilator 中启动 RT-Thread，通过真实 UART RX 时序注入 `coremark 3` 或其他少量轮次；
- FPGA 上启动 RT-Thread 和 FinSH/MSH，由串口终端输入 `coremark 10000`。

两条路径使用相同的 CPU/SoC RTL、Memory Map、BSP、RT-Thread、CoreMark
源码和 `code.mem`/`data.mem` 镜像。仿真只缩短运行轮次，不另做一个自动执行
CoreMark 的固件。

```text
RT-Thread + FinSH + CoreMark ELF
              |
              v
       code.mem / data.mem
          |             |
          v             v
   soc_sim_top      fpga_top
   UART 自动注入     串口手工输入
   coremark 3       coremark 10000
```

仓库根目录是 `SocRV/`。以下命令均在该目录执行。

## 2. 第一次使用

先检查环境并取得固定版本的上游依赖：

```text
make doctor
make deps
make deps-check
make check
```

`make deps` 管理 RT-Thread、CoreMark 和 riscv-tests。项目适配代码位于各自的
`port/`、`env/`、`bsp/` 或 `applications/`，不修改第三方 `upstream/`。

常用工具分工：

- RISC-V GCC 与 Verilator 在 WSL 中运行；
- Vivado 只由 `fpga-build` 和 `fpga-program` 显式调用；
- `make check` 不进行综合或生成 bitstream。

## 3. 修改 CPU 后如何仿真

### 3.1 日常推荐顺序

修改 CPU core 后，不必立即上板。按由快到慢的顺序执行：

```text
make sim-smoke
make sim-isa ISA_GATE=current
make sim-rtthread
make sim-coremark COREMARK_ITERATIONS=3
```

也可以一次顺序执行：

```text
make sim-quick
```

四个检查的含义：

| 命令 | 检查内容 | 主要失败含义 |
| --- | --- | --- |
| `make sim-smoke` | 复位、取指、访存、`.data/.bss`、UART、GPIO、Test Status | CPU/总线/基础存储路径损坏 |
| `make sim-isa ISA_GATE=current` | 当前 demo core 已实现的快速 ISA 门 | 指令语义或提交行为回退 |
| `make sim-rtthread` | RT-Thread 启动、调度、tick、中断和基本 BSP | Trap、CSR、中断或上下文切换损坏 |
| `make sim-coremark COREMARK_ITERATIONS=3` | 启动 RT-Thread，通过 UART 输入命令，检查 CoreMark CRC 并统计性能窗口 | shell/UART/OS/CoreMark 或长指令流回退 |

当前 core 仍是框架参考实现时使用 `ISA_GATE=current`。正式 CPU 完成
RV32IM、Machine Mode、Zicsr/Zicntr/Zifencei 后，执行：

```text
make sim-isa ISA_GATE=final-base
```

该门包含 RV32UI、RV32MI 和 RV32UM。浮点方案确定后再选择
`fp-single` 或 `fp-double`；不要在 F/FD 尚未确定时把 `final` 当作已完成门。

里程碑检查入口是：

```text
make sim-full
```

它顺序运行 `final-base`、RT-Thread 和 `coremark 10`。在正式 CPU 尚未支持完整
RV32MI/RV32UM 时，`sim-full` 失败是预期结果，不应降低验收集合来迁就当前 core。

### 3.2 CoreMark 仿真如何工作

例如：

```text
make sim-coremark COREMARK_ITERATIONS=3
```

Runner 执行以下过程：

1. 构建 `rtthread-coremark` 固件；
2. 启动 `soc_sim_top`；
3. 按配置的 UART 波特率逐位解码 `uart_tx_o`，等待 transcript 的末尾完整出现
   `msh >`；只看到 `msh`、`msh ` 或零散字符都不会触发；
4. 检测到提示符后等待一个 UART bit time，再按 100 MHz、115200 baud 的真实
   UART 帧向 `uart_rx_i` 发送
   `coremark 3\r`；
5. CoreMark 通过硬件 timer 划定测量窗口；
6. checker 检查 UART framing、命令轮次、`crclist=0xe714`、
   `crcmatrix=0x1fd7`、`crcstate=0x8e3a`、项目 CRC PASS 文本、数值型精确
   tick、完整性能窗口和 Test Status；
7. 记录 cycles、commits、IPC、每轮 cycles 和模拟秒数。

默认提示符超时是 5,000,000 cycles。超时结果为 `uart_prompt_timeout`，
`checker.command_sent` 保持 `false`，因此不会再用固定 cycle 盲发命令。

轮次可以改为其他小值：

```text
make sim-coremark COREMARK_ITERATIONS=1
make sim-coremark COREMARK_ITERATIONS=10
```

短仿真不足 CoreMark 官方要求的 10 秒，所以日志中的上游程序会提示运行时间不足。
这不等于 CRC 错误。项目额外输出 `SocRV CoreMark CRC check PASS/FAIL` 和 64 位
精确 tick。短仿真只能用于正确性和同配置性能趋势比较，不能作为正式 CoreMark
分数。

### 3.3 结果在哪里看

单次结果：

```text
build/result/soc/<test>.json
build/log/soc/<test>.log
```

常见文件：

```text
build/result/soc/baremetal-smoke.json
build/result/soc/rtthread-smoke.json
build/result/soc/rtthread-coremark-command-3.json
build/log/soc/rtthread-coremark-command-3.log
```

CoreMark JSON 中重点看：

- `status`：应为 `PASS`；
- `exit_reason`：正常为 Test Status 完成；提示符或 checker 失败时会给出明确原因；
- `checker.passed`：UART/CoreMark 可执行判定；
- `checker.prompt_seen` / `checker.prompt_cycle`；
- `checker.command_sent` / `checker.command_cycle`；
- `checker.framing_error`、`checker.missing`、`checker.forbidden_seen`；
- `cycles`：从复位到测试完成的总仿真周期；
- `performance.cycles`：CoreMark 测量窗口；
- `performance.commits`；
- `performance.ipc`；
- `performance.cycles_per_iteration`；
- `performance.iterations_per_second`。

ISA 汇总位于：

```text
build/regression/isa/<gate>/summary.json
```

JSON testlist 回归汇总位于：

```text
build/regression/<suite>/summary.json
```

只有需要定位失败时再开波形：

```text
make sim-smoke TRACE=1
make sim-coremark COREMARK_ITERATIONS=3 TRACE=1
```

波形位于：

```text
build/wave/soc/<test>.vcd
```

开启 VCD 会明显降低速度并增加磁盘占用，因此不建议给整套 ISA 回归开波形。

### 3.4 Verilator 模型复用

Runner 对 RTL、递归 filelist、Verilator flags、C++ harness、头文件和 Verilator
版本计算内容指纹。CPU 或 memory RTL 改变后会自动重建模型；输入未变时复用现有
模型。这样不会因为误用旧 executable 而得到假通过。

## 4. 软件如何编译

### 4.1 构建最终 FPGA 固件

```text
make software-fpga
```

等价于构建 `rtthread-coremark` profile。该固件启动后停留在 FinSH/MSH，不会自动
运行 CoreMark。

主要产物：

```text
build/software/rtthread-coremark/firmware.elf
build/software/rtthread-coremark/firmware.map
build/software/rtthread-coremark/firmware.dis
build/software/rtthread-coremark/firmware.bin
build/software/rtthread-coremark/size.json
build/software/rtthread-coremark/build_manifest.json

build/images/rtthread-coremark/code.mem
build/images/rtthread-coremark/data.mem
build/images/rtthread-coremark/image.json
```

文件用途：

- `firmware.elf`：带符号的主软件产物；
- `firmware.map`：检查 section、符号和链接地址；
- `firmware.dis`：对照 CPU 执行路径和反汇编；
- `size.json`：检查 CODE/DATA 容量；
- `build_manifest.json`：记录编译器、flags、源码 hash 和依赖 commit；
- `code.mem`/`data.mem`：Verilator 与 FPGA 共同使用的存储器初始化文件；
- `image.json`：记录镜像地址范围与 hash。

其他常用软件构建：

```text
make software-smoke
make software-rtthread
make software PROFILE=trap-timer
```

修改 Memory Map 后必须按顺序执行：

```text
make soc-contract
make isa-data
make check
make software-fpga
```

这会重新生成 BSP 头文件、linker 常量和 riscv-tests 镜像，不能继续使用旧地址布局
下的 `data/isa`。

## 5. 如何综合、生成 bitstream 和查看结果

本节给出命令，但本次框架修复没有调用 Vivado。

### 5.1 完整构建

默认 profile 已设为 `rtthread-coremark`：

```text
make fpga-build
```

显式写法：

```text
make fpga-build PROFILE=rtthread-coremark JOBS=4
```

该命令会：

1. 编译统一软件镜像；
2. 创建 Kintex-7 Vivado 工程；
3. 运行 synthesis；
4. 运行 implementation；
5. 生成 bitstream；
6. 检查实现后 timing、DRC 和 bitstream；
7. 写出机器可读的 `result.json`。

### 5.2 bitstream 和报告位置

bitstream：

```text
build/vivado/kintex7-100mhz-rtthread-coremark/project/socrv.runs/impl_1/fpga_top.bit
```

机器可读结果：

```text
build/vivado/kintex7-100mhz-rtthread-coremark/result.json
```

报告目录：

```text
build/vivado/kintex7-100mhz-rtthread-coremark/project/reports/
```

主要报告：

```text
post_synth_utilization.rpt
post_synth_timing_summary.rpt
post_synth_clock_utilization.rpt
post_synth_cdc.rpt
post_impl_utilization.rpt
post_impl_timing_summary.rpt
post_impl_drc.rpt
post_impl_methodology.rpt
```

优先检查：

- `result.json` 的 `status`、`timing_met`、`drc_error_count`；
- `post_impl_timing_summary.rpt` 的 WNS/TNS 和时序是否满足；
- `post_impl_utilization.rpt` 的 LUT、FF、BRAM、DSP 使用量；
- `post_impl_drc.rpt` 的 Error/Critical Warning。

只检查已有结果，不重新综合：

```text
make fpga-check
```

### 5.3 下载和板上运行

已有 bitstream 后：

```text
make fpga-program
```

串口设置：

```text
115200 baud
8 data bits
no parity
1 stop bit
no flow control
```

看到 `msh >` 后输入：

```text
coremark 10000
```

命令会输出上游 CoreMark 信息，以及 SocRV 的 64 位精确 total ticks、total time
和 ticks/iteration。结束后返回 shell，可以继续执行 `socrv_info` 或再次运行
CoreMark。

板上 10000 轮才是目标测量路径。是否能对外称为正式 CoreMark 分数，还应同时满足
CoreMark 的运行时长、编译选项和报告规则；仿真的少量轮次结果不替代板上结果。

## 6. BRAM 延迟与仿真/FPGA 一致性

统一配置在：

```text
rtl/common/pkg/soc_config_pkg.sv
```

参数：

```systemverilog
CODE_MEM_RESPONSE_LATENCY
DATA_MEM_RESPONSE_LATENCY
```

两者默认为 1，且必须大于等于 1。`soc_top_generic` 和 FPGA memory backend 都实例化
`generic_rom`/`generic_spram`，所以修改这些参数会同时改变 Verilator 与 FPGA 的
请求—响应等待周期。

例如尝试两拍响应时，将两项都改成 2，然后运行：

```text
make rtl-lint
make sim-smoke
make sim-isa ISA_GATE=current
make sim-rtthread
make sim-coremark COREMARK_ITERATIONS=3
```

功能仿真通过后，再由你显式执行：

```text
make fpga-build
```

比较不同延迟/CPU 版本时，至少保存：

- CoreMark result JSON；
- `post_impl_timing_summary.rpt`；
- `post_impl_utilization.rpt`；
- 对应的 Git commit 或 `git diff`；
- `build/verilator/soc/build_manifest.json` 的模型指纹。

增加响应延迟可能改善某些组合路径，也会增加 CPI。是否值得不能只看 Vivado 频率，
应同时比较 `cycles_per_iteration`。粗略性能应看
`frequency / cycles_per_iteration`，而不是单独追求更高时钟。

## 7. 推荐的实际迭代节奏

日常 CPU 小改：

```text
make sim-smoke
make sim-isa ISA_GATE=current
```

涉及 Trap、CSR、interrupt、访存或流水线控制：

```text
make sim-quick
```

准备阶段性合入：

```text
make check
make sim-full
make software-fpga
```

准备上板：

```text
make fpga-build
make fpga-check
make fpga-program
```

板上：

```text
coremark 10000
```

这样的分层能把多数 CPU 回退留在快速仿真阶段，同时保证最终 FPGA 使用的仍是同一套
SoC、memory、BSP、RT-Thread、CoreMark 和镜像生成链路。
