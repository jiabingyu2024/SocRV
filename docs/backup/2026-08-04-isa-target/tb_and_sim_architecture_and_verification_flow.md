# TB 与 Sim 内部结构规划：从单元测试到 SoC 回归

> 适用项目：`SocRV` 自研 RV32 CPU、HXI SoC、Verilator 仿真、RT-Thread、CoreMark 与 FPGA 上板前验证。  
> 本文与 `project_structure_for_verilator_and_fpga.md`、`rtl_internal_hierarchy_and_soc_interfaces.md` 配套，展开其中 `tb/` 与 `sim/` 两侧的职责、内部层次、接口和运行流程。  
> 本文规划的是目标结构。当前仓库不需要一次创建所有空目录，也不要求照搬上一轮 `superScalar` 的文件；相应文件在功能开始实现时建立。

---

## 当前落地基线与取舍（2026-08-04）

本阶段保留本文的分层边界，但不机械创建三个仿真 Top。当前五条必需路径都
使用 `soc_sim_top`：

| 路径 | 入口 | 判定与产物 |
| --- | --- | --- |
| ISA 直接快速验证 | `make sim-isa` | 官方 riscv-tests 生成的 40 个 RV32UI 镜像，逐项 Test Status，汇总到 `build/regression/isa/` |
| 裸机 smoke | `make sim-smoke` | DATA/BSS、UART、GPIO、Test Status |
| RT-Thread 正确性 | `make sim-rtthread` | 内核启动、调度、Timer/Software IRQ、FinSH/MSH、Test Status |
| RT-Thread + 少量 CoreMark | `make sim-rtthread-coremark-smoke` | 1 iteration，上游参考 CRC `0xe714`、Test Status、完整性能窗口 |
| RT-Thread + 多轮 CoreMark | `make sim-rtthread-coremark-perf` | 10 iterations，同样先检查 CRC，再输出简单仿真统计 |

一次顺序执行全部必需路径：

```text
make sim-required
```

这里选择单一 SoC Top，原因是当前 RV32UI 全量回归在模型已构建后已足够快，
而单独增加 `cpu_sim_top` 会立即复制镜像加载、Test Status、watchdog 和结果
协议。后续出现以下需求时再实现独立 Top：

- HXI/APB/Cache 的模块级随机背压或故障注入：补 `unit_sim_top`；
- 需要 DiffTest、CSR 专项或 SoC 外设明显拖慢 ISA：补 `cpu_sim_top`；
- 当前裸机、OS、CoreMark 路径继续使用 `soc_sim_top`。

当前 C++ Harness 已从单文件拆为：

```text
tb/cpp/
├─ soc_main.cpp
├─ adapter/
│  └─ soc_dut_adapter.h/.cpp
└─ common/
   ├─ sim_config.h/.cpp
   ├─ sim_control.h/.cpp
   ├─ sim_result.h/.cpp
   ├─ uart_decoder.h/.cpp
   └─ perf_stats.h/.cpp
```

`soc_dut_adapter` 是唯一包含 `Vsoc_sim_top.h` 的层；`sim_control` 管 reset、
cycle watchdog 与退出条件；`sim_result` 写统一 JSON；`perf_stats` 只统计
RTL 已可靠提供的 cycle 和 commit，不虚构 cache miss、branch miss 等事件。

模型复用由 `scripts/run_verilator.py` 的内容指纹控制。指纹覆盖 Verilator
版本、Top、flags、递归 filelist、所列 RTL、Harness C++ 和头文件。输入变化
时完整重建 `build/verilator/soc/obj_dir`；显式使用 `--no-rtl-build` 时，
旧模型会被拒绝。

### CoreMark 的正确性与简单性能统计

CoreMark 的 `start_time()`/`stop_time()` 在 Test Status CODE 寄存器写入
`perf_start_magic`/`perf_stop_magic`。Harness 以这两个 MMIO 事件划定算法
窗口，输出：

```text
cycles
commits
IPC
seconds（按 50 MHz SoC 时钟换算）
cycles_per_iteration
commits_per_iteration
iterations_per_second
```

短档和多轮档都必须先通过上游 CoreMark CRC 与最终 Test Status。为了让上游
“运行时长”功能校验能在 RTL 仿真中实际完成，这两个仿真 profile 的
`COREMARK_TICKS_PER_SEC=1` 是合成值；上面列出的 Harness 指标仍按真实
50 MHz cycle window 计算。它们适合做同一 RTL/工具配置下的简单趋势比较，
不是可发布的官方 CoreMark 分数。正式分数仍应使用 FPGA Profile 和符合
CoreMark 报告规则的轮次、计时与平台声明。

当前生成物位置：

```text
build/result/soc/<test>.json
build/log/soc/<test>.log
build/wave/soc/<test>.vcd
build/regression/<suite>/summary.json
build/verilator/soc/build_manifest.json
```

以下仍是后续项，不在当前已完成基线内：`unit_sim_top`、`cpu_sim_top`、
DiffTest、并行回归调度、覆盖率、branch/cache/stall 事件计数和性能阈值门禁。

---

## 0. 先给出推荐的 TB/Sim 总体结构

一次完整仿真由五层协作完成：

```text
Test Definition
    测什么、用哪个镜像、预期怎样结束、最大运行多久
            ↓
Runner / Regression
    解析测试清单、构建目标、启动进程、收集结果
            ↓
Simulator Configuration
    filelist、Top、编译选项、waiver、仿真器差异
            ↓
Testbench
    时钟复位、激励、模型、Monitor、Scoreboard、Harness
            ↓
DUT
    unit DUT / cpu_subsystem / soc_core
```

对应到仓库：

```text
tb/          验证逻辑本体：如何驱动、观察和判断 DUT
sim/         仿真目标配置：使用哪些源、Top、工具选项和测试清单
scripts/     自动化入口：如何构建、运行、回归和汇总
build/       生成物：可执行文件、日志、波形、结果和中间目录
rtl/         被验证的可综合设计，不反向依赖以上目录
software/    被 CPU/SoC 执行的软件，不包含仿真器专用判断
```

最重要的边界是：

```text
tb/ 定义“验证语义”
sim/ 定义“工具目标”
scripts/ 定义“执行流程”
build/ 只保存“执行产物”
```

推荐保留三类验证目标：

```text
unit_sim_top    模块级协议、边界条件和故障注入
cpu_sim_top     ISA、CSR/Trap、Cache、DiffTest 和性能
soc_sim_top     完整 SoC、外设、中断、裸机、RT-Thread 和 CoreMark
```

它们不是三个功能版本。它们应复用同一套 RTL，通过不同测试环境验证不同边界。

---

## 1. 推荐的 `tb/` 与 `sim/` 文件结构

```text
tb/
├─ common/
│  ├─ clock_reset_driver.sv
│  ├─ timeout_monitor.sv
│  ├─ test_status_pkg.sv
│  ├─ hxi_bfm.sv
│  ├─ hxi_monitor.sv
│  ├─ apb_bfm.sv
│  ├─ apb_monitor.sv
│  └─ scoreboard/
│     ├─ scoreboard_base.sv
│     ├─ hxi_scoreboard.sv
│     └─ memory_scoreboard.sv
│
├─ unit/
│  ├─ cpu/
│  ├─ hxi/
│  ├─ cache/
│  ├─ memory/
│  ├─ timer/
│  ├─ uart/
│  └─ irq/
│
├─ models/
│  ├─ generic/
│  │  ├─ rom_model.sv
│  │  ├─ ram_model.sv
│  │  ├─ hxi_memory_model.sv
│  │  ├─ uart_host_model.sv
│  │  └─ gpio_host_model.sv
│  └─ xilinx_compat/
│     ├─ IROM_0.sv
│     ├─ DRAM_0.sv
│     ├─ MUL_0.sv
│     ├─ DIV_0.sv
│     └─ pll.sv
│
├─ tops/
│  ├─ unit_sim_top.sv
│  ├─ cpu_sim_top.sv
│  └─ soc_sim_top.sv
│
├─ cpp/
│  ├─ common/
│  │  ├─ sim_config.h/.cpp
│  │  ├─ sim_clock.h/.cpp
│  │  ├─ sim_control.h/.cpp
│  │  ├─ sim_memory.h/.cpp
│  │  ├─ sim_trace.h/.cpp
│  │  ├─ sim_result.h/.cpp
│  │  └─ perf_stats.h/.cpp
│  ├─ adapter/
│  │  ├─ cpu_dut_adapter.h/.cpp
│  │  └─ soc_dut_adapter.h/.cpp
│  ├─ checker/
│  │  ├─ isa_test_checker.h/.cpp
│  │  ├─ soc_test_checker.h/.cpp
│  │  └─ difftest_checker.h/.cpp
│  ├─ cpu_main.cpp
│  └─ soc_main.cpp
│
└─ tests/
   ├─ isa/
   ├─ unit/
   ├─ baremetal/
   ├─ rtthread/
   └─ coremark/

sim/
├─ filelists/
│  ├─ pkg.f
│  ├─ common_rtl.f
│  ├─ cpu_rtl.f
│  ├─ bus_rtl.f
│  ├─ memory_rtl.f
│  ├─ peripheral_rtl.f
│  ├─ soc_rtl.f
│  ├─ tb_common.f
│  ├─ tb_models_generic.f
│  ├─ verilator_cpu.f
│  ├─ verilator_soc.f
│  └─ fpga_kintex7.f
│
├─ verilator/
│  ├─ verilator_common.flags
│  ├─ verilator_lint.flags
│  ├─ verilator_waiver.vlt
│  └─ README.md
│
├─ xsim/
│  ├─ xsim_common.tcl
│  └─ README.md
│
└─ regression/
   ├─ testlist.yaml
   └─ expected_results.yaml

scripts/
├─ run_verilator.py
├─ run_regression.py
├─ elf2mem.py
├─ check_filelists.py
├─ check_memory_map.py
└─ collect_reports.py

build/
├─ verilator/
│  ├─ unit/<unit>/
│  ├─ cpu/
│  └─ soc/
├─ xsim/
├─ software/
├─ image/
├─ log/<target>/<test>.log
├─ result/<target>/<test>.json
└─ wave/<target>/<test>.fst
```

这是一套职责视图，不是要求一开始生成所有文件。第一阶段只建立能够跑通 Smoke Test 的最小闭环。

---

## 2. 各目录只能依赖谁

推荐依赖方向：

```text
tb/tests
   ↓
tb/checker
   ↓
tb/cpp/common + tb/common + tb/models
   ↓
tb/tops
   ↓
rtl/

sim/
   └─ 选择 rtl/ 与 tb/ 中哪些源参与某个目标

scripts/
   └─ 读取 sim/ 配置并驱动外部工具
```

禁止反向依赖：

```text
rtl/      不能 include tb/
rtl/      不能读取 sim/ 配置
software/ 不能依赖 Verilator API
tb/       不能依赖 build/ 中某次运行的临时文件
sim/      不能把 build/ 生成源码当作手写权威源
```

允许的特殊情况只有：

- 外部工具生成的 DiffTest probe；
- Verilator 生成的模型头文件；
- 软件编译生成的 ELF、HEX、MEM；
- Xilinx IP 仿真库。

这些都必须由脚本显式生成到 `build/`，并可从干净仓库重建。

---

## 3. `tb/` 与 `sim/` 的区别

### 3.1 `tb/` 回答“怎样验证”

进入 `tb/` 的内容包括：

- 时钟和复位激励；
- BFM；
- 仿真存储模型；
- UART Host；
- Monitor；
- Scoreboard；
- C++ Harness；
- DUT Adapter；
- Checker；
- Testbench Top；
- 仅用于验证的断言和故障注入。

### 3.2 `sim/` 回答“怎样交给某个仿真器”

进入 `sim/` 的内容包括：

- filelist；
- `--top-module`；
- Verilator flags；
- lint flags；
- warning waiver；
- XSim Tcl；
- 测试清单；
- 预期结果清单。

### 3.3 `scripts/` 回答“怎样自动执行”

脚本负责：

- 定位仓库根目录；
- 检查依赖工具；
- 选择构建目标；
- 调用软件构建和镜像转换；
- 调用 Verilator/XSim；
- 设置 `--Mdir`；
- 启动仿真；
- 传递运行参数；
- 收集日志、结果和波形；
- 汇总回归；
- 返回可靠的进程退出码。

脚本不应重新定义 HXI 协议，也不应在 Python 中实现一套与 C++ Checker 不同的 PASS/FAIL 规则。

### 3.4 `build/` 没有设计权威性

以下内容全部属于生成物：

```text
obj_dir
仿真可执行文件
自动生成头文件
编译日志
运行日志
FST/VCD
JSON 结果
软件 ELF/BIN/HEX/MEM
回归汇总
```

删除 `build/` 后，项目仍应能从源码和受控依赖重建。

---

## 4. 三层验证分别负责什么

### 4.1 Unit：尽早定位局部协议错误

目标 DUT：

```text
hxi_arbiter
hxi_crossbar
hxi_to_apb
generic_spram
hxi_data_mem_slave
machine_timer
apb_uart
interrupt_controller
cache refill/writeback
store buffer/load queue
```

Unit Test 重点：

- 边界地址；
- 握手背压；
- 同时请求；
- reset 中断事务；
- byte strobe；
- 非法访问；
- error response；
- FIFO 满/空；
- 计数器越界；
- IRQ pending/clear；
- 读写延迟。

Unit Test 不需要启动 CPU，也不需要编译 RT-Thread。

### 4.2 CPU：验证处理器体系结构行为

`cpu_sim_top` 重点：

- RV32 ISA；
- Zicsr 与已实现扩展；
- 异常、Trap、MRET；
- 三路 IRQ 注入；
- I/D HXI 行为；
- Cache；
- 非对齐策略；
- Commit Trace；
- DiffTest；
- 周期、指令数和 IPC。

CPU Test 应尽量绕开 UART、GPIO 和完整 APB 子系统，使构建快、失败原因集中。

### 4.3 SoC：验证软硬件集成行为

`soc_sim_top` 重点：

- Memory Map；
- Code/Data Memory；
- HXI Crossbar；
- Timer IRQ；
- UART 收发；
- External IRQ；
- 裸机启动；
- RT-Thread Tick；
- FinSH Console；
- CoreMark；
- 与 FPGA 使用相同软件镜像。

SoC Test 不应重复覆盖所有 ISA 组合。它证明的是“CPU、总线、存储、外设和软件能协同工作”。

### 4.4 三层测试的关系

```text
Unit
  证明局部模块和协议边界
        ↓
CPU
  证明处理器体系结构状态
        ↓
SoC
  证明完整系统和软件场景
```

下层通过是上层排查问题的前提，但上层不能替代下层。仅靠 RT-Thread 启动成功，无法证明所有 HXI 背压和异常边界正确。

---

## 5. `unit_sim_top` 的结构

每个复杂模块优先有独立 Top，不建议用一个巨大的通用 Top 通过大量宏选择 DUT。

例如 HXI Crossbar：

```text
hxi_crossbar_sim_top
├─ clock_reset_driver
├─ master0_hxi_bfm
├─ master1_hxi_bfm
├─ slave0_model
├─ slave1_model
├─ hxi_monitor
├─ hxi_scoreboard
└─ hxi_crossbar
```

如果单元数量较少，也可以先使用参数化的：

```text
unit_sim_top.sv
```

但必须满足：

- Top 名称和 DUT 选择显式；
- 不同 Unit 使用独立构建目录；
- 不通过宏改变 RTL 功能；
- 测试失败能指出事务、时间和期望值；
- Unit 测试可在不编译完整 SoC 的情况下运行。

---

## 6. `cpu_sim_top` 的结构与接口

推荐结构：

```text
cpu_sim_top
├─ cpu_subsystem
├─ I-side HXI memory model
├─ D-side HXI memory model
├─ IRQ injector
├─ commit monitor
├─ timeout monitor
└─ optional protocol assertions
```

对 C++ Harness 暴露稳定信号：

```text
Clock/Reset
    clk_i
    rst_i

Commit
    commit_valid
    commit_pc
    commit_inst
    commit_wen
    commit_rd
    commit_wdata
    commit_trap
    commit_cause
    commit_next_pc

Memory observation
    commit_mem_valid
    commit_mem_write
    commit_mem_addr
    commit_mem_wdata
    commit_mem_wstrb

Control
    irq_software
    irq_timer
    irq_external
```

如果处理器支持双发射或多退休，上述 Commit 字段变为固定槽位数组，并增加：

```text
commit_valid[NCOMMIT]
commit_order[NCOMMIT]
```

`commit_order` 必须能够确定架构退休顺序，Checker 不能用 C++ 端口扫描顺序猜测。

### 6.1 CPU 仿真不直接读深层层次

禁止长期依赖：

```text
TOP.u_cpu.u_rob.entries[...]
TOP.u_cpu.u_regfile.mem[...]
TOP.u_cpu.u_dcache.data_array[...]
```

这些路径只能用于临时 Debug，不能作为 PASS/FAIL 的正式输入。

正式 Checker 使用：

- Commit Trace；
- HXI Monitor；
- 显式 Debug Port；
- 受控的 memory loader；
- DiffTest packet。

### 6.2 CPU Memory Model 的职责

CPU 级模型负责：

- 加载 Code/Data 镜像；
- 匹配 HXI 握手；
- 返回确定的读写响应；
- 检查越界；
- 支持 byte strobe；
- 可选固定延迟；
- 可选带固定 seed 的随机背压；
- 为 Checker 提供只读快照或事务日志。

它不负责：

- 猜测 Cache 内部状态；
- 修改 CPU 架构寄存器；
- 替 RTL 修复错误地址；
- 用组合读掩盖 FPGA 同步 BRAM 延迟。

---

## 7. `soc_sim_top` 的结构与接口

推荐结构：

```text
soc_sim_top
├─ soc_core
│  ├─ cpu_subsystem
│  ├─ hxi_crossbar
│  ├─ memory slaves
│  ├─ machine_timer
│  ├─ hxi_to_apb
│  ├─ uart
│  └─ irq controller
├─ code memory backend
├─ data memory backend
├─ uart_host_model
├─ gpio_host_model
├─ commit monitor
└─ termination monitor
```

SoC Top 面向 Harness 暴露：

```text
Clock/Reset
UART host byte stream
GPIO input/output
Commit Trace
Simulation termination event
可选性能计数器
```

### 7.1 UART Host Model 的边界

UART Host Model 有两种模式：

```text
bit-accurate
    通过 uart_rx_i / uart_tx_o 按波特率发送和采样

transaction-level
    在明确的仿真专用 Wrapper 边界交换字节
```

默认 SoC 回归优先使用 bit-accurate 模式验证真实 UART RTL。长时间软件性能测试可使用 transaction-level 加速，但必须：

- 不修改 `apb_uart` 功能；
- 与 bit-accurate 模式使用相同字节语义；
- 至少保留一个 bit-accurate Smoke Test；
- 结果中记录使用的模式。

### 7.2 GPIO Host Model

GPIO 模型负责：

- 提供开关/按键输入；
- 观察 LED/状态输出；
- 按测试清单注入时序事件；
- 把输出变化写入结构化事件日志。

GPIO 模型不应知道 CPU 寄存器编号或 RTL 内部状态。

### 7.3 SoC Top 与 FPGA Top 的一致性

两者应共享：

```text
soc_core
Memory Map
外设寄存器定义
IRQ 连线
软件镜像格式
UART 字节语义
```

不同点只在：

```text
soc_sim_top → 仿真 Clock、Generic Model、Host Model
fpga_top    → PLL、Xilinx Backend、真实 Pins
```

---

## 8. Testbench 公共组件

### 8.1 Clock/Reset Driver

统一规则：

```text
Clock 初始为 0
半周期翻转
Reset 至少覆盖若干完整上升沿
Reset 只在非采样边沿改变
释放后再等待固定稳定周期
```

运行参数可以覆盖：

```text
clock_period
reset_cycles
```

但普通回归使用统一默认值。不能让每个 Test 自己实现一份略有不同的复位序列。

### 8.2 BFM

HXI/APB BFM 负责产生协议合法的事务：

```text
read
write
idle
backpressure
error injection
```

BFM 的任务是驱动，不是判断最终功能是否正确。

### 8.3 Monitor

Monitor 只在握手真正发生时采样：

```text
request_fire  = req_valid && req_ready
response_fire = rsp_valid && rsp_ready
```

采样结果转换为统一事务：

```text
timestamp
master_id
slave_id
address
write
size
wdata
wstrb
rdata
error
```

Monitor 不应驱动 DUT。

### 8.4 Scoreboard

Scoreboard 维护期望模型并比较：

- 请求和响应是否一一对应；
- 返回给哪个 Master；
- 数据是否正确；
- byte strobe 是否生效；
- error 是否符合地址和权限；
- 事务是否在允许时间内完成。

错误信息至少包含：

```text
test
cycle
transaction id
expected
actual
最近若干事务
```

### 8.5 Assertion

协议不变量优先由 SVA 表达：

```text
valid && !ready 时 payload 稳定
一笔请求最多命中一个 Slave
响应只返回事务 Owner
单 outstanding 不重复接收
FIFO 不上溢、不下溢
APB Setup/Access 状态合法
```

Assertion 与 Scoreboard 互补：

```text
Assertion  检查局部时序不变量
Scoreboard 检查跨周期、跨模块的数据和功能结果
```

---

## 9. 仿真模型怎样组织

### 9.1 Generic Model

`tb/models/generic/` 用于厂商无关仿真：

- ROM/RAM；
- HXI Memory；
- UART Host；
- GPIO Host；
- 可选外部 IRQ Source。

这些模型可以不可综合，但必须有明确接口契约。

### 9.2 Xilinx Compatibility Model

`tb/models/xilinx_compat/` 只用于兼容旧模块名或验证 Wrapper：

```text
IROM_0
DRAM_0
MUL_0
DIV_0
pll
```

长期目标是让通用 CPU/SoC 仿真使用 Generic Model，而不是依赖 Xilinx 模块名。

### 9.3 模型与 FPGA Backend 必须呈现相同行为

需要冻结：

- 地址单位：byte 或 word；
- 读延迟；
- 写完成时机；
- byte enable；
- read-during-write；
- 越界行为；
- reset 对输出的影响；
- 初始化文件格式。

尤其不能出现：

```text
仿真 RAM 组合读、零延迟
FPGA BRAM 同步读、两拍延迟
上层却按同一状态机使用
```

### 9.4 随机行为必须可重现

支持随机背压时，结果必须记录：

```text
seed
stall probability
min/max latency
error injection profile
```

日志必须打印可直接复制的复现命令。

---

## 10. C++ Harness 的内部层次

推荐把 Harness 拆成以下职责：

```text
main
  只负责组合组件和顶层退出码

sim_config
  解析命令行，冻结一次运行的配置

sim_clock
  产生 half-cycle，调用 eval

sim_control
  reset、主循环、timeout、退出条件

sim_memory
  镜像加载和受控内存访问

sim_trace
  打开、写入和关闭 FST/VCD

sim_result
  统一 PASS/FAIL/ERROR 与 JSON

perf_stats
  cycle、instret、IPC 和事件计数

dut_adapter
  屏蔽不同 Top 生成类和端口命名

checker
  判断 ISA、SoC 场景或 DiffTest 结果
```

### 10.1 `main()` 不承载验证细节

推荐：

```cpp
int main(int argc, char** argv) {
    SimConfig config = SimConfig::parse(argc, argv);
    CpuDutAdapter dut(config);
    SimControl sim(config, dut);
    SimResult result = sim.run();
    result.write_json(config.result_path);
    return result.exit_code();
}
```

实际类名可调整，但职责要保持。

### 10.2 DUT Adapter

Adapter 是 C++ Harness 与 Verilator 生成模型之间唯一允许知道具体 Top 类名的层。

例如：

```text
cpu_dut_adapter
    Vcpu_sim_top
    Commit Trace
    IRQ 控制

soc_dut_adapter
    Vsoc_sim_top
    UART/GPIO
    Commit Trace
```

其他公共组件不直接 include 多个 `V<top>.h`，避免顶层改名导致整个 Harness 扩散修改。

### 10.3 时间推进

统一使用：

```text
drive falling-edge inputs
eval
clock rising
eval
sample rising-edge outputs
clock falling
eval
```

如果启用 Verilator timing 功能，也必须在公共 `sim_clock` 中统一管理，不允许不同 Checker 自己推进时间。

### 10.4 资源释放

在 PASS、FAIL、timeout 或异常退出时均要：

- 调用模型 `final()`；
- 关闭波形；
- 刷新日志；
- 输出 JSON；
- 返回非歧义退出码。

---

## 11. 一次测试如何开始和结束

### 11.1 启动阶段

标准顺序：

```text
解析 Test Definition
→ 检查镜像和参数
→ 构建或复用对应仿真目标
→ 实例化 DUT
→ 加载 Code/Data 镜像
→ 打开可选波形
→ 施加 Reset
→ 进入运行循环
```

### 11.2 结束条件必须显式

允许的结束机制：

```text
tohost
测试状态 MMIO 寄存器
UART 中的明确结束协议
GPIO/Counter 的明确通过条件
DiffTest mismatch
Assertion failure
Watchdog timeout
模型或 Harness 内部错误
```

不推荐仅凭：

```text
PC 一段时间不变
看见某个普通 UART 字符串
执行到某个硬编码内部层次
仿真进程自然退出
```

### 11.3 统一状态

建议内部状态：

```text
PASS
FAIL
TIMEOUT
ASSERTION
DIFF_MISMATCH
BUILD_ERROR
CONFIG_ERROR
CRASH
NO_RESULT
UNSUPPORTED
```

回归通过条件只接受 `PASS`。`UNSUPPORTED` 必须被明确统计，不能悄悄当作通过。

### 11.4 Watchdog

至少支持：

```text
max_cycles
max_wall_time
max_cycles_without_commit
```

其中 `max_cycles_without_commit` 对 WFI、Timer 等场景可能不适用，必须由测试配置显式关闭或放宽，不能由 Harness 猜测。

---

## 12. 软件镜像与 Memory Loader 的契约

### 12.1 权威输入优先使用 ELF

推荐流程：

```text
software source
→ ELF
→ elf2mem.py
→ code.mem + data.mem + image.json
```

`image.json` 至少记录：

```json
{
  "elf": "build/software/hello/hello.elf",
  "entry": "0x00000000",
  "code_base": "0x00000000",
  "code_image": "build/image/hello/code.mem",
  "data_base": "0x10000000",
  "data_image": "build/image/hello/data.mem",
  "tohost": "0x10000080"
}
```

地址仅为格式示例，实际值必须来自冻结的 Memory Map 和链接脚本。

### 12.2 Loader 不重新解释链接布局

Loader 只按 manifest 加载：

```text
目标区域
基地址
文件格式
字节顺序
有效长度
```

它不应通过文件名猜测地址，也不应把 `.rodata` 固定塞进某个 RAM。

### 12.3 字节序和地址单位

必须统一：

```text
RISC-V little-endian
系统地址以 byte 为单位
MEM 文件每行代表什么
BRAM Wrapper 接收 byte address 还是 word index
```

`elf2mem.py`、Generic Model 和 FPGA COE 生成流程应使用同一个转换库或共同测试向量。

### 12.4 镜像一致性检查

建议自动检查：

- ELF 段不越出 Memory Map；
- Code 区权限正确；
- Data 区容纳 `.data/.bss/heap/stack`；
- Entry 位于可执行区域；
- 仿真与 FPGA 镜像来自同一 ELF；
- manifest 中的地址与 `memory_map_pkg`、链接脚本一致。

---

## 13. Commit Trace 与 DiffTest

### 13.1 Commit Trace 是体系结构边界

Checker 在退休点观察：

```text
PC
instruction
trap/cause
next PC
register write
load/store classification
effective address
store data
byte mask
```

不把 Issue、Execute 或 Writeback 当作架构完成点。

### 13.2 Reference Model 独立

Reference 侧内存必须独立初始化，并在参考执行的 store 退休时更新。

禁止：

- 直接读取 DUT RegFile 当作参考状态；
- 用 DUT 算出的 next PC 更新 Reference；
- 从 DUT Memory Model 直接复用写后状态而不检查 store；
- Commit packet 缺失时跳过比较。

### 13.3 非确定性输入

以下数据可能非确定：

```text
MMIO read
cycle/time counter
外部输入
中断到达时刻
```

处理方式：

1. 先验证指令、地址、权限和访问类型；
2. 再把受允许的非确定返回值同步给 Reference；
3. 结果中记录发生的同步；
4. 不得用“非确定”跳过整个 Commit。

### 13.4 Trap 和 Interrupt

DiffTest 必须比较：

```text
trap flag
cause
mepc
mtval（如果实现）
mstatus 相关位
handler PC
MRET 后 PC
```

外部中断注入使用测试配置中的确定 cycle/事件，保证可重现。

### 13.5 DiffTest 通路自检

必须保留一个 C++ 侧 fault injection 测试：

```text
把某次已知寄存器写回值翻转一位
→ DiffTest 必须失败
```

故障注入只能修改 Checker 观察值，不修改 RTL。这样可以证明比较通路真实生效。

---

## 14. Filelist 和仿真目标

### 14.1 基础 RTL Filelist

```text
pkg.f
common_rtl.f
cpu_rtl.f
bus_rtl.f
memory_rtl.f
peripheral_rtl.f
soc_rtl.f
```

它们只列设计源，不列 C++，不列生成物。

### 14.2 TB Filelist

```text
tb_common.f
    package、driver、BFM、monitor、scoreboard

tb_models_generic.f
    ROM/RAM、HXI Memory、UART/GPIO Host
```

### 14.3 CPU 目标

```text
verilator_cpu.f
├─ pkg.f
├─ common_rtl.f
├─ cpu_rtl.f
├─ 必要 bus/cache RTL
├─ tb_common.f
├─ tb_models_generic.f
└─ tb/tops/cpu_sim_top.sv
```

构建参数：

```text
--top-module cpu_sim_top
--Mdir build/verilator/cpu/obj_dir
```

### 14.4 SoC 目标

```text
verilator_soc.f
├─ pkg.f
├─ common_rtl.f
├─ cpu_rtl.f
├─ bus_rtl.f
├─ memory_rtl.f
├─ peripheral_rtl.f
├─ soc_rtl.f
├─ tb_common.f
├─ tb_models_generic.f
└─ tb/tops/soc_sim_top.sv
```

构建参数：

```text
--top-module soc_sim_top
--Mdir build/verilator/soc/obj_dir
```

### 14.5 不把 C++ 源写入 `.f`

SystemVerilog filelist 与 C++ source list 分开：

```text
sim/filelists/*.f
    RTL 与 SV TB

scripts/run_verilator.py 中的目标描述
    C++ Harness 源、include、link 参数
```

后续目标增多时，可以把 C++ source list 独立为受控 manifest，但不要混入 RTL filelist。

### 14.6 自动检查

`check_filelists.py` 至少检查：

- 路径存在；
- 无绝对路径；
- 无重复文件；
- package 顺序；
- Top 存在；
- CPU 目标不包含 SoC 外设；
- Verilator 目标不包含 FPGA IP；
- FPGA 目标不包含 `tb/`；
- 同一模块无多个定义；
- 所有手写 RTL 至少进入一个预期目标。

---

## 15. `sim/verilator/` 的规则

### 15.1 Common Flags

公共 flags 包括：

```text
语言版本
warning 策略
trace 格式能力
线程/优化的稳定默认值
include 根目录
timescale 策略
```

不包含某个具体 Test 的镜像和超时。

### 15.2 Lint Flags

Lint 与仿真构建分开：

```text
lint-core
lint-soc
lint-tb
```

RTL Lint 不应因为 Testbench 中合法的 `initial`、延时或 DPI 使用而降低标准。

### 15.3 Waiver

每条 waiver 必须限定：

```text
warning 类型
文件/模块范围
原因
Owner
移除条件
```

禁止全局关闭：

```text
WIDTH
LATCH
MULTIDRIVEN
UNOPTFLAT
CASEINCOMPLETE
```

除非有逐项审查和明确范围。

### 15.4 Verilator 版本

回归结果记录：

```text
verilator --version
C++ compiler version
build flags hash
git commit
dirty state
```

这样不同机器出现结果差异时能够定位工具环境。

---

## 16. Runner 的命令行与行为

推荐统一入口：

```text
python scripts/run_verilator.py build --target cpu
python scripts/run_verilator.py build --target soc

python scripts/run_verilator.py run \
    --target cpu \
    --test rv32ui-p-add

python scripts/run_verilator.py run \
    --target soc \
    --test timer_irq

python scripts/run_verilator.py run \
    --target soc \
    --test rtthread \
    --trace
```

可支持的公共选项：

```text
--target
--test
--seed
--max-cycles
--trace
--trace-start
--trace-depth
--build
--no-build
--jobs
--result
--log
```

### 16.1 构建与运行分离

```text
build
    只生成仿真可执行文件

run
    只运行一个测试；默认检查可执行文件是否与源码匹配

regression
    选择测试集合并调度多个 run
```

是否重建不能只看“可执行文件存在”。至少应比较：

- filelist；
- 所列源文件时间或内容 hash；
- C++ source；
- flags；
- Verilator 版本；
- Top；
- 编译期参数。

### 16.2 Runner 返回码

建议：

```text
0  全部测试 PASS
1  至少一个测试 FAIL/TIMEOUT/DIFF_MISMATCH
2  配置或用法错误
3  构建失败
4  Harness/工具崩溃
```

JSON 是详细结果，进程退出码是 CI 和 Makefile 的第一层判断。两者必须一致。

### 16.3 并行回归

并行单位是独立测试进程。

每个测试拥有独立：

```text
log
result
wave
临时目录
seed
```

多个测试可以共享只读仿真可执行文件，但不能共享可写结果文件。

---

## 17. Regression Testlist

推荐 `testlist.yaml` 表达测试事实：

```yaml
tests:
  - name: rv32ui-p-add
    target: cpu
    suite: [smoke, isa, rv32ui]
    image: build/image/rv32ui-p-add/image.json
    checker: isa
    max_cycles: 20000

  - name: timer_irq
    target: soc
    suite: [smoke, soc, irq]
    image: build/image/timer_irq/image.json
    checker: tohost
    max_cycles: 200000

  - name: rtthread
    target: soc
    suite: [nightly, os]
    image: build/image/rtthread/image.json
    checker: uart_script
    max_cycles: 100000000
```

字段可按实现调整，但以下信息要有唯一来源：

- 测试名；
- 目标；
- suite/tag；
- 软件镜像；
- Checker；
- 超时；
- seed 或 seed 策略；
- 模型配置；
- 预期结束协议；
- 是否允许非确定输入。

### 17.1 测试分组

推荐：

```text
smoke
    每次提交，数分钟内

unit
    模块接口和边界

isa
    RV32 指令和 CSR/Trap

soc
    Memory Map、外设和 IRQ

os
    RT-Thread/FinSH

benchmark
    CoreMark 和性能

stress
    随机背压、随机 seed、长时间

nightly
    全量和慢测试
```

### 17.2 `expected_results.yaml`

只用于暂时记录：

- 当前明确不支持的 ISA 扩展；
- 已知、已审批的预期失败；
- 工具/平台限制。

每条必须包含：

```text
test
expected status
reason
owner
issue/doc link
expiry condition
```

不允许用大范围 wildcard 把未知失败统一标成预期。

---

## 18. 结果、日志与波形

### 18.1 JSON 结果格式

建议：

```json
{
  "schema_version": 1,
  "test": "timer_irq",
  "target": "soc",
  "status": "PASS",
  "seed": 1,
  "cycles": 18234,
  "commits": 9371,
  "ipc": 0.5139,
  "exit_reason": "tohost",
  "max_cycles": 200000,
  "image": "build/image/timer_irq/image.json",
  "simulator": {
    "name": "verilator",
    "version": "..."
  },
  "artifacts": {
    "log": "build/log/soc/timer_irq.log",
    "wave": null
  }
}
```

失败时增加：

```text
failure_kind
failure_cycle
expected
actual
last_commit
last_transactions
reproduce_command
```

### 18.2 日志

普通日志分为：

```text
固定 Header
    环境、commit、dirty、版本、命令、seed、镜像

运行事件
    reset、关键 IRQ、UART、Checker 错误

固定 Footer
    status、cycles、commits、IPC、退出原因、产物路径
```

默认不打印每拍和每条 Commit。详细 Commit Trace 使用独立选项。

### 18.3 波形

默认：

```text
关闭
```

失败复现：

```text
FST
限制层次和深度
支持 trace start cycle
必要时只保存失败前后窗口
```

普通回归失败后，Runner 可输出一条带 `--trace` 的复现命令。第一版不必自动重跑，以免一次逻辑失败变成两倍运行时间。

### 18.4 产物命名

```text
build/log/<target>/<test>.log
build/result/<target>/<test>.json
build/wave/<target>/<test>.fst
```

随机多 seed：

```text
build/result/<target>/<test>/seed_<seed>.json
```

避免并行时覆盖。

---

## 19. PASS/FAIL 的 Owner

不同层的判断 Owner：

| 事件 | 第一判断者 | 最终结果汇总 |
| --- | --- | --- |
| HXI 协议违规 | SVA/Monitor | `sim_result` |
| Unit 数据错误 | Scoreboard | `sim_result` |
| ISA `tohost` | ISA Checker | `sim_result` |
| Commit 不一致 | DiffTest Checker | `sim_result` |
| UART 脚本不匹配 | SoC Checker | `sim_result` |
| RTL `$fatal` | 仿真器/Harness | `sim_result` |
| 超时 | `sim_control` | `sim_result` |
| 进程崩溃 | Runner | Runner 生成 CRASH 结果 |
| 构建失败 | Runner | Runner 生成 BUILD_ERROR |

最终只能有一个结果文件 Owner：

```text
正常启动 Harness 后：
    Harness 写单测 JSON

Harness 未启动或崩溃：
    Runner 补写基础错误 JSON
```

Runner 不覆盖已存在且可解析的 Harness 结果，只校验退出码是否一致。

---

## 20. 性能统计

### 20.1 基础指标

CPU/SoC 统一：

```text
cycles
committed instructions
IPC
loads
stores
branches
branch misses
I-cache miss
D-cache miss
stall cycles
```

没有可靠 RTL 事件时不伪造指标。未实现的字段应标为 `null` 或不输出。

当前 `soc_sim_top` 已实现前三项 `cycles`、`committed instructions` 和
`IPC`。其余事件尚无冻结的 RTL 统计接口，当前结果不输出这些字段。

### 20.2 统计窗口

CoreMark 和长程序区分：

```text
boot cycles
warmup cycles
measured cycles
total cycles
```

统计窗口由软件标记或明确 MMIO 控制，不用 UART 文本出现时间近似。

当前协议复用 Test Status CODE 寄存器：

```text
software start_time()
  -> write perf_start_magic
  -> Harness records start cycle/commit

software stop_time()
  -> write perf_stop_magic
  -> Harness records end cycle/commit
```

Magic 数值由 `data/soc/software_contract.json` 唯一定义，并生成到 BSP 头文件。
若测试清单要求性能窗口而 Harness 没有同时观察到 start/stop，功能即使写出
PASS 也会被改判为 `performance_window_incomplete`。

### 20.3 性能回归不是功能通过条件

功能结果：

```text
PASS / FAIL
```

性能结果：

```text
metric + baseline + threshold
```

先确认结果正确，再判断性能是否退化。IPC 提升不能掩盖 DiffTest 失败。

---

## 21. Debug 分层

推荐排查顺序：

```text
结果 JSON
→ 测试日志末尾
→ 最近 Commit/总线事务
→ 带 trace 的单测复现
→ 波形
→ 临时增加局部 Probe
```

### 21.1 默认保留的失败上下文

Harness 使用环形缓冲保存：

```text
最近 32～128 条 Commit
最近 32～128 笔 HXI 事务
最近 IRQ 变化
最近 UART 字节
```

只在失败时打印，通常比从零打开全量波形更快。

### 21.2 不把 Debug 变成功能依赖

临时 Probe 可以：

- 增加日志；
- 增加波形信号；
- 观察内部状态。

不能：

- 改变 ready/valid；
- 延长状态；
- 修改 Cache/流水线功能；
- 只在 `VERILATOR` 下修复行为。

---

## 22. 与旧 `superScalar` 仿真资产的关系

上一轮工程只作为机制参考。可以评估复用：

| 旧资产 | 可保留的思路 | 当前结构中的目标位置 |
| --- | --- | --- |
| `tb/verilator/sim_config.*` | 统一运行参数 | `tb/cpp/common/` |
| `sim_control.*` | reset、主循环、timeout | `tb/cpp/common/` |
| `sim_memory.*` | 镜像加载抽象 | `tb/cpp/common/` |
| `sim_trace.*` | 波形默认关闭、按需开启 | `tb/cpp/common/` |
| `sim_result.*` | 统一 JSON 结果 | `tb/cpp/common/` |
| `perf_stats.*` | cycle/commit/IPC | `tb/cpp/common/` |
| `dut_*_io.*` | 隔离不同 Top 端口 | `tb/cpp/adapter/` |
| `checker_rv32.*` | ISA 结束与结果判断 | `tb/cpp/checker/` |
| `checker_src.*` | 场景化 SoC 判断 | `tb/cpp/checker/` |
| `tb/difftest/adapter/` | Commit-level DiffTest | `tb/cpp/checker/` 或独立 `tb/difftest/` |
| `scripts/run_verilator.py` | build/run 与 JSON 产物 | 新 `scripts/run_verilator.py` |
| `scripts/run_difftest.py` | 独立 DiffTest 目标 | 合并到统一 Runner 或保留薄入口 |

不应直接继承：

- `myCPU`、`student_top` 等旧 Top 名称；
- 依赖旧层次路径的 DUT IO；
- 旧 Memory Map；
- 旧比赛板卡 I/O；
- 用大量编译宏改变模块公开接口；
- 散落在 Runner 中的测试特例；
- `tb/verilator/` 与新 `tb/cpp/` 两套并存。

迁移原则：

```text
先冻结当前接口
→ 为新 Top 写 Adapter
→ 迁移公共控制组件
→ 用一个 ISA Smoke 和一个 SoC Smoke 验证
→ 再迁移 DiffTest、性能和长回归
```

---

## 23. 推荐的实现顺序

### 第一步：建立最小 CPU 仿真闭环

建立：

```text
sim/filelists/verilator_cpu.f
tb/tops/cpu_sim_top.sv
tb/cpp/cpu_main.cpp
tb/cpp/common/sim_config
tb/cpp/common/sim_control
tb/cpp/common/sim_result
scripts/run_verilator.py
```

验收：

```text
CPU build
一个最小程序 PASS
一个故意失败程序 FAIL
timeout 正确
JSON 与退出码一致
```

### 第二步：建立镜像契约

建立：

```text
elf2mem.py
image.json
Code/Data Memory Loader
Memory Map 一致性检查
```

验收同一个 ELF：

```text
cpu_sim_top 可运行
soc_sim_top 可加载
FPGA image 可生成
```

### 第三步：补 CPU ISA 与 Commit Trace

完成：

- ISA Test Checker；
- 稳定 Commit Port；
- CSR/Trap 测试；
- 基础性能统计；
- 最近 Commit 环形日志。

### 第四步：建立 SoC 仿真闭环

建立：

```text
verilator_soc.f
soc_sim_top.sv
soc_main.cpp
uart_host_model
soc_test_checker
```

验收：

```text
hello_uart
memory smoke
timer_irq
非法地址 error
```

### 第五步：补 Unit Test

优先顺序：

```text
HXI handshake/arbiter
Memory slave/BRAM latency
Timer
HXI-to-APB
UART
IRQ controller
Cache
```

Unit Test 应跟随对应 RTL 功能同步交付，不等 SoC 集成后再补。

### 第六步：接入 DiffTest

完成：

- Commit Adapter；
- Reference Model；
- 非确定 MMIO 规则；
- fault injection 自检；
- DiffTest suite。

### 第七步：接入 RT-Thread 与 CoreMark

完成：

- Timer Tick；
- UART Console；
- RT-Thread 启动；
- FinSH 可选交互脚本；
- CoreMark 统计窗口；
- 长测试波形策略。

### 第八步：建立回归与 CI

完成：

```text
testlist.yaml
smoke/unit/isa/soc/nightly
并行运行
summary.json
失败复现命令
工具版本记录
```

---

## 24. 每类 RTL 修改必须跑什么

### 只移动文件或调整 Filelist

```text
check_filelists
lint-core
lint-soc
CPU build
SoC build
Vivado elaboration
```

### 修改 CPU Frontend/Decode/Execute

```text
相关 Unit
ISA directed
DiffTest smoke
异常/CSR
SoC smoke
```

### 修改 Commit/CSR/Trap

```text
CSR/Trap directed
ECALL/illegal instruction
MRET
三路 IRQ injection
DiffTest
RT-Thread timer smoke
```

### 修改 HXI/Crossbar

```text
HXI Unit + random backpressure
同 Slave 仲裁
不同 Slave 并行
非法地址
CPU load/store
SoC smoke
```

### 修改 Memory/Cache

```text
byte strobe
读延迟
load/store directed
Cache refill/evict
Code 区 D-side read
随机背压
SoC 软件镜像加载
```

### 修改 Timer/IRQ

```text
Timer Unit
IRQ injection
baremetal timer_irq
RT-Thread tick/delay
UART external IRQ（若实现）
```

### 修改 UART/APB

```text
APB Unit
UART loopback
bit-accurate hello_uart
UART IRQ
RT-Thread Console
```

### 修改仿真 Harness/Checker

```text
已知 PASS
已知 FAIL
timeout
bad image
assertion failure
result JSON schema
退出码
DiffTest fault injection
```

Checker 自身的负向测试不能省略，否则“测试全绿”可能只是判断通路失效。

---

## 25. 编码前需要冻结的开放问题

### 必须尽快确认

1. CPU 是单退休还是多退休，Commit Trace 有几个槽位；
2. 第一阶段 I-side 是否已经使用 HXI；
3. Code/Data Memory 的基地址和容量；
4. `.rodata` 位于 Code 还是 Data 区；
5. Memory Backend 对上层呈现 1 拍还是 2 拍读延迟；
6. CPU Test 的正式结束机制使用 `tohost` 还是 Test Status MMIO；
7. SoC Test 是否保留统一 Test Status MMIO；
8. UART 长回归是否允许 transaction-level 加速；
9. DiffTest 使用何种 RV32 Reference；
10. 哪些 MMIO/Counter 允许非确定值同步；
11. Verilator 最低支持版本；
12. XSim 是否作为必须维护的第二仿真器。

### 本文推荐的暂定答案

```text
Commit：
    从第一版就使用稳定架构接口；多退休预留槽位和 order

I-side：
    目标接口按 HXI；迁移期可由 Adapter 兼容旧接口

Memory：
    地址以 byte 为单位；可见延迟以 FPGA Backend 为准

结束协议：
    ISA 优先 tohost
    SoC 使用统一 Test Status MMIO，UART 文本只作辅助

UART：
    Smoke 必须 bit-accurate
    长性能测试可选 transaction-level，并记录模式

DiffTest：
    Reference 独立维护架构状态和内存

随机：
    默认确定性；压力测试固定并记录 seed

波形：
    默认关闭，失败按需复现

第二仿真器：
    第一阶段 Verilator 为主；接口冻结后补 XSim elaboration/smoke
```

---

## 26. 最终验收标准

### 目录边界

- [ ] `tb/` 只保存验证逻辑与测试资产；
- [ ] `sim/` 只保存目标、工具和回归配置；
- [ ] `scripts/` 只负责编排与转换；
- [ ] 所有生成物进入 `build/`；
- [ ] `rtl/` 不依赖 `tb/`、`sim/` 或 Verilator API；
- [ ] FPGA filelist 不包含仿真模型。

### Unit

- [ ] HXI valid/ready 背压有定向测试；
- [ ] Crossbar ownership 和非法地址有测试；
- [ ] Memory byte strobe 和读延迟有测试；
- [ ] Timer、UART、IRQ 有独立测试；
- [ ] Scoreboard 错误信息包含完整事务上下文；
- [ ] Assertion 能让进程和 JSON 同时失败。

### CPU

- [ ] CPU 使用独立 `cpu_sim_top`；
- [ ] Commit Trace 是稳定公开接口；
- [ ] ISA、CSR/Trap、IRQ 有定向测试；
- [ ] Checker 不依赖深层层次；
- [ ] DiffTest packet 缺失是硬失败；
- [ ] DiffTest fault injection 能证明比较通路有效；
- [ ] 性能计数不影响功能判断。

### SoC

- [ ] SoC 使用独立 `soc_sim_top`；
- [ ] Memory Map 与链接脚本、镜像一致；
- [ ] UART 至少有 bit-accurate Smoke；
- [ ] Timer IRQ 能驱动裸机和 RT-Thread；
- [ ] MMIO 强制 non-cacheable；
- [ ] 同一 ELF 能生成仿真与 FPGA 镜像；
- [ ] RT-Thread 和 CoreMark 有明确结束协议。

### Runner 与回归

- [ ] CPU/SoC 使用独立 `--top-module` 与 `--Mdir`；
- [ ] Build 与 Run 可分离；
- [ ] 源码或 flags 改变后不会误用旧可执行文件；
- [ ] 每次运行有唯一 log/result/wave 路径；
- [ ] JSON、进程退出码和回归汇总一致；
- [ ] PASS、FAIL、TIMEOUT、CRASH、NO_RESULT 可区分；
- [ ] 随机失败能用记录的 seed 复现；
- [ ] 普通回归默认不生成波形；
- [ ] Testlist 是测试参数的唯一权威来源；
- [ ] 已知失败有 Owner 和移除条件。

### 可维护性

- [ ] 公共 Harness 不知道具体 Verilator Top 类名；
- [ ] DUT 差异集中在 Adapter；
- [ ] 模型行为与 FPGA Backend 契约一致；
- [ ] 测试本身有正向和负向自检；
- [ ] Smoke Test 在主分支始终可运行；
- [ ] 删除 `build/` 后可以完整重建。

---

## 27. 一句话理解各层边界

```text
unit_sim_top：
    把一个模块单独放到协议和边界压力下

cpu_sim_top：
    观察 CPU 的架构退休行为，不引入无关 SoC 外设

soc_sim_top：
    把同一个 CPU 放回完整 SoC，运行真实软件

BFM：
    产生合法激励

Monitor：
    把引脚活动还原成事务

Scoreboard：
    判断事务和数据是否正确

Model：
    模拟 DUT 外部环境，并严格遵守冻结接口

C++ Harness：
    推进仿真、控制生命周期、连接 Checker

DUT Adapter：
    隔离具体 Top 和 Verilator 生成端口

sim/filelists：
    决定某个目标编译哪些源

sim/verilator：
    决定 Verilator 怎样编译这些源

sim/regression：
    决定有哪些测试和预期

scripts：
    把构建、运行和结果收集串成可重复命令

build：
    保存本次执行的全部可删除产物
```

对当前项目，最关键的 TB/Sim 边界是：

```text
稳定 Commit Trace
+ 冻结 HXI/Memory 行为
+ 明确 Test Status
+ 独立 CPU/SoC Top
+ 统一 JSON 结果
+ 可复现 seed 与失败命令
```

这几个边界冻结以后，RTL 开发、验证环境、软件移植和 FPGA 集成才能并行推进。
