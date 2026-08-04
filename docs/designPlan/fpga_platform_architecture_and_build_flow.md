# FPGA 侧结构与实现流程

> 适用项目：`SocRV` 自研 RV32 CPU、HXI SoC、Xilinx FPGA、片上 BRAM、UART/GPIO 与可选 digital twin。  
> 本文与项目结构、RTL、TB/Sim 规划配套，说明 `fpga/` 的目录职责、板级层次、Backend/IP、时钟复位、约束、Vivado Tcl、报告和上板验收。  
> 本文不填写尚未冻结的板卡引脚、时钟频率、BRAM 容量和 IP 参数；这些值确认后进入板卡 Profile、XDC 和架构事实表。

---

## 0. FPGA 侧的总体边界

FPGA 侧负责把厂商无关的 SoC 接到具体器件和开发板：

```text
Board Pins
    差分/单端时钟、复位按键、UART、GPIO、LED
            ↓
fpga_top
    板级 Buffer、PLL/MMCM、复位同步、I/O Wrapper
            ↓
Platform Backend
    Xilinx BRAM、乘除法 IP、可选 ILA
            ↓
soc_core
    CPU、HXI、Memory Slave、Timer、UART、IRQ
```

目录边界：

```text
rtl/    芯片功能，不知道板卡和 Xilinx IP 名称
fpga/   平台适配、板级连接、XDC、Tcl、IP 参数
data/   受控板卡/Profile 输入与可复用初始化数据
scripts/ 调用 Vivado、生成镜像、收集报告
build/  Vivado 工程、运行目录、bitstream 和报告
```

FPGA 侧不重新实现 SoC 功能。地址译码、Timer、UART 寄存器、Cache 属性和 IRQ 优先级仍由 `rtl/` 中的 Owner 模块负责。

---

## 1. 推荐目录

```text
fpga/
├─ common/
│  ├─ rtl/
│  │  ├─ xilinx_code_mem_backend.sv
│  │  ├─ xilinx_data_mem_backend.sv
│  │  ├─ xilinx_mul_backend.sv
│  │  ├─ xilinx_div_backend.sv
│  │  └─ xilinx_clock_wrapper.sv
│  └─ tcl/
│     ├─ create_ip.tcl
│     ├─ read_rtl_filelist.tcl
│     ├─ reports.tcl
│     └─ check_messages.tcl
│
├─ boards/
│  └─ kintex7_competition/
│     ├─ rtl/
│     │  ├─ fpga_top.sv
│     │  ├─ board_clock_reset.sv
│     │  ├─ board_io_wrapper.sv
│     │  └─ digital_twin_wrapper.sv
│     ├─ constraints/
│     │  ├─ pins.xdc
│     │  ├─ clocks.xdc
│     │  ├─ cdc.xdc
│     │  └─ debug.xdc
│     ├─ tcl/
│     │  ├─ create_project.tcl
│     │  ├─ synth.tcl
│     │  ├─ impl.tcl
│     │  ├─ bitstream.tcl
│     │  └─ program.tcl
│     ├─ board.yaml
│     └─ README.md
│
└─ profiles/
   ├─ smoke.yaml
   ├─ baremetal.yaml
   ├─ rtthread.yaml
   └─ coremark.yaml

sim/filelists/
└─ fpga_kintex7.f

data/
├─ boards/
├─ images/
└─ profiles/

build/vivado/
└─ kintex7_competition/<profile>/
   ├─ project/
   ├─ ip/
   ├─ reports/
   ├─ checkpoints/
   ├─ logs/
   └─ bitstream/
```

目录只在有实际文件时创建。Profile 的权威位置需要在编码前统一；推荐把“目标选择”放 `fpga/profiles/`，大体积或可共享输入放 `data/`。

---

## 2. 依赖方向

```text
fpga/boards/<board>/rtl/fpga_top.sv
    ├─ fpga/common/rtl/*
    ├─ rtl/soc/soc_core.sv
    └─ rtl/common/sync/*

fpga/boards/<board>/tcl/*
    ├─ sim/filelists/fpga_<board>.f
    ├─ fpga/common/tcl/*
    ├─ fpga/boards/<board>/constraints/*
    └─ fpga/profiles/<profile>.yaml 的受控输出
```

禁止方向：

```text
rtl/ → fpga/
rtl/ → Xilinx 生成目录
fpga/ → build/ 中某个不可重建文件
软件源码 → .xpr
Verilator filelist → fpga/common/rtl 的真实 IP Wrapper
```

允许 `fpga/common/rtl` 实例化 Xilinx 模块，但必须通过通用 Backend 接口连接 `soc_core`。

---

## 3. Board、Profile 与 Build Target

三个概念分开：

```text
Board
    器件、Package、引脚、输入时钟、物理外设

Profile
    软件镜像、功能开关、存储深度、Debug 选项

Build Target
    board + profile + build stage
```

示例：

```text
BOARD=kintex7_competition
PROFILE=rtthread
STAGE=bitstream
```

Board 不应包含某个应用的硬编码路径；Profile 不应重定义引脚。相同 Board 可以生成 Smoke、RT-Thread 和 CoreMark 等多个 bitstream。

---

## 4. `fpga_top` 的职责

推荐结构：

```text
fpga_top
├─ board_clock_reset
│  ├─ input clock buffer
│  ├─ PLL/MMCM wrapper
│  └─ reset synchronizer
├─ soc_core
├─ xilinx_code_mem_backend
├─ xilinx_data_mem_backend
├─ optional arithmetic backend
├─ board_io_wrapper
└─ optional debug wrapper
```

允许放入：

- 物理输入 Buffer；
- PLL/MMCM Wrapper；
- 每个时钟域的复位同步；
- Xilinx Memory/Arithmetic Backend；
- UART/GPIO 引脚连接；
- ILA、VIO 等可选调试实例；
- 必要的板级电平极性转换。

不允许临时加入：

- HXI 地址译码；
- Cache bypass；
- UART 寄存器；
- Timer 比较器；
- CSR/Trap 行为；
- 只为某个软件补丁服务的状态机。

`fpga_top` 主要完成实例化、连接和参数传递。

### 4.1 顶层端口

端口以板卡事实为准，典型形式：

```systemverilog
module fpga_top (
    input  logic         sys_clk_p_i,
    input  logic         sys_clk_n_i,
    input  logic         reset_button_i,
    input  logic         uart_rx_i,
    output logic         uart_tx_o,
    input  logic [N-1:0] switch_i,
    input  logic [M-1:0] key_i,
    output logic [K-1:0] led_o
);
```

实际端口、位宽和极性必须与原理图、比赛约束和 `pins.xdc` 一致，不从旧工程猜测。

### 4.2 板级极性

低有效按键、LED 或 UART 控制信号的极性转换集中在：

```text
board_io_wrapper
```

`soc_core` 内部统一使用逻辑语义：

```text
reset asserted = 1
gpio value     = 1 表示逻辑高
irq active     = 1
```

---

## 5. 时钟结构

### 5.1 时钟事实表

板卡文档需要维护：

| Clock | Source | Frequency | Domain Owner | Consumers |
| --- | --- | ---: | --- | --- |
| `sys_clk_*` | Board oscillator | 待冻结 | Board | Clock Wrapper |
| `soc_clk` | PLL/MMCM | 待冻结 | SoC | CPU/HXI/Memory/Peripheral |
| `debug_clk` | 可选 | 待冻结 | Debug | digital twin/ILA |

第一版推荐让 CPU、HXI、Memory、Timer 和 UART 数字逻辑使用同一个 `soc_clk`。UART 波特率使用 Clock Enable，不额外生成 UART Clock。

### 5.2 PLL/MMCM Wrapper

厂商原语和生成 IP 封装在：

```text
xilinx_clock_wrapper.sv
```

对上层暴露：

```text
input clock
generated clock
locked
```

`soc_core` 不直接实例化 `MMCME2_*`、Clock Wizard 或板卡输入 Buffer。

### 5.3 Generated Clock

所有真实派生时钟由 `clocks.xdc` 声明。Tcl/报告需要验证：

- 主时钟存在；
- PLL 输出时钟被识别；
- 周期与 Profile 一致；
- 没有意外自动派生时钟；
- 每个时序端点属于预期时钟。

### 5.4 不用普通逻辑生成时钟

禁止：

```systemverilog
always_ff @(posedge soc_clk)
    slow_clk <= ~slow_clk;
```

然后把 `slow_clk` 当作大量模块的新时钟。

低速功能优先使用 Clock Enable。确需新时钟域时，由专用 Clocking Resource 产生并完成 CDC、Reset 和约束。

---

## 6. 复位结构

推荐：

```text
external reset asserted
或 PLL not locked
        ↓
asynchronous assertion
        ↓
per-domain reset synchronizer
        ↓
synchronous deassertion
        ↓
soc_rst
```

### 6.1 Board Reset Owner

`board_clock_reset.sv` 负责：

- 外部按键极性；
- PLL lock；
- 上电稳定等待；
- 各时钟域同步释放；
- 可选 Debug Reset。

功能 RTL 接收已经同步好的 `rst_i`，不重复处理按键去抖或 PLL lock。

### 6.2 RAM 与复位

BRAM 数据数组不做全量复位。复位只清理：

- 控制 FSM；
- valid；
- outstanding；
- FIFO pointer；
- IRQ pending；
- 需要确定初值的可见寄存器。

程序和常量通过初始化镜像进入 BRAM。

### 6.3 复位释放检查

上板 Smoke 至少观察：

```text
PLL locked
soc_rst released
first fetch address
first commit
first UART byte 或 status
```

如果这些信号进入 ILA，使用与 TB/Sim 相同的观测语义。

---

## 7. CDC 边界

每条跨时钟路径必须有明确 Owner：

```text
single bit level
    bit_sync

pulse
    pulse_sync 或 toggle handshake

multi-bit status
    stable-data handshake / Gray code

stream
    async_fifo
```

### 7.1 CDC 不由 XDC 修复

`set_false_path` 和 `set_clock_groups -asynchronous` 只描述时序关系，不提供硬件同步。

正确顺序：

```text
先选择同步结构
→ 再写约束
→ 再检查 report_cdc
```

### 7.2 digital twin

若 digital twin 使用独立时钟：

```text
digital_twin domain
    ↕ async_fifo/handshake
soc domain
```

不能直接跨域采样多位总线或把 Gray Code 当作所有数据通路的通用解决方案。

### 7.3 CDC 报告

每个 Release 固定生成：

```text
report_clock_interaction
report_cdc
```

对已确认结构的 waiver 要限定实例路径、说明同步结构和移除条件，禁止大范围忽略两个时钟域之间的全部路径。

---

## 8. Memory Backend

FPGA 侧最重要的接口边界：

```text
HXI Memory Slave
        ↓
Native Memory Port
        ↓
xilinx_*_mem_backend
        ↓
Block Memory Generator / inferred BRAM
```

### 8.1 Native Memory Port

推荐：

```text
clk
en
addr
we[3:0]
wdata[31:0]
rdata[31:0]
```

契约必须冻结：

- byte address 还是 word index；
- Code/Data 深度；
- 读延迟；
- 写完成时机；
- byte enable；
- read-during-write；
- 初始化格式；
- 越界处理。

### 8.2 Code Memory

`xilinx_code_mem_backend`：

- 面向 SoC 为只读；
- 支持程序初始化；
- 对上层呈现固定读延迟；
- IP 名称只在 Wrapper 内出现；
- 容量来自 Board/Profile 的受控参数。

如果 D-side 需要读取 `.rodata` 所在 Code 区，Memory Slave 和 Backend 必须支持对应读路径。

### 8.3 Data Memory

`xilinx_data_mem_backend`：

- 支持 4 位 byte write enable；
- 支持 `.data/.bss/heap/stack`；
- 初始化行为与软件镜像一致；
- 不依赖全量 reset；
- 读延迟与 Verilator Model 相同。

### 8.4 推断 BRAM 与生成 IP

两种方案都可保留：

```text
Generic inferred BRAM
    结构简单、厂商依赖少

Xilinx Block Memory Generator
    初始化、端口和资源控制更明确
```

选择由资源、时序和工具稳定性决定。上层 Native Memory Port 不随选择变化。

---

## 9. Arithmetic Backend

乘除法可有两种实现：

```text
rtl/ 中可综合通用实现
fpga/common/rtl 中 Xilinx IP Backend
```

接口要冻结：

```text
request valid/ready
operation
operands
response valid/ready
result
latency/kill 语义
```

FPGA IP latency、流水级和 backpressure 不得泄漏成 CPU 内部的隐式假设。Verilator Model、Generic RTL 和 Xilinx Backend应呈现同一可见协议。

---

## 10. Xilinx IP 管理

### 10.1 权威来源

推荐权威来源：

```text
create_ip.tcl
+ 受控参数
+ 工具版本记录
```

生成的 `.xci/.dcp` 是否提交由工具可重建性决定，但不能成为没有参数记录的唯一来源。

### 10.2 IP 输出目录

```text
build/vivado/<board>/<profile>/ip/
```

不同 Board/Profile 不共用可写 IP 生成目录，避免参数串扰。

### 10.3 IP 检查

创建工程后检查：

- IP 是否存在；
- 生成状态是否正常；
- 输出产品是否完整；
- 没有 locked/upgrade required；
- 综合没有 black box；
- 参数与 manifest 一致。

### 10.4 工具版本

IP 对 Vivado 版本敏感。Release 记录：

```text
Vivado version
IP catalog version
device/part
IP parameter hash
```

跨版本升级需单独评审和回归。

---

## 11. XDC 组织

### 11.1 `pins.xdc`

只包含：

- `PACKAGE_PIN`；
- `IOSTANDARD`；
- 驱动强度和 Slew（确有依据时）；
- pull-up/down；
- 板级端口相关属性。

每个端口必须在 `fpga_top` 存在，未使用引脚不保留虚假约束。

### 11.2 `clocks.xdc`

包含：

- 输入 `create_clock`；
- generated clock；
- 与板卡/PLL 一致的周期；
- 必要的 clock uncertainty；
- 时钟关系。

### 11.3 `cdc.xdc`

包含经过结构评审的：

- 异步时钟组；
- 同步器属性；
- CDC 模块局部约束；
- 必要的 max delay/bus skew。

不把普通 timing violation 塞进 `cdc.xdc` 规避。

### 11.4 `debug.xdc`

仅在 Debug Profile 使用：

- ILA 相关约束；
- Debug Hub 时钟；
- 可选保留属性。

Release Profile 不因历史 Debug 信号而保留大量无用逻辑。

### 11.5 约束质量检查

每次实现检查：

```text
unconstrained paths
no_clock endpoints
multiple clocks
invalid object query
critical warning
ignored constraint
```

Tcl 查询返回空集合时应失败或显式警告，不能静默继续。

---

## 12. FPGA Filelist

`sim/filelists/fpga_kintex7.f` 建议包含：

```text
pkg.f
common_rtl.f
cpu_rtl.f
bus_rtl.f
memory_rtl.f
peripheral_rtl.f
soc_rtl.f
fpga/common/rtl/*
fpga/boards/kintex7_competition/rtl/*
```

禁止包含：

```text
tb/
tb/models/
Verilator C++
XSim 临时生成源码
build/ 中的旧综合网表
另一个 Board 的 fpga_top
```

### 12.1 Filelist 是源清单

Vivado Tcl 读取 filelist，不递归 glob 整个仓库。这样可以：

- 固定 package 顺序；
- 防止重复模块；
- 防止仿真模型进入综合；
- 让 Verilator 与 Vivado 共享主要 RTL 集合；
- 审查目标差异。

### 12.2 Source Property

Tcl 对 SystemVerilog、Verilog、XDC 和初始化文件设置正确类型。Header/include path 与 define 集中管理，不在多个 Tcl 中重复。

---

## 13. Vivado Tcl 分层

### 13.1 `create_project.tcl`

负责：

```text
创建 build 目录
设置 part/board
创建工程
读取 RTL filelist
读取 Board XDC
调用 create_ip
设置 fpga_top
设置语言和编译顺序
保存工程
```

不负责跑完整实现。

### 13.2 `synth.tcl`

负责：

```text
打开/创建工程
检查源和 IP
运行 synthesis
检查消息
写 post-synth checkpoint
生成综合时序和资源报告
```

### 13.3 `impl.tcl`

负责：

```text
opt_design
place_design
phys_opt_design（按策略）
route_design
写 checkpoints
生成 timing/utilization/clock/CDC/DRC 报告
```

每一阶段遇到不可接受的 error、critical warning、black box 或 timing failure 时返回非零。

### 13.4 `bitstream.tcl`

只对通过实现验收的 routed checkpoint 生成 bitstream。不能在时序失败后仍把文件当正式 Release。

### 13.5 `program.tcl`

负责：

- 连接 hw_server；
- 选择目标器件；
- 检查 bitstream 存在；
- 下载；
- 可选读回设备信息。

不把本地特定硬件序号写死在公共脚本中；多设备时由命令行或本地配置选择。

---

## 14. 构建阶段

推荐顶层目标：

```text
make fpga-elab
make fpga-synth
make fpga-impl
make fpga-bitstream
make fpga-build
make fpga-program
make fpga-report
```

其中 `fpga-build` 是从检查到 bitstream 的总入口，保留项目结构规划中的易记命令；其余目标用于阶段化调试。

阶段关系：

```text
environment check
→ software image
→ filelist/IP check
→ elaboration
→ synthesis
→ implementation
→ timing/DRC gate
→ bitstream
→ program
→ board smoke
```

顶层 Make 只提供入口。实际参数解析、目录创建、日志和工具调用由脚本/Tcl 完成。

---

## 15. Build 目录

```text
build/vivado/<board>/<profile>/
├─ manifest.json
├─ project/
├─ ip/
├─ logs/
│  ├─ create_project.log
│  ├─ synth.log
│  ├─ impl.log
│  └─ bitstream.log
├─ checkpoints/
│  ├─ post_synth.dcp
│  ├─ post_place.dcp
│  └─ post_route.dcp
├─ reports/
│  ├─ timing_summary.rpt
│  ├─ utilization_hier.rpt
│  ├─ clock_interaction.rpt
│  ├─ cdc.rpt
│  ├─ drc.rpt
│  ├─ blackbox.rpt
│  └─ power.rpt
└─ bitstream/
   ├─ SocRV.bit
   ├─ SocRV.ltx
   └─ release.json
```

`manifest.json` 记录：

```text
git commit/dirty
board/profile
part
Vivado version
RTL filelist hash
XDC hash
IP parameter hash
software ELF/image hash
build timestamp
```

---

## 16. 报告与 Gate

### 16.1 固定报告

每次 Release 至少生成：

```text
report_timing_summary
report_utilization -hierarchical
report_clock_interaction
report_cdc
report_drc
report_methodology
report_blackbox
```

Power Report 可在活动信息可靠时加入。

### 16.2 Gate

bitstream 前必须确认：

- WNS/TNS 满足目标；
- 没有 unconstrained endpoint；
- 没有 black box；
- DRC 无阻断项；
- CDC 无未审查严重问题；
- 利用率保留合理余量；
- 时钟被正确识别；
- 软件镜像匹配当前 Profile。

具体阈值由项目评审冻结，脚本不能把所有 Critical Warning 一律忽略。

### 16.3 Timing Debug

固定保存：

```text
最差 setup/hold 路径
按 clock group 汇总
按 hierarchy 汇总
高扇出网
拥塞信息
```

路径聚类和详细分析工具属于 `scripts/`，报告原文属于 `build/`。

---

## 17. 软件镜像进入 FPGA

推荐：

```text
software ELF
→ elf2mem.py
→ code.mem/data.mem/image.json
→ FPGA Profile
→ BRAM init / IP update
→ bitstream
```

### 17.1 同一镜像合同

SoC Sim 与 FPGA 使用同一个 `image.json`：

```text
entry
code base/size
data base/size
byte order
code image
data image
hash
```

不能让 Verilator 和 Vivado 各自用不同脚本解释 ELF。

### 17.2 快速更新程序

如果所选 Vivado/IP 流程支持安全更新 BRAM 初始化，可提供：

```text
make fpga-update-image
```

该目标必须验证：

- routed design 与软件 Memory Map 一致；
- BRAM 实例路径匹配；
- 镜像没有越界；
- 更新后的 bitstream 记录新软件 hash。

不满足条件时回退到完整综合/实现。

---

## 18. Debug 结构

### 18.1 稳定 Probe

优先观察：

```text
reset/lock
commit_valid/pc/inst
trap/cause
last HXI request/response
irq_timer/irq_external
UART byte event
mtime/mtimecmp
test status
```

这些信号与仿真使用相同语义。

### 18.2 ILA

ILA 放在 FPGA Debug Wrapper，按 Profile 启用。要求：

- 采样时钟明确；
- 跨域信号先同步或在所属域采样；
- Probe 宽度受控；
- Debug Profile 单独报告资源和时序；
- Release 可关闭。

### 18.3 UART

上板第一调试通道优先使用简单、可观察的 UART：

```text
boot marker
trap marker
test result
RT-Thread console
```

正式应用输出和诊断协议要区分，避免自动化脚本把普通文本误判成 PASS。

### 18.4 digital twin

如果比赛要求保留 digital twin：

- 板级协议和管脚位于 `fpga/boards/...`；
- 软件可见寄存器仍位于通用外设 RTL；
- 独立时钟通过明确 CDC；
- 不把 digital twin 状态机塞入 CPU 或 HXI Crossbar；
- 单独维护接口说明和上板测试。

---

## 19. 上板操作

标准流程：

```text
确认板卡和电源
→ 确认 JTAG/UART 连接
→ 生成或选择受控 bitstream
→ program
→ 观察 reset/lock
→ 运行 board smoke
→ 保存 UART/测试结果
```

### 19.1 Board Smoke

最低测试：

```text
clock/reset
first commit
Code/Data BRAM
UART TX
UART RX（若使用）
Timer IRQ
GPIO/LED
Test Status
```

### 19.2 上板结果

保存：

```text
board
device
bitstream hash
software hash
program time
UART log
test status
operator
```

结果进入 `build/result/fpga/<board>/<profile>/`，正式 Release 再归档。

---

## 20. Release 内容

推荐 Release 包：

```text
SocRV.bit
SocRV.ltx（Debug 版本）
release.json
software.elf
software.map
image.json
timing_summary.rpt
utilization_hier.rpt
cdc.rpt
drc.rpt
README.txt
```

`release.json` 至少记录：

- Git commit 和 dirty 状态；
- Board/Profile；
- Vivado 版本；
- part；
- 时钟目标；
- WNS/TNS；
- 资源摘要；
- bitstream/ELF hash；
- 已跑测试；
- 已知限制。

工作目录中的 `.xpr/.runs/.cache` 不作为 Release 交付物。

---

## 21. 与 TB/Sim 的一致性

FPGA 和 SoC Sim 共享：

```text
soc_core
Memory Map
IRQ Map
软件 ELF
image.json
BRAM 可见延迟
UART 字节语义
Test Status
Commit Trace 语义
```

两边差异：

| 内容 | SoC Sim | FPGA |
| --- | --- | --- |
| Clock | Harness | PLL/MMCM |
| Reset | TB Driver | Board Reset |
| Memory | Generic Model | Xilinx Backend |
| UART 对端 | Host Model | 物理串口 |
| Debug | Log/FST | ILA/UART |
| 运行结果 | JSON | UART/Test Status + 归档 |

每个 FPGA Backend 改动至少跑：

```text
Backend elaboration
XSim/行为模型 smoke（若维护）
Vivado synthesis
blackbox check
timing
board smoke
```

---

## 22. 旧工程资产如何参考

上一轮 `superScalar/fpga/` 中可参考：

| 旧资产 | 可保留机制 | 新位置 |
| --- | --- | --- |
| `create_vivado_project.tcl` | Tcl 重建工程 | Board `create_project.tcl` |
| `register_filelist_sources.tcl` | 从 filelist 注册源 | `fpga/common/tcl/read_rtl_filelist.tcl` |
| `run_synthesis.tcl` | 阶段化综合 | Board `synth.tcl` |
| `run_implementation.tcl` | 阶段化实现 | Board `impl.tcl` |
| `export_all_violating_paths.tcl` | 固定时序报告 | `fpga/common/tcl/reports.tcl` |
| `digital_twin.xdc` | 板级专用约束 | Board `constraints/` |
| 测试板工程 | 独立 Board 示例 | 新 Board 目录，不混入主目标 |

不直接继承：

- 旧 part、Package 和 pin；
- 旧 Top 名；
- 旧层次路径；
- 旧 BRAM 实例名；
- 旧时钟频率；
- 工程目录中的临时日志；
- 未经审查的 false path。

---

## 23. 推荐实施顺序

### 第一阶段：冻结 Board Facts

确认：

```text
part/package
输入时钟
reset 极性
UART pins
GPIO/LED
JTAG/program 方式
```

形成 `board.yaml` 和 Board README。

### 第二阶段：最小 `fpga_top`

只接：

```text
clock/reset
soc_core
Code/Data Memory Backend
UART TX
Test Status/LED
```

先完成 elaboration 和 synthesis。

### 第三阶段：约束和报告

完成：

```text
pins.xdc
clocks.xdc
cdc.xdc
固定报告
message gate
```

### 第四阶段：软件镜像

让同一个裸机 Smoke ELF 在 SoC Sim 和 FPGA 运行。

### 第五阶段：实现和上板

完成 timing/DRC/blackbox gate，生成 bitstream，跑 UART/Timer/GPIO Smoke。

### 第六阶段：RT-Thread

接入：

```text
Timer Tick
UART RX/TX
FinSH
长时间运行
```

### 第七阶段：CoreMark 与性能

冻结：

```text
时钟频率
编译参数
计时源
运行模式
报告格式
```

### 第八阶段：Debug 与 Release

增加可选 ILA/digital twin，建立 Release manifest 和归档流程。

---

## 24. 修改影响与必跑检查

### 修改 `fpga_top` 或 Board I/O

```text
elaboration
pin/port consistency
synthesis
DRC
board smoke
```

### 修改 Clock/Reset

```text
clock report
reset simulation
CDC
timing
first commit smoke
长时间 reset/restart
```

### 修改 Memory Backend

```text
byte write
read latency
image load
blackbox
BRAM utilization
SoC smoke
board software smoke
```

### 修改 XDC

```text
invalid/empty query
unconstrained paths
clock interaction
CDC
setup/hold
DRC
```

### 修改 Vivado/IP 版本

```text
clean rebuild
IP status
synthesis diff
utilization diff
timing diff
bitstream
full board smoke
```

### 修改软件镜像流程

```text
ELF range check
Sim image hash
FPGA image hash
boot
data/bss
stack/heap
```

---

## 25. 编码前的开放问题

1. 正式 Board 的 part、Package 和速度等级；
2. 输入时钟形式与频率；
3. 目标 `soc_clk`；
4. Code/Data BRAM 容量；
5. BRAM 对上层呈现 1 拍还是 2 拍读延迟；
6. 使用推断 BRAM 还是 Block Memory Generator；
7. MUL/DIV 使用通用 RTL 还是 Xilinx IP；
8. UART 与 digital twin 是否共用物理接口；
9. 是否存在第二时钟域；
10. ILA 的默认 Profile；
11. bitstream 是否支持快速 BRAM 镜像更新；
12. 固定 Vivado 版本；
13. timing/CDC/DRC 的 Release Gate；
14. 比赛交付要求的 bitstream、报告和命名。

暂定建议：

```text
Clock：
    SoC 第一版单时钟域

Reset：
    异步拉起、各域同步释放

Memory：
    Code/Data 独立，Native Port 冻结
    可见延迟以 FPGA 实际 Backend 为准

IP：
    Tcl 参数化生成，Wrapper 隔离

XDC：
    pins/clocks/cdc/debug 分开

Build：
    Board/Profile 独立目录

Debug：
    UART + 稳定 Probe 起步，ILA 按 Profile 启用

Release：
    timing、CDC、DRC、blackbox 全部过 Gate
```

---

## 26. 验收标准

### 结构

- [ ] `fpga_top` 只做平台集成；
- [ ] `soc_core` 不知道 Board 和 Xilinx IP；
- [ ] Board、Profile 和 Build Target 分开；
- [ ] 每个 Board 有独立 RTL、XDC、Tcl 和 README；
- [ ] 生成物全部进入 `build/vivado/`。

### Clock/Reset/CDC

- [ ] 输入和派生时钟都有明确约束；
- [ ] 功能 RTL 不用普通逻辑生成新时钟；
- [ ] 每个域同步释放复位；
- [ ] 每条 CDC 有明确同步结构；
- [ ] 没有用大范围 false path 掩盖 CDC；
- [ ] Clock Interaction 和 CDC 报告已审查。

### Backend/IP

- [ ] Memory/Arithmetic 使用稳定通用接口；
- [ ] IP 名只出现在 FPGA Wrapper；
- [ ] Verilator Model 与 FPGA Backend 可见行为一致；
- [ ] Data BRAM 支持 byte write；
- [ ] RAM 数组不全量 reset；
- [ ] IP 可由 Tcl 和参数重建；
- [ ] 没有 black box 或 locked IP。

### XDC/Tcl

- [ ] pin 与 `fpga_top` 端口一一对应；
- [ ] Tcl 可从干净目录重建工程；
- [ ] 各构建阶段返回可靠退出码；
- [ ] 空对象约束不会静默通过；
- [ ] 固定生成 timing/utilization/clock/CDC/DRC 报告；
- [ ] bitstream 只由通过 Gate 的 routed design 生成。

### 软件与上板

- [ ] SoC Sim 与 FPGA 使用同一 ELF/image manifest；
- [ ] 镜像范围经过检查；
- [ ] Board Smoke 覆盖 Clock/Reset/Memory/UART/Timer/GPIO；
- [ ] bitstream 与软件 hash 可追踪；
- [ ] RT-Thread 能稳定运行；
- [ ] Release 包包含必要报告和已知限制。

---

## 27. 各层一句话边界

```text
fpga_top：
    把 soc_core 接到具体板卡

board_clock_reset：
    把板卡时钟和复位变成 SoC 可用时钟域

board_io_wrapper：
    处理管脚、极性和物理接口

xilinx_*_backend：
    把通用功能接口映射到 Xilinx IP

XDC：
    描述物理引脚和时序关系

Vivado Tcl：
    从受控输入重建并执行工程

Board：
    描述器件和物理资源

Profile：
    描述本次构建使用的功能和软件

build/vivado：
    保存可删除、可追踪的实现产物
```

FPGA 侧冻结以下边界后，RTL、软件、仿真和上板可以独立推进：

```text
fpga_top 端口
+ Clock/Reset/CDC
+ Native Memory Port
+ Board/Profile
+ XDC Owner
+ Tcl 阶段与报告 Gate
+ 软件镜像 manifest
```
