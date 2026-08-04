# Software 侧结构与移植流程

> 适用项目：`SocRV` RV32 SoC、裸机程序、BSP、RT-Thread、FinSH、CoreMark、Verilator SoC 仿真与 FPGA。  
> 本文说明 `software/` 的目录、启动链、链接布局、Trap/中断、驱动、RT-Thread Port、应用和镜像边界。  
> 本轮实现已经冻结第一版 ISA/ABI、Memory Map、IRQ、时钟和软件可见寄存器合同；权威值位于 `data/soc/`，本文件后续章节仍保留架构原则与变更方法。

---

## 当前落地基线（2026-08）

本节记录已经实现并由构建/仿真验证的工程事实。后续章节中的“推荐”“待冻结”
表示通用设计要求；若与本节冲突，以受控 JSON、生成器和实际 Profile 为准。

### 唯一事实源与生成物

```text
data/soc/memory_map.json
data/soc/software_contract.json
        │
        └─ scripts/generate_soc_contract.py
             ├─ software/bsp/include/soc_memory_map.h
             ├─ software/bsp/include/soc_config.h
             ├─ software/bsp/include/soc_irq.h
             ├─ software/bsp/include/soc_registers.h
             └─ software/linker/memory.ldh
```

生成文件禁止手工维护。修改硬件合同后执行：

```text
make soc-contract
make check
make isa-data
make isa-regression
```

合同现在分为“当前实现”和“最终目标”两层。当前 demo core 仍为
RV32I + Zicsr、`ilp32`、Machine Mode，现有 smoke、RT-Thread 和 CoreMark
Profile 继续用 `-march=rv32i_zicsr -mabi=ilp32`，不得提前生成 M/F/D 指令。
最终 CPU 的整数基线为 RV32IM + Zicsr + Zicntr + Zifencei，必须通过
RV32UI、RV32MI、RV32UM；浮点在 F 与 FD 之间待选。这里的 RV32MI 是
riscv-tests 的 Machine Mode 测试套件，不是名为 “MI” 的 ISA 扩展。

当前 Memory Map 不因 ISA 扩展而改变：CODE 为 `0x0000_0000/64 KiB`，DATA 为
`0x1000_0000/64 KiB`；详细外设地址、寄存器访问属性、复位值和副作用均在
上述受控 JSON 中，不在本文重复复制。

### 固定上游依赖

三个第三方项目采用相同的 `dependency.lock.json + upstream/` 模式，
`upstream/` 不提交且不写入 SocRV 私有修改：

| Dependency | Locked revision | Project-owned adaptation |
| --- | --- | --- |
| RT-Thread | v5.2.2, `ddf52e2cdd977f14fc04035c88672ac204aec713` | `software/rt-thread/port/`、`rtconfig.h` |
| riscv-tests | `447a5fcb8253627ddb5f6a226f64e43463afcdd5` | `software/riscv-tests/env/socrv/`、`tests.json` |
| CoreMark | v1.01, `cfa9ab377835911f23d9b0831c7be302ed1f58de` | `software/coremark/port/` |

`make deps` clone/checkout，`make deps-check` 同时校验 commit、必需文件和
riscv-tests 的 `env` 子模块 revision。SocRV 不修改 `upstream/`。

### 已实现 Profile

| Profile | 用途 | 是否可报告正式分数 |
| --- | --- | --- |
| `smoke` | `.data/.bss`、UART、GPIO、Test Status | 不适用 |
| `trap-timer` | M-mode `ecall` 返回、完整 Trap Frame、Timer IRQ | 不适用 |
| `rtthread` | heap、scheduler、tick、FinSH/MSH、线程运行 | 不适用 |
| `coremark-smoke` | 裸机 CoreMark 短迭代与官方 CRC 功能门 | 否 |
| `coremark-baremetal` | FPGA 上正式裸机测量候选镜像 | 满足官方条件后才可 |
| `coremark-rtthread` | RT-Thread 集成与单独报告 | 不与裸机分数混用 |

所有 Profile 统一生成：

```text
build/software/<profile>/firmware.{elf,map,dis,bin}
build/software/<profile>/{size.json,build_manifest.json}
build/images/<profile>/{code.mem,data.mem,image.json}
```

### riscv-tests 与 `data/isa`

`data/isa` 不再从旧工程复制。`scripts/generate_isa_data.py` 使用锁定的官方
riscv-tests 源码、锁定的 `riscv-test-env` 子模块和 SocRV 自有 environment，
按当前 CODE/DATA Map 生成 86 个镜像：RV32UI 41 个、RV32MI 16 个、
RV32UM 8 个、RV32UF 11 个、RV32UD 10 个。`ma_data` 因合同允许 misaligned
访问 Trap 而排除；固定版本上游 Makefrag 本身排除 RV32UD `move`，选择文件
记录了两项原因。每个用例均保留 ELF、MAP、DIS、CODE/DATA MEM 与 hash
manifest。

```text
make isa-data
make isa-data-check
make isa-gates
make isa-regression             # 当前 demo gate
make sim-isa-final-base         # RV32UI + RV32MI + RV32UM
make sim-isa-fp-single          # F 候选
make sim-isa-fp-double          # FD 候选
make sim-isa-final              # 选定 F/FD 后启用
```

`final` gate 在 `data/soc/software_contract.json` 的浮点选择仍为 `pending`
时主动阻塞，防止把两个候选套件误当成已冻结需求。当前 demo gate 只运行其
已经实现的 RV32UI 子集；数据生成完整不等于 demo core 已支持最终 ISA。

历史数据仅可通过 `data-isa-legacy-*` 入口审计，不再是默认回归输入。

### ISA/ABI 决策级联

最终选择 F 或 FD 时，不能只改 GCC 的 `-march`。同一变更必须覆盖：

| 层 | RV32IM 基线 | 选择 F | 选择 FD |
| --- | --- | --- | --- |
| RTL | MDU、`misa.M`、完整 M-mode Trap/CSR、PMP0、`fence.i`、counter | 32×32-bit FP regfile、FPU、`misa.F`、`mstatus.FS`、`fflags/frm/fcsr` | 在 F 基础上支持 64-bit FP 数据路径并置 `misa.D` |
| 测试门 | RV32UI/RV32MI/RV32UM | 再加 RV32UF | 再加 RV32UD；D 蕴含 F |
| 编译 | `rv32im_zicsr_zicntr_zifencei` | `rv32imf_zicsr_zicntr_zifencei` | `rv32imfd_zicsr_zicntr_zifencei` |
| ABI | `ilp32` | 先用 `ilp32` 验证指令；对外 hard-float 可选 `ilp32f` | 先用 `ilp32` 验证指令；对外 hard-float 可选 `ilp32d` |
| RT-Thread | 保存整数 Trap Frame | 任务使用浮点后保存/恢复 F 状态 | 保存/恢复完整 D 状态 |

浮点上下文策略应在 eager save 与按 `mstatus.FS` lazy save 中明确选一种。
选择完成前，启动代码、RT-Thread context、printf 和 CoreMark 不依赖浮点；
CoreMark 仍是整数基准，不能用浮点扩展改变其验收含义。若 commit trace 用于
DiffTest，还要增加 FP 写回目标、数据和 FP CSR side effect，不能把它们塞进
现有整数 `rd` 字段。

### 与原规划的受控差异

- 内部构建 Owner 已选定为 Make，`software/profiles/*.mk` 负责源文件与 flags；
  没有并行维护 SCons/CMake。
- 轻量 freestanding 运行库使用 `runtime/minilibc.c` 与最小头文件，而不是
  引入 newlib；只实现固件和 FinSH 实际需要的符号。
- 统一镜像目录采用已有工程约定 `build/images/`（复数）。
- RT-Thread 复用上游 RISC-V context/trap 源，SocRV 只维护启动、Board/BSP
  适配；FinSH 符号表和组件初始化段由链接脚本显式 `KEEP`。
- CoreMark 短仿真仅验证参考 CRC。正式 `coremark-baremetal` 使用 50 MHz
  硬件 Timer、2000 iterations，并面向 FPGA 测量。

### 本轮验证记录

```text
make check                         PASS
make check-images                  6/6 PASS
smoke regression                  3/3 PASS
CoreMark functional regression    2/2 PASS，crcfinal = 0xe714
RV32UI demo gate regression       40/40 PASS
coremark-baremetal Vivado         timing met，DRC 0 error
```

正式 CoreMark bitstream 已生成并打入可校验 release 包。当前记录只证明软件、
镜像和 FPGA 构建路径可用；尚未在实体板上运行 2000 iterations，因此不记录
CoreMark 分数。

---

## 0. Software 侧的总体结构

复位后的软件路径：

```text
Reset Vector
    ↓
startup
    设置栈、初始化数据、清零 BSS、设置 mtvec
    ↓
bare-metal runtime / BSP
    UART、Timer、Trap、IRQ、GPIO
    ↓
RT-Thread Port（可选）
    上下文切换、临界区、Tick、Board Init
    ↓
application
    裸机测试、线程、FinSH 命令、CoreMark
```

仓库边界：

```text
software/  固件源码、移植层、应用、配置和链接脚本
rtl/       CPU、Memory Map、外设和 IRQ 的硬件实现
data/      测试输入、Profile、预构建镜像或可复用数据
scripts/   软件构建编排、ELF 检查、镜像转换
tb/        在仿真中加载并判断软件结果
fpga/      把同一镜像装入 FPGA Memory Backend
build/     ELF、MAP、DIS、HEX、MEM、日志和结果
```

软件不能通过仿真器宏走另一套功能路径。相同 ELF 应能在 `soc_sim_top` 和 `fpga_top` 对应系统上执行。

---

## 1. 推荐目录

在项目结构规划的 `software/` 基础上展开：

```text
software/
├─ README.md
├─ Makefile
│
├─ toolchain/
│  ├─ riscv_gcc.mk
│  └─ common_flags.mk
│
├─ startup/
│  ├─ start.S
│  ├─ crt0.c
│  └─ trap_entry.S
│
├─ linker/
│  ├─ socrv_code_data.ld
│  ├─ sections.ldh
│  └─ memory.ldh
│
├─ bsp/
│  ├─ include/
│  │  ├─ soc.h
│  │  ├─ soc_memory_map.h
│  │  ├─ soc_irq.h
│  │  ├─ board.h
│  │  ├─ drv_uart.h
│  │  ├─ drv_timer.h
│  │  ├─ drv_irq.h
│  │  └─ drv_gpio.h
│  ├─ board/
│  │  └─ board.c
│  ├─ trap/
│  │  ├─ trap.c
│  │  └─ trap_frame.h
│  └─ drivers/
│     ├─ drv_uart.c
│     ├─ drv_timer.c
│     ├─ drv_irq.c
│     └─ drv_gpio.c
│
├─ runtime/
│  ├─ syscalls.c
│  ├─ mini_printf.c
│  ├─ memory.c
│  └─ assert.c
│
├─ baremetal/
│  ├─ common/
│  └─ tests/
│     ├─ hello/
│     ├─ memory/
│     ├─ trap/
│     ├─ timer_irq/
│     ├─ uart/
│     └─ gpio/
│
├─ rt-thread/
│  ├─ upstream/
│  ├─ port/
│  │  ├─ cpuport.c
│  │  ├─ cpuport.h
│  │  ├─ context_gcc.S
│  │  └─ interrupt.c
│  ├─ board/
│  │  ├─ board.c
│  │  ├─ Kconfig
│  │  ├─ SConscript
│  │  └─ rtconfig.h
│  └─ README.md
│
├─ applications/
│  ├─ baremetal/
│  └─ rtthread/
│     ├─ main.c
│     ├─ commands/
│     └─ tests/
│
├─ coremark/
│  ├─ upstream/
│  ├─ port/
│  │  ├─ baremetal/
│  │  └─ rtthread/
│  └─ README.md
│
└─ profiles/
   ├─ hello.yaml
   ├─ timer_irq.yaml
   ├─ rtthread.yaml
   └─ coremark.yaml

build/software/<profile>/
├─ firmware.elf
├─ firmware.map
├─ firmware.dis
├─ firmware.bin
├─ size.json
├─ build_manifest.json
└─ objects/

build/images/<profile>/
├─ code.mem
├─ data.mem
├─ image.json
└─ image_report.txt
```

具体构建系统可以使用 Make、SCons 或 CMake，但顶层事实和产物格式保持一致。第一阶段不要同时维护三套等价构建入口。

---

## 2. 各层依赖

```text
applications
    ↓
RT-Thread API 或 bare-metal runtime
    ↓
BSP
    ↓
soc.h / Memory Map / IRQ / MMIO
    ↓
RTL 硬件契约
```

允许：

```text
CoreMark Port → BSP Timer/UART
RT-Thread Board → BSP Driver
Bare-metal Test → BSP
startup → linker symbols
```

禁止：

```text
BSP → 某个 Application
BSP → Verilator API
RT-Thread upstream → SocRV 私有寄存器
Application → RTL 层次路径
Driver → build/ 中临时生成头文件但无权威来源
```

上游开源源码与本项目 Port 分开，减少升级时的冲突。

---

## 3. 软件与硬件的权威合同

Software 侧依赖五类硬件事实：

```text
CPU ISA/ABI
Memory Map
Peripheral Register Map
Interrupt Map
Clock/Timer Frequency
```

这些事实必须在硬件文档、RTL package 和软件头文件之间一致。

### 3.1 推荐单一来源

第一阶段可以人工同步，但必须有自动检查：

```text
docs/memory_map
rtl/common/pkg/memory_map_pkg.sv
software/bsp/include/soc_memory_map.h
software/linker/memory.ldh
```

后续可用结构化 manifest 生成 SV/C/LD 片段。生成器只是分发工具，权威值仍需要评审。

### 3.2 变更级联

Memory Map 变化时同时更新：

- RTL decoder/package；
- 软件 `soc_memory_map.h`；
- 链接脚本；
- BSP driver base；
- TB/Sim image loader；
- FPGA BRAM Profile；
- 文档和测试。

IRQ 变化时同时更新：

- RTL interrupt route；
- `soc_irq.h`；
- Trap dispatch；
- RT-Thread BSP；
- 中断测试。

时钟变化时同时更新：

- FPGA Clock；
- Timer frequency 参数；
- BSP Tick 计算；
- UART divisor；
- CoreMark 计时；
- manifest。

---

## 4. CPU 能力与工具链

### 4.1 CPU Capability 表

软件构建前冻结：

| Item | Value |
| --- | --- |
| XLEN | 32 |
| Privilege | Machine Mode 范围待冻结 |
| ISA | RV32I + 已实现扩展 |
| `-march` | 根据 RTL 冻结 |
| ABI | 根据乘除/浮点能力冻结 |
| Misaligned | 硬件/软件策略待冻结 |
| Atomic | 是否实现待冻结 |
| Compressed | 是否实现待冻结 |

编译参数不能比硬件能力更强。未实现 `M/A/C/F/D` 时，不在 `-march` 中声明。

### 4.2 工具链

记录：

```text
riscv*-unknown-elf-gcc
binutils
objcopy
objdump
size
版本
```

Release 保存工具链版本和完整 flags。

### 4.3 公共 flags

典型方向：

```text
-march=<frozen ISA>
-mabi=<frozen ABI>
-ffreestanding
-fno-builtin（按 runtime 能力）
-nostartfiles
-Wall -Wextra
-ffunction-sections
-fdata-sections
```

链接可使用 `--gc-sections`，但启动入口、中断向量和必要初始化段必须 `KEEP()`。

### 4.4 Debug 与 Release

```text
debug
    -Og/-O0、符号、额外断言

release
    受控优化级别、保留必要符号和 map

coremark
    独立、公开、可复现的优化参数
```

性能 Profile 不覆盖功能回归的 Debug Profile。

---

## 5. 启动流程

复位后：

```text
PC = Reset Vector
→ _start
→ 设置 gp（若工具链/模型需要）
→ 设置 sp
→ 暂时关闭或屏蔽中断
→ 设置 mtvec
→ 复制 .data
→ 清零 .bss
→ 初始化 runtime
→ board_init
→ main 或 rtthread_startup
```

### 5.1 `start.S`

负责最早期、必须用汇编表达的动作：

- 建立 `sp`；
- 必要时建立 `gp`；
- 清理关键 CSR；
- 安装初始 Trap Entry；
- 跳到 C 初始化。

不在 `start.S` 中实现完整 UART Driver 或应用逻辑。

### 5.2 `crt0.c`

适合处理：

- `.data` copy；
- `.bss` zero；
- 构造器（若支持）；
- runtime 初始化；
- 调用 `main()`；
- `main()` 返回后的受控结束。

如果全部放在 `start.S`，仍要保持职责清晰并有启动测试。

### 5.3 初始中断状态

启动早期应明确：

```text
mstatus.MIE
mie
mip 可写/只读语义
mtvec
mscratch
```

在栈、Trap Entry 和 BSP 未准备好前不开放中断。

---

## 6. 链接脚本

链接脚本是硬件与软件的地址合同。

### 6.1 `MEMORY`

定义：

```text
CODE
DATA
```

基地址和容量来自 Memory Map，不在不同 Profile 的 `.ld` 中随意复制修改。

### 6.2 Section

至少明确：

```text
.vectors/.init
.text
.rodata
.data
.sdata
.bss
.sbss
.heap
.stack
```

并导出：

```text
__data_load_start
__data_start
__data_end
__bss_start
__bss_end
__heap_start
__heap_end
__stack_bottom
__stack_top
__image_end
```

### 6.3 `.rodata`

`.rodata` 放 Code Memory 或 Data Memory 必须冻结。若放 Code：

- D-side 必须能读取 Code 区；
- Linker 的 VMA/LMA 与镜像转换一致；
- Cache 属性正确。

若放 Data：

- Code/Data 镜像生成要包含对应段；
- Data BRAM 容量要覆盖。

### 6.4 VMA 与 LMA

双镜像系统要明确：

```text
VMA：运行时地址
LMA：初始化数据在镜像中的存放地址
```

`crt0` 使用 linker symbol 完成 copy，不硬编码长度。

### 6.5 栈与堆

链接时报错或构建检查必须捕获：

- image 超出 Code；
- data/bss/heap/stack 互相覆盖；
- 栈空间为零；
- `_end` 超出 Data；
- 未对齐 section。

---

## 7. `soc.h` 与 MMIO 访问

### 7.1 内容

`soc.h`/相关头文件只描述公开硬件合同：

```text
base address
register offset
bit mask
IRQ number
clock frequency
MMIO helper
```

不暴露 RTL 实例名。

### 7.2 MMIO Helper

```c
static inline uint32_t mmio_read32(uintptr_t addr);
static inline void mmio_write32(uintptr_t addr, uint32_t value);
```

使用 `volatile`，并按 CPU/总线顺序语义决定是否需要 fence。不能用普通指针访问代替全部 MMIO 语义。

### 7.3 Register Definition

每个寄存器文档和头文件要明确：

```text
offset
width
access: RO/RW/WO/W1C
reset value
reserved bits
side effect
IRQ clear rule
```

软件不得依赖 reserved bit 的读值。

---

## 8. Trap 与 Context

### 8.1 Trap Frame

至少保存软件可能被异步打断时需要恢复的全部整数状态：

```text
x1..x31（按 ABI/实现组织）
mepc
mstatus
mcause
mtval（若实现）
必要的 mscratch
```

Trap Frame 的 C struct 与汇编 offset 必须来自同一组定义或有静态检查。

### 8.2 Trap Entry

典型路径：

```text
硬件写入 CSR
→ mtvec
→ 保存上下文
→ 读取 mcause
→ dispatch exception/interrupt
→ 更新 mepc/设备状态
→ 恢复上下文
→ mret
```

### 8.3 Exception 与 Interrupt

区分：

```text
mcause interrupt bit
exception code
timer interrupt
external interrupt
software interrupt
```

不能仅按低位 cause 编号判断，忽略最高位。

### 8.4 嵌套

第一版推荐 Trap Handler 默认不允许任意嵌套。若以后启用嵌套，需冻结：

- 优先级；
- 栈策略；
- `mstatus` 保存恢复；
- 外设 pending/claim/complete；
- RT-Thread 临界区关系。

---

## 9. BSP 的职责

BSP 向上提供：

```text
board_init
console put/get
timer init/read/compare
irq install/enable/disable
GPIO
trap dispatch
```

向下依赖：

```text
Memory Map
Register Map
IRQ Map
Timer/UART Clock
CPU CSR 语义
```

BSP 不包含应用线程和 CoreMark 算法。

### 9.1 `board.c`

负责初始化顺序：

```text
early console
clock facts
trap
timer
irq
device registration
late console/RT-Thread board init
```

如果硬件时钟已由 FPGA 固定，BSP 只读取/使用事实，不假装配置不存在的 PLL 寄存器。

### 9.2 Early Console

早期启动阶段优先提供最小轮询 TX：

```text
uart_early_putc
```

它不依赖 RT-Thread Device Framework，便于定位 `_start` 到 Scheduler 之前的问题。

---

## 10. UART Driver

分阶段：

```text
阶段 1：轮询 TX
阶段 2：轮询 RX
阶段 3：RT-Thread Console
阶段 4：RX/TX IRQ 和 Ring Buffer（需要时）
```

### 10.1 配置

冻结：

- 输入时钟；
- baud divisor 公式；
- 数据位、停止位、校验；
- FIFO 深度；
- status bit；
- IRQ 条件和清除方式。

### 10.2 Driver 边界

Driver 负责寄存器访问、等待和中断搬运。应用不直接轮询 UART 寄存器。

### 10.3 测试

```text
单字符 TX
字符串 TX
RX
连续收发
FIFO 满/空
IRQ
RT-Thread Console
FinSH
```

SoC Sim 与 FPGA 的 UART 字节语义保持一致。

---

## 11. Machine Timer 与 Tick

### 11.1 BSP 接口

推荐：

```text
uint64_t timer_read(void);
void timer_set_compare(uint64_t deadline);
void timer_init_tick(uint32_t tick_hz);
```

### 11.2 RV32 访问 64 位寄存器

读取 `mtime` 使用防撕裂序列：

```text
hi1
lo
hi2
若 hi1 != hi2 则重读
```

写 `mtimecmp` 使用硬件合同规定的安全顺序，避免写入中间值时误触发。

### 11.3 Tick

```text
tick_delta = timer_frequency / RT_TICK_PER_SECOND
next_deadline += tick_delta
```

优先基于上次 deadline 累加，减少 ISR 延迟造成的长期漂移。整除误差需在频率冻结后评审。

### 11.4 Timer ISR

顺序：

```text
更新下一次 compare
→ 通知 RT-Thread Tick
→ 处理需要的调度标记
→ 退出 Trap
```

Timer IRQ 是电平语义时，必须先把 `mtimecmp` 推到未来，不能只清一个不存在的 pulse pending 位。

---

## 12. External IRQ

第一版可从 UART 直连 external IRQ 起步，但软件接口预留：

```text
irq_install
irq_mask
irq_unmask
irq_ack/complete
```

如果加入 Interrupt Controller，需要冻结：

- IRQ 编号；
- level/edge；
- pending；
- enable/mask；
- priority；
- claim/complete；
- clear mechanism。

Timer IRQ 不混入 External IRQ Controller 的普通源编号。

---

## 13. GPIO

Driver 提供：

```text
direction
read
write
set/clear
optional irq
```

Board 引脚和 LED 极性由 FPGA Board Wrapper 处理；BSP 面向逻辑 GPIO 语义。应用不为某块板卡重复取反。

---

## 14. Bare-metal Runtime

最小 runtime 提供：

```text
memcpy/memset（需要时）
mini printf
assert/panic
exit/test status
有限 syscall stub
```

### 14.1 `printf`

早期使用轻量实现，避免无意引入：

- 浮点格式；
- 大型 locale；
- heap；
- 不支持 syscall。

CoreMark 输出格式需要的整数/可选浮点能力单独评估。

### 14.2 `exit`

裸机没有宿主进程。`exit()` 映射到明确协议：

```text
写 Test Status/tohost
→ 可选打印结果
→ 进入 WFI/安全循环
```

PASS 和 FAIL 编码必须写入文档，并由 TB/Sim 与 FPGA 自动化共同使用。

### 14.3 Panic

Panic 输出：

```text
reason
mcause/mepc/mtval
可选寄存器摘要
FAIL status
```

不能只进入无限循环而没有可观察标记。

---

## 15. Bare-metal Tests

建议顺序：

```text
hello
data_bss
stack_call
load_store
illegal_instruction
ecall
timer_read
timer_irq
uart_rx_tx
external_irq
gpio
```

每个测试：

- 一个明确目标；
- 固定结束协议；
- 小镜像；
- 独立 Profile；
- SoC Sim 先通过；
- 对应硬件成熟后上板。

Bare-metal Test 是 BSP/硬件合同的最短验证路径，不由 RT-Thread 测试替代。

---

## 16. RT-Thread 源码与 Port

### 16.1 Upstream

`software/rt-thread/upstream/` 保存：

- Git submodule；
- 固定版本 vendor；
- 或受控外部依赖。

不在 Upstream 中散改 SocRV 寄存器和 Board 代码。

### 16.2 CPU Port

Port 负责：

```text
线程初始栈
上下文切换
中断进入/退出
临界区
必要 CSR
```

CPU Port 与 SocRV BSP 分开：可复用的 RV32 Machine Mode 上下文逻辑放 Port，具体 UART/Timer 地址放 Board/BSP。

### 16.3 Board Port

负责：

```text
rt_hw_board_init
Console Device
Tick Timer
Heap range
Device registration
rtconfig
```

### 16.4 Context Switch

至少验证：

```text
首次启动线程
主动 yield
阻塞后切换
Tick 抢占
中断退出切换
callee/caller saved registers
栈对齐
```

### 16.5 临界区

临界区保存并恢复原中断状态，不能简单地：

```text
disable
...
always enable
```

否则嵌套临界区会破坏上层状态。

---

## 17. RT-Thread 启动

推荐路径：

```text
_start
→ C runtime
→ rtthread_startup
→ board init
→ timer/console
→ scheduler
→ main thread
→ application main
```

必须明确项目采用 RT-Thread 哪一种入口方式，避免裸机 `main()`、RT-Thread `main()` 和 CoreMark `main()` 同时链接。

### 17.1 Heap

Heap 起止来自链接符号：

```text
__heap_start
__heap_end
```

Board Init 检查范围与栈不重叠。内存紧张时优先建立静态配置基线。

### 17.2 Tick

确认：

```text
RT_TICK_PER_SECOND
timer_frequency
tick_delta
mtimecmp 安全写
MTIE/MIE
Trap dispatch
rt_tick_increase
```

### 17.3 Console

Console 建立两阶段：

```text
early polling UART
→ RT-Thread device/console
```

切换后避免两个输出层同时无序访问 UART。

---

## 18. FinSH/MSH 与应用

应用目录负责：

- 线程；
- IPC；
- FinSH 命令；
- 演示；
- 系统测试；
- CoreMark 命令入口。

不负责：

- 保存 Trap Frame；
- 直接配置 `mtimecmp`；
- 维护 UART FIFO；
- 重复定义 Memory Map。

### 18.1 命令组织

```text
applications/rtthread/commands/
├─ cmd_info.c
├─ cmd_timer.c
├─ cmd_memory.c
└─ cmd_coremark.c
```

命令有受控参数、错误返回和栈预算。不要把大数组放入 FinSH 线程栈。

### 18.2 应用资源表

维护：

```text
线程名
优先级
栈大小
时间片
IPC 对象
共享资源
启动条件
```

避免所有线程使用随意优先级和默认大栈。

---

## 19. CoreMark

### 19.1 Upstream 与 Port

```text
coremark/upstream/
    官方源码，尽量不修改

coremark/port/baremetal/
    Timer、输出、内存、seed

coremark/port/rtthread/
    MSH 入口、RT-Thread Timer/输出
```

### 19.2 两种运行方式

```text
bare-metal
    系统干扰少，适合正式 CPU/SoC 性能

RT-Thread command
    适合演示和系统集成
```

两者结果分开报告，不能直接混为同一基准。

### 19.3 计时

计时源必须：

- 单调；
- 频率已知；
- 足够宽；
- 不受 UART 输出阻塞影响；
- 在 Sim/FPGA 语义一致。

### 19.4 正确性

正式结果保留：

```text
seed
iterations
CRC
run time
clock frequency
compiler/version
flags
CoreMark version
memory mode
RTOS mode
```

先检查 CRC 和官方有效性条件，再记录分数。

---

## 20. Software Profile

Profile 描述一次固件构建：

```yaml
name: rtthread
entry: rtthread
march: <frozen>
mabi: <frozen>
optimization: Os
linker: software/linker/socrv_code_data.ld
features:
  console: true
  timer_tick: true
  finsh: true
  coremark: false
```

实际 schema 可调整，目标是避免 Makefile 中散落：

```text
某个应用的源文件
特殊宏
镜像名
链接脚本
期望内存大小
```

推荐 Profile：

```text
hello
data_bss
timer_irq
rtthread
coremark_baremetal
coremark_rtthread
```

---

## 21. 构建产物

每个 Profile 独立：

```text
firmware.elf
    调试和镜像转换的权威产物

firmware.map
    section/symbol/链接分析

firmware.dis
    指令和启动排查

firmware.bin
    可选连续二进制

size.json
    section 和 Memory 使用

build_manifest.json
    工具链、flags、sources、git、profile
```

ELF 必须保留，不能只交 HEX/MEM。

### 21.1 构建检查

链接完成后自动检查：

- Entry；
- ISA attributes；
- Code/Data 范围；
- `.data/.bss`；
- stack/heap；
- 未解析 syscall；
- 意外大 section；
- 重复 `main`；
- 禁止的浮点/原子/压缩指令；
- 镜像是否超出硬件容量。

---

## 22. ELF 到镜像

统一路径：

```text
firmware.elf
→ scripts/elf2mem.py
→ code.mem
→ data.mem
→ image.json
```

### 22.1 `image.json`

至少包含：

```text
ELF path/hash
entry
ISA/ABI
Code base/size/file/hash
Data base/size/file/hash
segment mapping
tohost/Test Status
endianness
word format
```

### 22.2 转换规则

转换器按 ELF Program Header 和链接合同工作，不按 section 名或文件名猜测。

明确：

- little-endian；
- 每行位宽；
- 空洞填充值；
- Code/Data 分区；
- `.bss` 是否存入镜像；
- 未初始化 Data 的启动责任；
- 地址到 BRAM index 的转换。

### 22.3 消费者

同一 `image.json` 被：

```text
tb/cpp memory loader
tb/models memory model
fpga BRAM init
release packager
```

使用。

---

## 23. Sim 与 FPGA 的一致性

共享：

```text
ELF
image.json
Memory Map
Timer frequency
UART baud/format
Test Status
IRQ Map
```

允许差异：

```text
Sim
    可缩短某些测试等待，但必须由 Profile 明示

FPGA
    使用真实时钟和外设
```

软件不能使用：

```c
#ifdef VERILATOR
    修正一个硬件行为
#endif
```

可有受控的测试配置，例如缩短迭代次数，但结果 manifest 必须记录，正式性能 Profile 不使用仿真缩短参数。

---

## 24. 软件测试路线

### Stage 0：工具链

```text
最小汇编
ELF/objdump/readelf
ISA 检查
```

### Stage 1：启动

```text
Reset Vector
sp/gp
.data
.bss
function call
Test Status
```

### Stage 2：Console

```text
early UART TX
字符串
RX
```

### Stage 3：Trap

```text
ecall
illegal instruction
mepc/mcause/mtval
mret
```

### Stage 4：Timer/IRQ

```text
mtime read
mtimecmp
timer interrupt
external interrupt
```

### Stage 5：RT-Thread

```text
first thread
yield
tick
preemption
IPC
long run
```

### Stage 6：FinSH

```text
Console input
command
arguments
stack
concurrent output
```

### Stage 7：CoreMark

```text
CRC
iteration/time
bare-metal
RT-Thread
FPGA formal run
```

每个 Stage 先在 SoC Sim 通过，再进入 FPGA 对应 Smoke。

---

## 25. Debug 分层

### 无取指

检查：

```text
Reset Vector
Code image
entry
BRAM init
clock/reset
```

### 到 `_start`，不到 C

检查：

```text
sp/gp
链接地址
.data copy
.bss clear
illegal instruction
```

### 到 `main`，无 UART

检查：

```text
UART base
clock/divisor
status bit
pin/host
```

### Trap 后不返回

检查：

```text
mtvec alignment
Trap Frame offset
mcause high bit
mepc update
mstatus
stack
```

### Timer 不工作

检查：

```text
mtime
mtimecmp
MTIP
mie.MTIE
mstatus.MIE
ISR 更新 compare
```

### RT-Thread 首次切换崩溃

检查：

```text
初始线程栈
上下文布局
ABI
sp alignment
mstatus/mepc
```

### 仿真能跑、FPGA 不能跑

检查：

```text
镜像 hash
BRAM 延迟
Clock/Timer frequency
UART baud
未初始化内存
CDC/reset
```

---

## 26. 旧资料如何使用

`learn/` 中可作为知识参考：

```text
Application Layer
RT-Thread Layer
BSP Porting Layer
SoC/OS Porting Guide
CoreMark Guide
Machine Timer/Tick Guide
```

使用原则：

- 继承职责划分和验证顺序；
- 地址、频率、IRQ 和容量以新 SocRV 架构为准；
- RT-Thread API 与实际固定版本核对；
- 不把学习文档当编译源或唯一规格。

上一轮 `superScalar` 的软件镜像、测试 Profile 和 Runner 可参考机制，但不直接继承：

- 旧 Memory Map；
- 旧链接地址；
- 旧 Board 寄存器；
- 旧 Top/Test Status 层次；
- 已针对旧 CPU 扩展设置的 `-march`；
- 旧镜像拆分假设。

---

## 27. 推荐实施顺序

### 第一阶段：冻结合同

确认：

```text
ISA/ABI
Reset Vector
Code/Data Map
Register Map
IRQ Map
Timer frequency
Test Status
```

### 第二阶段：裸机启动

完成：

```text
startup
linker
runtime
data/bss
exit/status
```

### 第三阶段：BSP

按顺序：

```text
early UART
Trap
Timer
IRQ
GPIO
```

### 第四阶段：镜像合同

完成 ELF 检查、`elf2mem.py`、`image.json`，让 SoC Sim 和 FPGA 使用同一镜像。

### 第五阶段：RT-Thread Port

先跑首次线程和主动切换，再加 Tick/抢占、Heap、Device、FinSH。

### 第六阶段：应用

补线程、IPC、命令和系统测试，维护资源表。

### 第七阶段：CoreMark

先裸机正确性与计时，再接 RT-Thread 命令，最后做 FPGA 正式结果。

### 第八阶段：Release

保存 ELF/MAP/DIS、工具链、flags、镜像 hash、测试结果和已知限制。

---

## 28. 开放问题

1. 最终 `-march/-mabi`；
2. Reset Vector；
3. Code/Data 基地址和容量；
4. `.rodata` 位置；
5. Stack/Heap 大小；
6. Misaligned 策略；
7. Test Status/tohost 地址与编码；
8. Machine Timer 地址和频率；
9. Timer IRQ、External IRQ 的完整编号与清除方式；
10. UART Register Map、时钟和 baud；
11. RT-Thread 固定版本与依赖方式；
12. RT-Thread Tick 频率；
13. 上下文是否需要保存扩展状态；
14. CoreMark 计时源和正式编译 flags；
15. 构建系统使用 Make 还是 SCons 作为内部 Owner；
16. 软件 Profile schema；
17. C/SV/LD Memory Map 是否由结构化源生成。

暂定建议：

```text
Privilege：
    第一版 Machine Mode

Startup：
    显式初始化 sp/data/bss/mtvec

Linker：
    Code/Data 双区，范围自动检查

BSP：
    early UART → Trap → Timer → IRQ

RT-Thread：
    Upstream、CPU Port、Board Port 分开

Test：
    明确 Test Status，不能靠死循环猜结果

Image：
    ELF 为权威，同一 image.json 服务 Sim/FPGA

CoreMark：
    裸机正式性能，RT-Thread 模式单独报告
```

---

## 29. 验收标准

### 合同

- [ ] ISA/ABI 与 CPU 实现一致；
- [ ] Memory Map 在 RTL、C Header、Linker 和 Loader 中一致；
- [ ] 每个寄存器有 offset、访问类型、复位值和副作用；
- [ ] IRQ 编号、触发和清除方式明确；
- [ ] Timer/UART Clock 有唯一事实来源。

### Startup/Linker

- [ ] Reset Vector 正确；
- [ ] `sp/gp` 初始化正确；
- [ ] `.data` copy、`.bss` zero 通过测试；
- [ ] Trap Entry 在开放中断前安装；
- [ ] Code/Data/Heap/Stack 无重叠；
- [ ] image 越界使构建失败；
- [ ] ELF/MAP/DIS 保留。

### BSP

- [ ] Early UART 可在 RT-Thread 前工作；
- [ ] Exception/Interrupt 能保存恢复上下文；
- [ ] RV32 安全访问 64 位 Timer；
- [ ] Tick 不长期漂移；
- [ ] External IRQ 流程明确；
- [ ] Driver 不依赖应用和仿真器。

### RT-Thread

- [ ] Upstream 与项目 Port 分开；
- [ ] 初始线程、yield、阻塞、Tick、抢占通过；
- [ ] 临界区恢复原中断状态；
- [ ] Heap 来自链接符号且不碰栈；
- [ ] Console/FinSH 稳定；
- [ ] 长时间运行无栈溢出和 Tick 丢失。

### 应用/CoreMark

- [ ] 应用不直接重复实现 Driver；
- [ ] 线程资源表完整；
- [ ] FinSH 命令有参数和栈检查；
- [ ] CoreMark Upstream 与 Port 分开；
- [ ] CRC、时间、工具链和 flags 可追踪；
- [ ] 裸机与 RT-Thread 结果分开报告。

### 构建与镜像

- [ ] 每个 Profile 使用独立目录；
- [ ] Build Manifest 记录工具链、flags 和 Git 状态；
- [ ] ELF 到 Code/Data 镜像只有一套权威转换；
- [ ] `image.json` 包含地址、格式和 hash；
- [ ] SoC Sim 与 FPGA 使用同一 ELF；
- [ ] PASS/FAIL/TIMEOUT 有明确协议。

---

## 30. 各层一句话边界

```text
startup：
    把复位后的 CPU 带到可运行 C 的状态

linker：
    决定每段软件位于哪块硬件存储

runtime：
    提供裸机 C 程序最小运行环境

BSP：
    把公开 SoC 寄存器变成稳定软件接口

trap_entry：
    保存现场并进入 C/RTOS 的事件处理

RT-Thread CPU Port：
    实现上下文和临界区

RT-Thread Board Port：
    接入 Timer、Console、Heap 和 Device

application：
    组织线程、命令和业务

CoreMark Port：
    提供计时、输出、内存和运行入口

Software Profile：
    固定一次固件构建的源、配置和用途

image.json：
    让 Sim 与 FPGA 对同一 ELF 使用同一种解释
```

Software 侧优先冻结：

```text
ISA/ABI
+ Memory/IRQ/Register Map
+ Startup/Linker
+ Trap Frame
+ BSP Driver API
+ RT-Thread Port 边界
+ Test Status
+ ELF/Image 合同
```
