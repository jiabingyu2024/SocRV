# SocRv 软件部分介绍（修改与引用）

- 日期：2026-08-13
- 范围：`software/` 下全部文件，以及与之强相关的 `data/soc/`（硬件/软件合同）、顶层 `Makefile`（构建入口）、`fpga/`（LED 点亮通路）
- 目的：说明软件侧到底**改了哪些文件、引用了哪些上游、哪些保持原样**，并给出核心数据流与调用链，作为后续点灯与 CoreMark/RT-Thread 审查的基础。

> 结论先行：
> - **CoreMark 只改了 `port/` 适配层**，核心算法文件（`core_main.c` / `core_list_join.c` / `core_matrix.c` / `core_state.c` / `core_util.c` / `coremark.h`）全部从 EEMBC 上游 v1.01 **原样拉取**，未做任何改动。
> - **RT-Thread 只改了 `rt-thread/port/`**，内核源码从 RT-Thread v5.2.2 上游 **原样拉取**，未改动。
> - 硬件/软件的地址与寄存器定义由 `data/soc/*.json` 唯一权威生成（`make soc-contract`），生成的头文件/链接脚本**禁止手改**。

---

## 1. 目录结构与职责

```
software/
├── Makefile                     # 软件编译入口（gcc 编译 + 链接 + 生成 bin/dis/map）
├── README.md                    # 软件总览（profile 表、构建命令）
├── startup/                     # 裸机启动：start.S / crt0.c / trap_entry.S
├── linker/                      # 链接脚本与内存布局（memory.ldh / socrv_code_data.ld）
├── bsp/                         # 板级支持包（board / drivers / include / trap）
│   ├── board/board.c            #   裸机 board_init
│   ├── drivers/                 #   drv_uart / drv_timer / drv_irq / drv_gpio / test_status
│   ├── include/                 #   由合同生成的头 + 手写驱动头
│   └── trap/trap.c              #   裸机 trap 处理（中断/ECALL 分发）
├── rt-thread/                   # RT-Thread port（上游源码在 gitignore 的 upstream/）
│   ├── port/                    #   start_rtthread.S / trap_gcc.S / interrupt_gcc.S /
│   │                            #   context_gcc.S / cpuport.c/h / rtconfig.h / board.c /
│   │                            #   rtthread_crt0.c / rt_hw_stack_frame.h
│   └── dependency.lock.json     #   上游版本/提交锁定
├── coremark/                    # CoreMark port（上游源码在 gitignore 的 upstream/）
│   ├── port/common/             #   core_portme.c/h / ee_printf.c / cvt.c（共享适配）
│   ├── port/baremetal/main.c    #   裸机 CoreMark main
│   ├── port/rtthread/command.c  #   RT-Thread `coremark` 命令
│   └── dependency.lock.json     #   上游版本/提交锁定
├── applications/                # 应用与命令
│   ├── baremetal/               #   smoke / trap-timer 两个裸机测试
│   └── rtthread/                #   main.c / shell_main.c / commands/cmd_info.c
├── profiles/                    # 每个构建 profile 的源文件清单与编译宏
│   ├── *.inc                    #   源文件 / include / flags 片段
│   └── *.mk                     #   具体 profile 定义
├── runtime/                     # 最小 libc（minilibc.c / platform.c / include/*.h）
├── riscv-tests/                 # RISC-V ISA 测试清单（tests.json + env/socrv）
└── toolchain/                   # riscv_gcc.mk / common_flags.mk
```

---

## 2. 工具链与硬件/软件合同

**工具链合同**（`software/toolchain/`、`software/README.md`）：

```text
-march=rv32imf_zicsr
-mabi=ilp32f
```

即：RV32IM + 单精度浮点（F）+ 原子指令用 CSR（Zicsr）；无 C 压缩、无 A 原子、无 D 双精度（见 §5）。

**硬件/软件合同**（权威来源，手改无效）：

| 文件 | 内容 |
| --- | --- |
| `data/soc/memory_map.json` | 地址映射（CODE/DATA/TIMER/UART/GPIO/SYSCTRL） |
| `data/soc/software_contract.json` | CPU/时钟/中断/外设寄存器/test_status 的权威定义 |

由 `make soc-contract`（`scripts/generate_soc_contract.py`）**生成**以下文件，均带 `/* Generated ... do not edit */`：

| 生成产物 | 内容 |
| --- | --- |
| `bsp/include/soc_config.h` | `SOCRV_MARCH/MABI`、各时钟 Hz、UART 波特率 |
| `bsp/include/soc_memory_map.h` | 各外设基址与尺寸 |
| `bsp/include/soc_registers.h` | 各外设寄存器偏移、复位值、magic 常量 |
| `bsp/include/soc_irq.h` | 中断 cause 号与 `mie` 掩码 |
| `linker/memory.ldh` | CODE/DATA 起始与长度（供链接脚本 INCLUDE） |

> 改硬件/寄存器/地址后，应改 `data/soc/*.json` 再跑 `make soc-contract`，不要手改生成文件。

---

## 3. 内存布局与启动流程

### 3.1 内存布局（`linker/memory.ldh` + `socrv_code_data.ld`）

| 区域 | 基址 | 大小 | 用途 |
| --- | --- | --- | --- |
| CODE（ICCM） | `0x0000_0000` | 128 KiB | 指令（`.text`），仅接取指通路 |
| DATA（DCCM） | `0x0002_0000` | 64 KiB | `.rodata/.data/.bss/堆/栈` |

关键约束（链接脚本注释明确写了）：
- **ICCM 只连取指**，CPU 经 LSU 读不到 ICCM。因此字符串字面量、RT-Thread 的 `FSymTab`/`.rti_fn.*` 链接表等**只读数据必须放进 DCCM 的 `.rodata`**。
- 栈顶 = `DATA_ORIGIN + DATA_LENGTH = 0x30000`，栈 8 KiB，堆位于 `__heap_start`（镜像末尾）到 `__heap_end`（栈底）之间。
- `ASSERT` 检查 CODE 溢出、堆/栈重叠、栈顶 16 字节对齐。

### 3.2 裸机启动（`startup/`）

```
_start (start.S)
  ├─ 关 MIE、清 mie/mscratch，设 mstatus.FS=Initial（硬浮点安全）
  ├─ 设 gp、sp=__stack_top，mtvec=trap_entry
  └─ call crt0 (crt0.c)
        ├─ crt_init_memory(): 拷贝 .data、清零 .bss
        ├─ board_init():      uart_init + irq_controller_init + timer_start
        └─ platform_exit(main())
```

### 3.3 RT-Thread 启动（`rt-thread/port/`）

```
_start (start_rtthread.S)
  ├─ 关 MIE、清 mie/mscratch，设 mstatus.FS=Initial
  ├─ 设 gp、sp=__stack_top，mtvec=SW_handler
  └─ call rtthread_crt0 (rtthread_crt0.c)
        ├─ crt_init_memory()
        └─ rtthread_startup()   ← RT-Thread 内核入口（上游）
              ├─ rt_hw_board_init()  (port/board.c)
              │     ├─ uart_init / irq_controller_init / heap init
              │     ├─ rt_hw_interrupt_install(cause 7, timer_irq)
              │     └─ timer_init_tick(100Hz) + 开 timer 中断
              ├─ components 初始化（FinSH/MSH 等）
              └─ main 线程（RT_USING_USER_MAIN → applications/rtthread/main.c）
```

---

## 4. CoreMark 集成（回答“是否只改了 portme”）

### 4.1 上游来源

`software/coremark/dependency.lock.json`：

```json
{
  "url": "https://github.com/eembc/coremark.git",
  "ref": "v1.01",
  "commit": "cfa9ab377835911f23d9b0831c7be302ed1f58de",
  "required_paths": [
    "core_list_join.c", "core_main.c", "core_matrix.c",
    "core_state.c", "core_util.c", "coremark.h", "LICENSE.md"
  ]
}
```

`make deps` 把这些**核心算法文件原样**拉取到被 `.gitignore` 的 `software/coremark/upstream/`，**不进入版本库、不做修改**。

### 4.2 关键技巧：`-Dmain=coremark_main`

`software/Makefile:46-48`：

```make
$(OUT)/objects/coremark/upstream/core_main.c.o: coremark/upstream/core_main.c
	$(CC) $(CFLAGS) $(INCLUDES) -Dmain=coremark_main -c $< -o $@
```

只对 `core_main.c` 用 `-Dmain=coremark_main` 把上游的 `main()` 重命名成 `coremark_main()`，从而把**整个 CoreMark 当作一个可调用函数**嵌入，而不是独立入口。这样：
- 裸机：`coremark/port/baremetal/main.c` 的 `main()` 里 `coremark_main()`；
- RT-Thread：`coremark/port/rtthread/command.c` 的 `cmd_coremark()` 里 `coremark_main()`。

### 4.3 本工程自定义的 port 文件（唯一改动点）

| 文件 | 职责 |
| --- | --- |
| `port/common/core_portme.h` | 类型定义、`SEED_METHOD=SEED_VOLATILE`、`MEM_METHOD=MEM_STATIC`、`MULTITHREAD=1`、`COREMARK_TICKS_PER_SEC=50000000`、`HAS_FLOAT=1` 等 |
| `port/common/core_portme.c` | 计时三函数 + `portable_init/fini` + 结果码 |
| `port/common/ee_printf.c` | 极简 `ee_printf`（对接 UART） |
| `port/common/cvt.c` | 数值→字符串（上游自带，本工程保留） |
| `port/baremetal/main.c` | 裸机入口 `main()` |
| `port/rtthread/command.c` | FinSH `coremark [iterations]` 命令 |

**计时实现**（`core_portme.c`，是后续点灯的天然挂点）：

```c
void start_time(void) {
    saved_mstatus = irq_save();          // 关 MIE，避免 RT tick 打断计时
    irq_clear_software();
    timer_start(0);                      // 只开 mtime、关 timer IRQ
    test_status_set_code(SOCRV_TEST_PERF_START_MAGIC);  // 0x43504d53 "CPMS"
    start_ticks = timer_read();          // 读 50 MHz 外设 mtime
}
void stop_time(void) {
    stop_ticks = timer_read();
    test_status_set_code(SOCRV_TEST_PERF_STOP_MAGIC);   // 0x43504d45 "CPME"
}
CORE_TICKS get_time(void) { return stop_ticks - start_ticks; }
```

计时用 `timer_read()` 读**外设 `machine_timer`（50 MHz）**，`COREMARK_TICKS_PER_SEC = 50_000_000` 与之一致。

### 4.4 构建 profile

| Profile | 用途 | `COREMARK_ITERATIONS` | `COREMARK_TICKS_PER_SEC` |
| --- | --- | --- | --- |
| `coremark-smoke` | 快速功能冒烟（1 轮） | 1 | 1 |
| `coremark-baremetal` | 裸机计分候选 | 10000（可覆盖） | 50 MHz |
| `rtthread-coremark` | **最终板上固件**（RT-Thread + 命令） | 10000（运行时覆盖） | 50 MHz |

`rtthread-coremark.mk` 编译源 = RT-Thread 公共源 + CoreMark 源 + `applications/rtthread/shell_main.c` + `coremark/port/rtthread/command.c`。

---

## 5. RT-Thread 集成

### 5.1 上游来源

`software/rt-thread/dependency.lock.json`：RT-Thread **v5.2.2**，commit `ddf52e2cdd977f14fc04035c88672ac204aec713`。`make deps` 拉到 `software/rt-thread/upstream/`（gitignore），不改动。

### 5.2 本工程自定义的 port 文件

| 文件 | 职责 |
| --- | --- |
| `port/rtconfig.h` | nano 内核、small-mem heap、FinSH/MSH、`RT_TICK_PER_SECOND=100`、`RT_USING_USER_MAIN` |
| `port/start_rtthread.S` | 入口 `_start` |
| `port/rtthread_crt0.c` | `crt_init_memory()` + `rtthread_startup()` |
| `port/board.c` | `rt_hw_board_init` / `rt_hw_console_output` / `rt_hw_console_getchar` / `rt_trigger_software_interrupt` / timer 中断处理 |
| `port/cpuport.c/h` | 线程栈初始化、上下文切换请求 |
| `port/context_gcc.S` | 线程级上下文切换 |
| `port/interrupt_gcc.S` | 中断入口 `SW_handler` |
| `port/trap_gcc.S` | trap 入口 `trap_entry`（含 FPU 上下文保存） |
| `port/rt_hw_stack_frame.h` | 栈帧布局 |

### 5.3 中断与软件切换的关键设计（EH1 无 MSIP）

- EH1 只有 `timer_int`（cause 7）输入，**没有 MSIP**。因此 RT-Thread 的“抢占/上下文切换请求”复用 cause 7：
  - `cpuport.c` 的 `rt_hw_context_switch_interrupt()` 置 `rt_thread_switch_interrupt_flag` 后调用 `rt_trigger_software_interrupt()`；
  - `board.c` 的 `rt_trigger_software_interrupt()` 写 `SYSCTRL.SOFTWARE_IRQ=1`；
  - RTL 侧 `soc_top.sv` 把 `software_irq_sync_q` 与 `timer_irq_sync_q` **或**到 `timer_int`（cause 7）；
  - `board.c` 的 `timer_irq()` 里先用 `irq_pending()` 判断：是软件切换请求就 `irq_clear_software()` 返回；否则 `timer_schedule_next_tick()` + `rt_tick_increase()`。
- 软件中断位（`SYSCTRL.SOFTWARE_IRQ`）由 `drv_irq.c` 的 `irq_trigger_software()/irq_clear_software()/irq_pending()` 操作。

### 5.4 应用与命令

| 文件 | 职责 |
| --- | --- |
| `applications/rtthread/main.c` | `rtthread` profile 的 user main：起一个 `worker` 线程做调度冒烟并报 PASS |
| `applications/rtthread/shell_main.c` | `rtthread-coremark` profile 的 user main：进 MSH，等命令 |
| `applications/rtthread/commands/cmd_info.c` | `socrv_info` / `uptime` 命令 |
| `coremark/port/rtthread/command.c` | `coremark [iterations]` 命令（§4） |

---

## 6. BSP 驱动（`software/bsp/`）

| 驱动 | 头文件 | 关键函数 | 说明 |
| --- | --- | --- | --- |
| UART | `drv_uart.h` | `uart_init/putc/puts/getc/getc_nonblocking/flush` | 波特率分频由 `soc_peripheral_clock_hz()/BAUD` 运行时计算 |
| Timer | `drv_timer.h` | `timer_read/set_compare/disable_compare/start/init_tick/schedule_next_tick` | 读写 64 位 `mtime/mtimecmp`；`timer_init_tick` 按 50 MHz 外设时钟计算 tick 间隔 |
| IRQ | `drv_irq.h` | `irq_controller_init/irq_pending/irq_trigger_software/irq_clear_software` | 只实现软件中断位（cause 7 复用） |
| GPIO | `drv_gpio.h` | `gpio_set_output/gpio_write/gpio_read` | **LED 点灯入口**（见计划文档） |
| 状态 | `test_status.h` | `test_status_report_pass/fail` / `set_code` / `pass/fail(noreturn)` | 写 `SYSCTRL.STATUS/CODE`，驱动仿真结束与板上 PASS/FAIL LED |

`bsp/include/soc.h` 提供 `mmio_read32/mmio_write32`（volatile 指针）与 `irq_save/irq_restore`、`soc_clock_hz()`（运行时读 SYSCTRL，兼容 100/250 MHz 两种目标）等内联工具。

---

## 7. 构建系统与验证入口（顶层 `Makefile`）

| 目标 | 作用 |
| --- | --- |
| `make deps` / `deps-check` | 拉取/校验 CoreMark、RT-Thread、riscv-tests 上游 |
| `make soc-contract` / `soc-contract-check` | 生成/校验合同头文件与链接脚本 |
| `make software-<profile>` | 构建某 profile 固件（生成 ELF/bin/dis/map + ICCM/DCCM 镜像） |
| `make software-fpga` | = `rtthread-coremark`，板上固件（等 MSH 输入） |
| `make sim-smoke/trap-timer/rtthread/msh/coremark` | 对应 profile 的 Verilator 仿真 |
| `make sim-coremark COREMARK_ITERATIONS=3` | 通过 UART 下发 `coremark 3` 的仿真 |
| `make fpga-build / fpga-program` | Vivado 综合 / 烧写 |
| `make check` | 静态 + 基础检查全家桶 |

`software/Makefile` 编译每个 profile 时按 `profiles/<profile>.mk` 收集 `SOURCES`，链接 `linker/socrv_code_data.ld`，输出 `build/software/<profile>/firmware.{elf,bin,dis,map}`。

---

## 8. 修改 vs 未修改（上游）对照总结

| 组件 | 上游 | 上游位置 | 是否改动 | 本工程自定义 |
| --- | --- | --- | --- | --- |
| CoreMark 核心算法 | eembc/coremark v1.01 | `coremark/upstream/`（gitignore） | **未改** | —— |
| CoreMark 适配 | —— | —— | —— | `coremark/port/common/`、`port/baremetal/`、`port/rtthread/` |
| RT-Thread 内核 | RT-Thread v5.2.2 | `rt-thread/upstream/`（gitignore） | **未改** | —— |
| RT-Thread 适配 | —— | —— | —— | `rt-thread/port/` |
| 裸机启动 / BSP / 驱动 | —— | —— | —— | `startup/`、`bsp/`、`runtime/`、`linker/`、`applications/`、`profiles/` |

> 一句话回答“Coremark 是否只改了 portme 等部分，没改关键算法和文件？”——**是**。核心算法文件由上游原样拉取，本工程只在 `core_portme.c/h`、`ee_printf.c`、两个入口 `main.c/command.c` 做适配，并用 `-Dmain=coremark_main` 把上游 `core_main.c` 改名为可调用函数。
