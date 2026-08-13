# CoreMark 终端输出对齐原仓库格式 · 问题分析与修改计划

- 日期：2026-08-13
- 目标：把 `coremark` 命令跑完后在终端打印的内容，尽量保持 EEMBC CoreMark 原仓库（`eembc/coremark` v1.01）的输出格式。
- 范围：本次只动 **适配层**（`software/coremark/port/` 与 `software/profiles/`），**不碰上游核心算法文件**（`core_main.c` 等，由 `make deps` 原样拉取）。

> 结论先行：
> - 三个问题的根因都集中在 `software/coremark/port/rtthread/command.c`（自造打印）和 `software/profiles/coremark_sources.inc` / `rtthread-coremark.mk`（自编 `FLAGS_STR`）。
> - **上游 `core_main.c` 已经通过 `ee_printf` 把官方完整结果打印出来了**（`CoreMark Size / Total ticks / Total time / Iterations/Sec / Iterations / Compiler version / Compiler flags / Memory location / 各 CRC / Correct operation validated / CoreMark 1.0`）。所以“保持原仓库格式”的正确做法是：**删掉 `command.c` 里所有 `SocRV ...` 自造打印，让上游输出原样露出**，而不是去“补”什么。
> - `COREMARK_TICKS_PER_SEC = 50 MHz` **本身是对的**（它是 `mtime` 的计时频率），**不能改成核心时钟**；真正错的是把 50 MHz 外设时钟当成 CPU 时钟**打印出来**。

---

## 1. 背景：原仓库到底打印什么（权威格式）

上游 `core_main.c`（v1.01，commit `cfa9ab377835911f23d9b0831c7be302ed1f58de`）的结果打印段如下（`ee_printf` → `uart_putc`，已在本工程 `port/common/ee_printf.c` 接好 UART）：

```text
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 123456789
Total time (secs): 2.469136
Iterations/Sec   : 4050.000000
Iterations       : 10000
Compiler version : GCC 12.2.0
Compiler flags   : -O3 -march=rv32imf_zicsr -mabi=ilp32f
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x33ff
Correct operation validated. See readme.txt for run and reporting rules.
CoreMark 1.0 : 4050.000000 / GCC 12.2.0 -O3 -march=rv32imf_zicsr -mabi=ilp32f / STATIC
```

关键点（对照原仓库代码）：

1. **没有 "clock=xxx Hz" 这一行**。时钟只隐含在 `Total time (secs)` 里（`ticks / COREMARK_TICKS_PER_SEC`）。
2. **头两行由 `seedcrc` 决定**：`TOTAL_DATA_SIZE=2000` → 每算法 666 字节 → `seedcrc=0xe9f5` → 打印 `2K performance run parameters for coremark.`，且 `known_id==3` → **才会打印最后的 `CoreMark 1.0 : …` 得分行**。当前 profile 的 `-DTOTAL_DATA_SIZE=2000` 正好落在这个官方 2K 档，所以得分行是**能**打出来的（已核对，无需改）。
3. `Compiler flags` 打印的是 `COMPILER_FLAGS`，即 `FLAGS_STR`（真实编译选项），不是自编的描述串。
4. `MULTITHREAD=1`，所以不打印 `Parallel …` 行，`CoreMark 1.0` 行也没有 `/ N:method` 后缀——与本工程单核单上下文一致。

---

## 2. 三个问题的定位与根因

### 问题 1：时钟打印错误（外设时钟被当成核心时钟）

**现状**（`software/coremark/port/rtthread/command.c:65-67`）：

```c
rt_kprintf("SocRV CoreMark: iterations=%u, clock=%u Hz\n",
           iterations,
           COREMARK_TICKS_PER_SEC);      // = 50_000_000
```

**根因**：把两个不同的“时钟”混为一谈：

| 宏 / 函数 | 值 | 含义 | 正确用途 |
| --- | --- | --- | --- |
| `COREMARK_TICKS_PER_SEC` | 50 MHz | `mtime`（外设 `machine_timer`）的**计时频率** | 只能用于 `ticks → 秒` 换算 |
| `SOCRV_SOC_CLOCK_HZ` | 100 MHz（编译期） | CPU **核心**时钟 | 对外报告 / 归一化 |
| `soc_clock_hz()` | 100/150/200/250 MHz（运行时读 `SYSCTRL.CLOCK_HZ`） | 实际核心时钟 | 对外报告 |

`machine_timer` 挂在 50 MHz 外设时钟域（`local_peripheral_subsystem.sv` 的 `clk` 即外设 50 MHz，`machine_timer.sv` 用同一个 `clk` 累加 `mtime`；合同 `timer_hz=50_000_000`）。所以：

- **`COREMARK_TICKS_PER_SEC` 必须保持 50 MHz**。它就是上游 `time_in_secs()` 的分母，`Total time (secs)`、`Iterations/Sec`、`CoreMark 1.0` 得分都由它换算。**把它改成核心时钟会把真实时间/得分算错 2×~5×。**
- **真正错的**是把 `COREMARK_TICKS_PER_SEC`（外设 50 MHz）**当 CPU 时钟打印出来**给人看，一眼看上去像是“CPU 跑 50 MHz”，而实际核心是 100/150/200/250 MHz。

> 关于“迭代次数/得分算不对”：上游 `core_main.c` 的 `Iterations/Sec` 与 `CoreMark 1.0` 得分**在当前配置下是正确的**（`ticks / 50e6` 就是墙钟秒数）。当前**真正算错的**是 `command.c` 里另一条自造打印 `SocRV CoreMark/MHz (x1000)`（见问题 2），它的公式 `iterations*1e9/ticks` 不是任何有意义的 “CoreMark/MHz”，应删除。若你期望的是一个“按核心 MHz 归一化”的分数，那是原始 CoreMark 不打印的派生指标，另需按 `Iterations/Sec / core_MHz` 现算，且要读运行时核心时钟 `soc_clock_hz()`。

**修复**：删除该行（原仓库本就没有时钟行）。若确实想保留一个“时钟”提示，应打印**核心时钟** `soc_clock_hz()`，并放在 `coremark_main()` **之前**单独一行，不与官方结果块混排（见 §3 备选）。

### 问题 2：打印内容冗余（自造的 "SocRV ..." 污染官方格式）

**现状**（`command.c:85-104`，在 `coremark_main()` 返回之后追加）：

```c
uart_puts("SocRV exact total ticks: ");      print_u64(ticks);
uart_puts("\nSocRV total time (ms): ");      print_u64((ticks * 1000u) / COREMARK_TICKS_PER_SEC);
uart_puts("\nSocRV ticks/iteration: ");      print_u64(ticks / iterations);
uart_puts("\nSocRV CoreMark/MHz (x1000): "); print_u64(((uint64_t)iterations * 1000000000ull) / ticks);
uart_putc('\n');
if (ticks < (uint64_t)COREMARK_TICKS_PER_SEC * 10u)
    rt_kprintf("SocRV note: short functional/trend run; not a formal score.\n");
if (result == 0) rt_kprintf("SocRV CoreMark CRC check PASS\n");
else             rt_kprintf("SocRV CoreMark CRC check FAIL: %d\n", result);
```

**根因**：这些是适配层自己加的，与官方字段大量重复甚至冲突：

| 自造打印 | 是否与官方重复 | 结论 |
| --- | --- | --- |
| `SocRV CoreMark: iterations=..., clock=...` | 官方已有 `Iterations`；`clock` 是错误概念 | 删 |
| `SocRV exact total ticks` | 官方已有 `Total ticks` | 删 |
| `SocRV total time (ms)` | 官方已有 `Total time (secs)` | 删 |
| `SocRV ticks/iteration` | 官方无此字段，非必需 | 删 |
| `SocRV CoreMark/MHz (x1000)` | 公式错误（`iterations*1e9/ticks` 无意义） | 删 |
| `SocRV note: short run...` | 官方已有 `<10s` 时打印 `ERROR! Must execute for at least 10 secs...` | 删 |
| `SocRV CoreMark CRC check PASS/FAIL` | 官方已有 `Correct operation validated.` / `Errors detected` | 删 |

**修复**：整段删除，只保留 `coremark_main()` 之后**必须保留的副作用**（不是打印）：`uart_flush()`、`timer_init_tick()` 重挂 RT tick、`coremark_resume_interrupts()` 恢复 MIE、`test_status_report_pass/fail()` 写板级 PASS/FAIL。`<10s` 的官方提示由上游 `core_main.c` 自己负责。

### 问题 3：编译 flag 错误（自编描述串，非真实编译选项）

**现状**：

- `software/profiles/rtthread-coremark.mk:7`：`COREMARK_FLAGS_TEXT := O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-rtthread-command`
- `software/profiles/coremark_sources.inc:19`：`-DFLAGS_STR=\"$(COREMARK_FLAGS_TEXT)\"`
- `software/coremark/port/common/core_portme.h:19`：`#define COMPILER_FLAGS FLAGS_STR`

最终打印 `Compiler flags : O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-rtthread-command` —— 这是一段**人看的描述**，不是 gcc 真实收到的编译选项。

**原仓库做法**（`barebones/core_portme.mak`）：

```make
PORT_CFLAGS = -O0 -g
FLAGS_STR = "$(PORT_CFLAGS) $(XCFLAGS) $(XLFLAGS) $(LFLAGS_END)"
CFLAGS = $(PORT_CFLAGS) -I$(PORT_DIR) -I. -DFLAGS_STR=\"$(FLAGS_STR)\"
```

即：`FLAGS_STR` = **真实编译选项**。本工程真实选项来自 `software/toolchain/common_flags.mk`：

```make
ARCH_FLAGS    := -march=rv32imf_zicsr -mabi=ilp32f
OPTIMIZATION  ?= -O3      # rtthread-coremark.mk 显式 -O3
CFLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -fdata-sections -ffunction-sections \
          -msmall-data-limit=0 -Wall -Wextra -Werror -std=c11 $(OPTIMIZATION) -g3
```

**修复**：把 `COREMARK_FLAGS_TEXT` 改成真实选项。推荐（性能相关、信息足）：

```make
COREMARK_FLAGS_TEXT := -O3 -march=rv32imf_zicsr -mabi=ilp32f
```

（若想完全贴近 EEMBC 官方“只报优化级别”的习惯，可用最简 `-O3`；`-O3` 是必须的，`march/mabi` 属于加分信息。注意 `coremark_sources.inc` 里 `-DFLAGS_STR=\"$(…)\"` 已经自带引号，`COREMARK_FLAGS_TEXT` 里**不要再加引号**。）

---

## 3. 具体修改清单（文件级 before / after）

### 改动 A：`software/coremark/port/rtthread/command.c`（核心）

删除自造打印 + 无用助手 `print_u64`。改后 `cmd_coremark` 如下（其余文件结构不变）：

```c
static int cmd_coremark(int argc, char **argv)
{
    uint32_t iterations;
    uint64_t ticks;
    int result;

    if (parse_iterations(argc, argv, &iterations) != 0) {
        rt_kprintf("usage: coremark [iterations]\n");
        rt_kprintf("iterations: 1..%u, default %u\n",
                   COREMARK_MAX_ITERATIONS,
                   COREMARK_DEFAULT_ITERATIONS);
        return -RT_EINVAL;
    }

    uart_flush();
    coremark_set_iterations(iterations);
    (void)coremark_main();   /* 上游 core_main.c 经 ee_printf 打印完整官方报告 */
    result = coremark_result_code();
    ticks = coremark_last_ticks();

    if (ticks == 0u) {
        rt_kprintf("SocRV CoreMark timer did not advance\n");   /* 异常兜底，仅出错时出现 */
        (void)timer_init_tick(RT_TICK_PER_SECOND);
        coremark_resume_interrupts();
        test_status_report_fail(0xffffffffu);
        return -RT_ERROR;
    }

    uart_flush();

    /* 性能 port 跑 CoreMark 时关了 machine-timer IRQ，这里按当前 mtime 重挂 RT tick，
       避免旧的 compare 已过期导致中断风暴；随后恢复 MIE。 */
    RT_ASSERT(timer_init_tick(RT_TICK_PER_SECOND) != 0u);
    coremark_resume_interrupts();
    if (result == 0) {
        test_status_report_pass(0u);
    } else {
        test_status_report_fail((uint32_t)result);
    }
    return result;
}
```

需要一并删除的：

- `print_u64()` 整个函数（`command.c:15-27`）。删除后若未删除，`-Wall -Wextra -Werror` 会因 `unused-function` 编译失败。
- 顶部 `#include "core_portme.h"` 仍保留（`coremark_set_iterations` 等声明）；`drv_uart.h` 仍保留（`uart_flush`）；`test_status.h` 仍保留（`test_status_report_*`）。`drv_timer.h` 仍保留（`timer_init_tick`）。

### 改动 B：`software/profiles/rtthread-coremark.mk`（1 行）

```diff
- COREMARK_FLAGS_TEXT := O3-rv32imf_zicsr-ilp32f-veer-eh1-tcm-rtthread-command
+ COREMARK_FLAGS_TEXT := -O3 -march=rv32imf_zicsr -mabi=ilp32f
```

`software/profiles/coremark_sources.inc` 不用改（`-DFLAGS_STR=\"$(COREMARK_FLAGS_TEXT)\"` 已自带引号）。

### （备选）改动 C：若坚持要一行“核心时钟”提示

放在 `coremark_main()` **之前**，打印核心时钟（不是外设时钟），不混进官方块：

```c
rt_kprintf("SocRV core clock: %u Hz\n", soc_clock_hz());
```

> `soc_clock_hz()` 在 `bsp/include/soc.h`，运行时读 `SYSCTRL.CLOCK_HZ`，能区分 100/150/200/250 MHz 目标；`command.c` 需 `#include "soc.h"`。**默认不推荐**，因为它会破坏“尽量保持原仓库格式”这条总原则。

### （可选）改动 D：`MEM_LOCATION` 措辞

`core_portme.h:20` 现为 `#define MEM_LOCATION "STATIC"`。原仓库默认是 `"STACK"`，但本工程 `MEM_METHOD=MEM_STATIC`，`"STATIC"` 更准确，**建议保持现状**（打印 `Memory location : STATIC`），无需改。

---

## 4. 修改后预期终端输出（对齐原仓库）

板上 `msh> coremark 10000` 后应看到（数值仅为示例）：

```text
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 125000000
Total time (secs): 2.500000
Iterations/Sec   : 4000.000000
Iterations       : 10000
Compiler version : GCC 12.2.0
Compiler flags   : -O3 -march=rv32imf_zicsr -mabi=ilp32f
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x33ff
Correct operation validated. See readme.txt for run and reporting rules.
CoreMark 1.0 : 4000.000000 / GCC 12.2.0 -O3 -march=rv32imf_zicsr -mabi=ilp32f / STATIC
```

不再出现任何 `SocRV exact total ticks / total time / ticks/iteration / CoreMark/MHz / note / CRC check` 行，也不再出现 `clock=50000000`。

---

## 5. 下一步执行计划（分阶段、可验证、可回滚）

### 阶段 0：基线（先跑通，再改）

```text
make deps-check
make soc-contract-check
make check
make software-fpga            # 编译 rtthread-coremark，确认改动前可构建
```

> 目的：确认改动前基线是绿的，后续只归因到本次打印/flags 改动。

### 阶段 1：实现（改 2 个文件）

1. `software/coremark/port/rtthread/command.c`：删 `print_u64`、删 `clock=…` 行、删 5 段 `SocRV …` 打印与 `note`/`CRC` 打印，保留副作用（重挂 tick / 恢复中断 / PASS-FAIL）。
2. `software/profiles/rtthread-coremark.mk`：`COREMARK_FLAGS_TEXT` 改为 `-O3 -march=rv32imf_zicsr -mabi=ilp32f`。

### 阶段 2：构建 + 仿真验证

```text
make software-fpga
make print-flags PROFILE=rtthread-coremark        # 确认 -DFLAGS_STR="-O3 -march=..." 已生效
make sim-coremark COREMARK_ITERATIONS=10          # 快速链路 + CRC
```

验证点：
- `Compiler flags` 行显示真实选项（不再是 `O3-rv32imf…-rtthread-command`）。
- 输出不再含任何 `SocRV …` 行。
- 仍能打印 `Correct operation validated.` 与 `CoreMark 1.0 : …`。

### 阶段 3：FPGA 板上验证

```text
make software-fpga
make fpga-build
make fpga-program
# 板上 msh> coremark 10000
```

核对：
1. 输出与 §4 示例格式一致（原仓库格式）。
2. `Total time (secs)` 与实际挂钟时间吻合（≥10 s 才有效，`Iterations` 按需要调大，官方要求 ≥10 s）。
3. LED0 在 `start_time` 亮、LED1 在 `stop_time` 亮（上一轮点灯改动不受本次影响，`core_portme.c` 未动）。

### 回滚策略

- 两个文件均为删减/单行替换，`git diff` 干净；逐文件 `git checkout -- <file>` 即可回退。
- `coremark_sources.inc` 未动，`core_portme.c/h` 未动，上游 `core_main.c` 未动。

---

## 6. 顺带发现（本次可不动，仅记录）

1. **`test_status_report_pass/fail` 未反映真实 CRC**：`command.c` 的 `result` 来自 `coremark_result_code()`，而它只检查 `data_error_seen`（`portable_init` 里的类型尺寸 sanity 检查），**不等于**上游 `core_main.c` 的 CRC 判定（`total_errors`）。上游 `main()` 是 `void`（`MAIN_HAS_NOARGC=1`），不返回 `total_errors`。当前板上 PASS/FAIL LED 可能因此与实际 CRC 结果不一致（终端里 `Correct operation validated` / `Errors detected` 仍准确）。若要让板级 PASS/FAIL 跟随真实 CRC，需在 port 里给 `core_main.c` 暴露一个 `total_errors` 出口（例如把 `coremark_result_code()` 改成读一个由 `core_main.c` 回写的全局）。**与本次“输出格式”任务解耦，建议单独评估。**
2. **`Total ticks` 被截到 32 位**：上游 `ee_printf("Total ticks : %lu", (ee_u32)total_time)` 强制 32 位。50 MHz 下 32 位约 85 秒内不溢出，官方 ≥10 s 计分不受影响；超长跑需要留意（上游如此，保持原样）。
3. **`COMPILER_VERSION "GCC " __VERSION__`**：本工程比上游多一个空格（`"GCC 12.2.0"` vs 上游 `"GCC12.2.0"`），无实质影响，可留可改。

---

## 附：涉及文件链路（速查）

```
coremark_main()  ──► upstream/core_main.c  ──► ee_printf()  ──► port/common/ee_printf.c ──► uart_putc()
      ▲ 调用
coremark/port/rtthread/command.c  (cmd_coremark：只负责 参数解析 + 调用 + 重挂tick/恢复中断/PASS-FAIL，不再打印)
      ▲ 编译进
profiles/rtthread-coremark.mk  ──► coremark_sources.inc  ──► -DFLAGS_STR="$(COREMARK_FLAGS_TEXT)"
                                                        └─► core_portme.h: COMPILER_FLAGS = FLAGS_STR
```
