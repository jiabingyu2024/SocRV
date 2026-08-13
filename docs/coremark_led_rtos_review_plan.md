# CoreMark 点灯实现与 RT-Thread / CoreMark 运行审查 · 后续计划

- 日期：2026-08-13
- 目标：
  1. 明确“CoreMark 开始运行时亮一个 LED，运行结束时再亮一个 LED”要改**哪些文件、哪些代码**。
  2. 审查当前 SOC 上 **RT-Thread 与 CoreMark 是否运行正常**，列出发现与风险。
  3. 给出**分步后续计划**（可执行、可验证、可回滚）。

> 一句话结论：
> - 点灯走 **GPIO → 板上 `virtual_led[15:0]`** 通路，挂点是 `core_portme.c` 的 `start_time()` / `stop_time()`（正好是 CoreMark 基准循环的前后边界）。
> - 当前 RT-Thread / CoreMark 主体链路**已可用**，但发现**一处文档与实现不一致**（计时时钟 250 MHz vs 50 MHz）和**一处合同未同步**（UART 中断新接到 cause 11，合同仍只有 cause 7），需要后续确认/补齐。

---

## 1. LED 硬件通路（先搞清楚“灯”到底连在哪）

这是最容易踩坑的一点：**板上的 LED 不是直接由某个独立外设驱动，而是 `virtual_led[31:0]` 这个 32 位总线**。

`fpga/boards/kintex7_competition/rtl/board_io_wrapper.sv`：

```systemverilog
virtual_led_o = '0;
virtual_led_o[15:0] = gpio_o_i & gpio_oe_i;   // GPIO[15:0] -> LED[15:0]
virtual_led_o[28]   = clock_locked_i;
virtual_led_o[29]   = cpu_fault_i;
virtual_led_o[30]   = test_done_i && !test_pass_i;   // 失败(FAIL)
virtual_led_o[31]   = test_done_i &&  test_pass_i;   // 成功(PASS)
virtual_seg_o       = {test_code_i[7:0], commit_pc_i};
```

因此：

| LED 位 | 来源 | 软件如何控制 |
| --- | --- | --- |
| `[15:0]` | `gpio_out & gpio_oe` | 写 GPIO 外设（`gpio_set_output` + `gpio_write`） |
| `[28]` | 时钟锁定 | 硬件 |
| `[29]` | CPU fault | 硬件（`test_status==FAIL`） |
| `[30]` | FAIL | 写 `SYSCTRL.STATUS=FAIL magic`（`test_status_report_fail`） |
| `[31]` | PASS | 写 `SYSCTRL.STATUS=PASS magic`（`test_status_report_pass`） |

**结论**：给 CoreMark 开始/结束各点一盏独立的、由软件按位控制的灯，应使用 **GPIO[15:0] 通路**（例如 bit0 = “运行中”，bit1 = “已结束”）。不要用 `test_status` 那一路，因为那会同时触发仿真结束/板上 PASS-FAIL 判定。

GPIO 寄存器（`data/soc/software_contract.json` + `soc_registers.h`）：

| 寄存器 | 偏移 | 含义 |
| --- | --- | --- |
| OUTPUT_ENABLE | `0x08` | 置 1 使能对应位输出驱动 |
| OUTPUT | `0x04` | 输出逻辑值 |
| OUTPUT_SET / CLEAR / TOGGLE | `0x0c/0x10/0x14` | 写 1 原子置位/清零/翻转对应位 |

现有驱动 `bsp/drivers/drv_gpio.c` 只暴露了 `gpio_set_output(mask)`、`gpio_write(value)`、`gpio_read()`。

---

## 2. 点灯实现方案

### 2.1 挂点选择：`start_time()` / `stop_time()`

CoreMark 主流程（上游 `core_main.c`，未改）的顺序是：

```
portable_init()  →  start_time()  →  iterate()  ← 真正的基准循环  →  stop_time()  →  portable_fini()
```

因此 `start_time()` / `stop_time()` **正好把“真正的 CoreMark 计算”夹在中间**，是“开始亮灯 / 结束亮灯”最语义准确的挂点。这两个函数在本工程 `software/coremark/port/common/core_portme.c` 中已有实现（§4.3 of 介绍文档），且已经写了 `SOCRV_TEST_PERF_START/STOP_MAGIC` 到 `SYSCTRL.CODE`，点灯逻辑加在旁边即可。

### 2.2 具体改动清单

#### 改动 1：让 RT-Thread profile 编译 GPIO 驱动（**必改**）

`rtthread_sources.inc` 当前**没有**编译 `drv_gpio.c`，而板上固件 `rtthread-coremark` 正是走这条 profile。不改这里，点灯函数会链接失败。

`software/profiles/rtthread_sources.inc` 的 `RTTHREAD_COMMON_SOURCES` 追加一行：

```make
bsp/drivers/drv_gpio.c \
```

> 裸机 profile 无需改：`baremetal_sources.inc` 已经包含 `bsp/drivers/drv_gpio.c`。

#### 改动 2：定义 LED 位宏（推荐，可维护性）

在 `bsp/include/drv_gpio.h` 或新建一个小的板级头中定义：

```c
#define LED_COREMARK_RUN_MASK   (1u << 0)   /* CoreMark 开始 -> LED0 */
#define LED_COREMARK_DONE_MASK  (1u << 1)   /* CoreMark 结束 -> LED1 */
```

> 位号按实际板级连线/比赛展示需要调整；`[15:0]` 均可选，避开 `[28..31]`（被时钟/PASS/FAIL 占用）。

#### 改动 3：在 `core_portme.c` 点灯（**核心改动**）

```c
#include "drv_gpio.h"          /* 新增 */

/* 一次性的输出使能：可放 portable_init()，也可放 start_time() */
void portable_init(core_portable *portable, int *argc, char *argv[])
{
    ...
    /* 使能两个 LED 的输出驱动（bit 使能，不改输出值） */
    gpio_set_output(LED_COREMARK_RUN_MASK | LED_COREMARK_DONE_MASK);
    ...
}

void start_time(void)
{
    saved_mstatus = irq_save();
    irq_clear_software();
    timer_start(0);
    test_status_set_code(SOCRV_TEST_PERF_START_MAGIC);
    gpio_write(LED_COREMARK_RUN_MASK);                 /* 亮“运行中”LED */
    start_ticks = (CORE_TICKS)timer_read();
}

void stop_time(void)
{
    stop_ticks = (CORE_TICKS)timer_read();
    gpio_write(LED_COREMARK_RUN_MASK | LED_COREMARK_DONE_MASK);  /* 亮“已结束”LED */
    test_status_set_code(SOCRV_TEST_PERF_STOP_MAGIC);
}
```

要点：
- `gpio_write()` 写的是**整个 OUTPUT 寄存器**，所以结束时要写 `RUN|DONE` 两个位，避免把“运行中”灯顺手灭掉（除非你本就想要“结束亮、开始灭”的互斥效果）。
- CoreMark 运行期间 RT tick 与 MIE 已关闭，无并发，`gpio_write` 全量写安全。
- 若想更精确/原子地只置位某一位，可给 `drv_gpio.c` 增加 `gpio_set(mask)` / `gpio_clear(mask)`，用 `OUTPUT_SET`(0x0c)/`OUTPUT_CLEAR`(0x10) 寄存器，避免读改写。

#### 改动 4（可选）：给裸机 CoreMark 同样点灯

`core_portme.c` 是裸机与 RT-Thread 共用的，因此**改动 3 会自动同时覆盖 `coremark-baremetal`**（裸机 profile 已编译 `drv_gpio.c`）。若要裸机也亮灯，无需额外代码；若不希望裸机亮灯，可在 `portable_init` 里用 `#ifdef` 区分。

### 2.3 备选挂点（不推荐，供对比）

| 挂点 | 位置 | 优缺点 |
| --- | --- | --- |
| `cmd_coremark()` 前后 | `coremark/port/rtthread/command.c` | 只在 RT-Thread 生效；但包含参数解析/打印/CRC 判定，不是“纯计算”边界 |
| `portable_init/fini` | `core_portme.c` | 覆盖初始化到收尾，比 start/stop 稍宽（含打印） |
| `main()` 前后 | 各入口 main | 太粗，覆盖整个程序生命周期 |

`start_time/stop_time` 是最贴合“CoreMark 计算开始/结束”语义的选择。

---

## 3. RT-Thread 与 CoreMark 运行审查（是否正常）

### 3.1 已确认正常的部分

1. **工具链 / 内存**：`-march=rv32imf_zicsr -mabi=ilp32f`，无 C/A/D；ICCM 取指、DCCM 数据分离；`.rodata` 正确放入 DCCM。链接脚本有溢出断言。
2. **RT-Thread tick**：`RT_TICK_PER_SECOND=100`，`timer_init_tick(100)` 按 50 MHz 外设时钟算出 `tick_delta = 500000`，定时器/软件中断复用 cause 7 的区分逻辑（`board.c: timer_irq`）正确。
3. **CoreMark 计时**：`start_time` 关 MIE + 重启 mtime → `iterate` → `stop_time` 读 mtime → `command.c` 结束后 `timer_init_tick` 重挂 RT tick，并 `RT_ASSERT` 保证重挂成功，避免中断风暴。链路闭环正确。
4. **只改 port 不改算法**：CoreMark / RT-Thread 核心均为上游原样拉取（见介绍文档 §8）。
5. **构建与仿真入口齐全**：`make sim-rtthread` / `sim-coremark` / `sim-msh` / `software-fpga` 覆盖从编译到仿真到板子的路径。

### 3.2 发现的隐患（需处理/确认）

| # | 级别 | 问题 | 位置 | 建议 |
| --- | --- | --- | --- | --- |
| R1 | 中 | **计时时钟文档不一致**：`software/README.md` 写“以 250 MHz `mtime` 统计”，但权威合同 `timer_hz=50_000_000`、`soc_config.h` `SOCRV_TIMER_CLOCK_HZ=50MHz`、`COREMARK_TICKS_PER_SEC=50MHz` 均一致指向 **50 MHz 外设 mtime**。README 的“250 MHz”是过期笔误（250 MHz 是 core 最高可配频率，不是 mtime）。 | `software/README.md` | 改 README 为“50 MHz 外设 mtime”；同时明确 CoreMark/MHz 到底按哪个频率归一化（见 R2）。 |
| R2 | 中 | **CoreMark/MHz 归一化基准待确认**：`command.c` 打印 `CoreMark/MHz (x1000) = iterations*1e9/ticks`，但“MHz”指代未明确。mtime=50 MHz 固定，而 core 可 100/250 MHz，最终官方分数应以 **core 实际 MHz** 归一化，需在固件里确认/固化这个基准。 | `coremark/port/rtthread/command.c`、`core_portme.h` | 与比赛要求对齐：明确 core 目标频率，统一 `COREMARK_TICKS_PER_SEC`（计时用 50 MHz 不变）与“CoreMark/MHz”的除数。 |
| R3 | 中 | **UART 中断合同未同步**：上一轮 RTL 已把 `uart_irq` 接到 cause 11（MEIP），但 `data/soc/software_contract.json` 仍是 `"machine_causes": {"timer": 7}`、`"external_sources": {}`，生成头 `soc_irq.h` 只有 `SOCRV_MCAUSE_TIMER 7`。软件若要用 UART RX 中断，合同与头文件都不具备 cause 11。 | `data/soc/software_contract.json`、`bsp/include/soc_irq.h` | 若后续启用 UART 中断：更新合同加 `external: 11`，跑 `make soc-contract`，并在 RT-Thread `board.c` 安装 cause 11 的 handler + 使能 `mie.MEIE`。当前点灯方案**不需要**中断。 |
| R4 | 低 | **DCCM 空间余量**：CoreMark `TOTAL_DATA_SIZE=2000` 静态数据 + RT-Thread small-mem heap + 各线程栈 + 8 KB 主栈都挤在 64 KB DCCM。需确认 `make software-fpga` 后 `size.txt`/map 中 heap 边界与栈不重叠（链接脚本已有 `ASSERT`，主要关注运行时余量）。 | 链接脚本 / `build/software/*/size.txt` | 每次构建后看 `size.txt` 与 map，必要时调 `IDLE_THREAD_STACK_SIZE`、`FINSH_THREAD_STACK_SIZE` 或 heap。 |
| R5 | 低 | **CoreMark 运行期若死循环，tick 不恢复**：`start_time` 关 MIE 后若 `iterate` 异常，`command.c` 的恢复逻辑不执行，MSH 会卡死。当前已用 `RT_ASSERT` + 返回码兜底，但仍属单点。 | `core_portme.c` / `command.c` | 可接受；如需更稳，可加看门狗（当前 SOC 无 WDT 外设）。 |
| R6 | 信息 | **官方计分需 ≥10 s**：`command.c` 已对 `<10 s` 打印“非正式分数”。正式计分应跑 `coremark 10000`（或更高）并确认 ≥10 s。 | `command.c` | 按比赛规则选择迭代次数。 |

---

## 4. 后续行动计划（分步，可验证、可回滚）

### 阶段 0：基线确认（先跑通，再改）

```text
make deps-check
make soc-contract-check
make check
make sim-rtthread          # RT-Thread 起调度、worker PASS
make sim-coremark COREMARK_ITERATIONS=10   # CoreMark 命令链路 + CRC PASS
```

> 目的：确认改动前基线是绿的，后续点灯改动可区分“点灯引入的问题” vs “既有问题”。

### 阶段 1：实现点灯（改 2~3 个文件）

1. `software/profiles/rtthread_sources.inc`：`RTTHREAD_COMMON_SOURCES` 追加 `bsp/drivers/drv_gpio.c`。
2. `software/bsp/include/drv_gpio.h`（或新板级头）：定义 `LED_COREMARK_RUN_MASK` / `LED_COREMARK_DONE_MASK`。
3. `software/coremark/port/common/core_portme.c`：`#include "drv_gpio.h"`；`portable_init` 里 `gpio_set_output(RUN|DONE)`；`start_time` 亮 RUN、`stop_time` 亮 RUN|DONE。

（可选）`bsp/drivers/drv_gpio.c` 增加 `gpio_set/gpio_clear`。

### 阶段 2：仿真验证

```text
make software-fpga          # 编译 rtthread-coremark，确认链接通过（关键：drv_gpio.c 已纳入）
make sim-coremark COREMARK_ITERATIONS=10
```

验证点：仿真日志/波形里 `gpio_out`（或 `virtual_led[1:0]`）在 `PERF_START` 前后、`PERF_STOP` 前后出现预期电平；CoreMark CRC 仍 PASS。

### 阶段 3：FPGA 板上验证

```text
make software-fpga
make fpga-build
make fpga-program
# 板上 msh> 输入：coremark 10000
```

观察：开始瞬间 LED0 亮，结束瞬间 LED1 亮（LED[31:30] 的 PASS/FAIL 由 test_status 独立驱动，勿混淆）。

### 阶段 4：按审查结论补齐（视需要）

1. 修正 `software/README.md` 的“250 MHz mtime” → 50 MHz。
2. 对齐 CoreMark/MHz 归一化基准（R2）。
3. 若启用 UART RX 中断：更新 `software_contract.json` + `make soc-contract` + RT-Thread 注册 cause 11（R3）。

### 回滚策略

- 点灯改动集中在 2~3 个文件、且均为**新增/追加**为主（`gpio_set_output`/`gpio_write` 幂等），`git diff` 清晰，可逐文件 `git checkout -- <file>` 回退。
- `make soc-contract` 前先 `git diff data/soc/software_contract.json` 复核，避免手改生成文件污染。

---

## 5. 附：点灯涉及的完整文件链路（速查）

```
core_portme.c (start_time/stop_time 点灯)
   └─ gpio_set_output / gpio_write          ← bsp/drivers/drv_gpio.c
        └─ mmio_write32(GPIO.OUTPUT_ENABLE / GPIO.OUTPUT)   ← bsp/include/soc.h
             └─ SOCRV_GPIO_BASE + OFFSET    ← 由 data/soc/*.json 生成（soc_memory_map.h / soc_registers.h）
RTL: soc_top.gpio_out[15:0] ──► fpga_top ──► board_io_wrapper.virtual_led[15:0] = gpio_out & gpio_oe ──► 板上 LED[15:0]
```
