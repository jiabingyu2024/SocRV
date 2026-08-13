# SocRv RTL 全面审查与清洗方案

- 日期：2026-08-13
- 范围：`rtl/` 下全部文件（含 `core/eh1f`、`soc/`、filelist、配置与 license），以及与之强相关的 `fpga/` 时钟生成与 `tb/` 仿真顶层
- 目的：① 对 RTL 做一次介绍与整理；② 审查 SOC 串口（UART）是否存在问题；③ 确认“外设固定 50 MHz、core 频率可配置”的结论；④ 给出“不相关 license / 无用文件”的清洗清单（本次只做审查，不改文件）

> 结论先行：
> - **时钟**：外设固定 50 MHz、core 可配置（默认 100 MHz，最高 250 MHz）——已确认成立。
> - **串口**：UART 本身可收发，但 **UART 中断没有接到核心上**（`uart_irq` 悬空），是本次审查发现的最主要问题；另有“无发送中断 / 无溢出·帧错误标志”等次要问题。
> - **License**：目录里的 3 份 license 文件**都与实际编译进设计的代码一一对应，不属于“不相关”**，建议**保留**而非删除；真正该删的是历史 filelist、已生成但不再使用的配置产物、陈旧的 `flist.questa` 等。

> **执行状态（2026-08-13 已执行）**：
> - ✅ 文件清洗：§6.3 所列 13 个无用文件已全部删除（`flist.questa`、`filelist_stage_a/b/c/d.f`、`defines.h`、`pd_defines.vh`、`link.ld`、`perl_configs.pl`、`whisper.json`、被遮蔽的 `include/build.h`、`config_gen/veer.config`、`config_gen/veer_config_gen.py`）；随后按确认又把 §6.4 的三份 license 与 `UPSTREAM.md` 一并删除，来源/许可标注由项目方在 RTL 之外统一维护。
> - ✅ 串口中断：`uart_irq` 已接入 core。外设域 `uart_irq` 经 2 级同步后接到 `veer` 的 `extintsrc_req[1]`；`veer.sv` 中 `mexintpend = extintsrc_req[1]`，即 UART 接收中断作为**机器外部中断（cause 11 / MEIP）**上报（原 `mexintpend` 恒为 0）。软件需使能 `mstatus.MIE` + `mie.MEIE`，并在读 UART 状态后写偏移 `0x05` 清 `irq_pending`。
> - ✅ README：`rtl/README.md` 里失效的 `doc/rtl_stage2_integration_review.md` 已改为 `docs/rtl_review_and_cleanup_plan.md`。

---

## 1. 项目背景与总体结构

SocRv 的 RTL 是从 CHIPS Alliance 的 **Cores-VeeR-EH1**（VeeR/SweRV EH1，双发射 9 级流水 RISC-V）精简得到的 **TCM-only SoC**（`rtl/README.md`）。精简后目标为：

- ISA：`RV32IMF_Zicsr`，ABI `ilp32f`；**无 C 扩展、无 cache、无 ECC、无 PIC、无 DMA、无 AXI/AHB 外部总线**。
- 片上存储：**128 KiB ICCM**（指令）+ **64 KiB DCCM**（数据）。
- 本地 MMIO 外设：machine timer、UART、GPIO、SYSCTRL。
- 新增 FPU：基于 PULP 平台的 `fpnew`，仅启用 `RV32F`（单精度）。

```
rtl/
├── README.md
├── filelist.f                 # 入口，选择 filelist_stage_e.f
├── filelist_stage_{a..e}.f    # 五个历史阶段（仅 e 有效）
├── core/eh1f/                 # core（EH1 精简 + FPU）
│   ├── LICENSE.upstream        # EH1 的 Apache-2.0
│   ├── UPSTREAM.md             # 来源与提交号
│   ├── flist.questa            # 陈旧（$RV_ROOT 路径，已失效）
│   ├── config/eh1_stage_a/     # stage_a 生成配置（部分已废弃）
│   ├── config_gen/             # 配置生成器（veer.config + 脚本）
│   ├── include/  lib/          # 类型/头文件/基础库
│   ├── ifu/  dec/  exu/  lsu/  # 取指/译码/执行/访存
│   ├── fpu/                    # eh1_fpu + vendor/fpnew
│   ├── dbg/  dmi/              # 调试与 JTAG/DMI
│   └── mem.sv veer.sv veer_wrapper.sv
└── soc/                       # 精简 SoC 外设与互联
    ├── soc_top.sv  soc_clock_bridge.sv  soc_memory_map_pkg.sv
    └── local_peripheral_subsystem.sv  machine_timer.sv  uart.sv  gpio.sv  sysctrl.sv
```

---

## 2. Core（`rtl/core/eh1f`）详解

### 2.1 来源与许可

`UPSTREAM.md` 记录了来源仓库 `Cores-VeeR-EH1`、拷贝提交 `d04b1c7ae675a63dc4307cacfd10547ec937b928`、拷贝日期 2026-08-09。规则明确：上游 `Cores-VeeR-EH1` 保持未改动基准，所有精简改动只落在 `rtl/core/eh1f`；每个源文件保留 SPDX `Apache-2.0` 头；最终 core 是“派生实现”，不得当作原版 VeeR EH1。

### 2.2 活跃配置：`common_defines.vh`

真正的配置宏在 `rtl/core/eh1f/config/eh1_stage_a/common_defines.vh`（filelist 里被作为第一个编译单元显式列出，见 `filelist_stage_e.f:12`）。关键宏：

| 宏 | 值 | 含义 |
|---|---|---|
| `RV_TCM_ONLY` | 已定义 | 关 cache（`global.h` 里把 ICACHE 参数归零） |
| `RV_ICCM_ENABLE` / `RV_ICCM_SIZE` | 1 / 128 | 128 KiB ICCM，`RV_ICCM_EADR=0x1ffff` |
| `RV_DCCM_ENABLE` / `RV_DCCM_SIZE` | 1 / 64 | 64 KiB DCCM，`RV_DCCM_SADR=0x20000`，`RV_DCCM_EADR=0x2ffff` |
| `RV_DCCM_DATA_WIDTH` / `RV_DCCM_FDATA_WIDTH` | 32 / 32 | **无 ECC**（fdata == data，去掉了 7-bit ECC） |
| `RV_DCCM_DATA_CELL` | `ram_2048x32` | 无 ECC 存储单元 |
| `RV_XLEN` / `RV_EXT_ADDRWIDTH` | 32 / 32 | RV32 |
| `RV_BUILD_AHB_LITE` / `RV_BUILD_AXI4` | **未定义** | 无外部总线（`common_defines.vh:41-42` 注释明确） |
| `RV_PIC_*` | 保留定义 | 仅用于维持 `RV_PIC_TOTAL_INT_PLUS1=9` 使 `veer.sv` 端口可编译，PIC 本体未实例化 |
| `ASSERT_ON` | **未定义** | 关闭继承的 SVA（含仿真器不支持的延时语法） |
| `CLOCK_PERIOD` | 100 | 遗留的 tb 宏，综合无关 |

> 注意：`config/eh1_stage_a/defines.h` 是 stage_a **生成器原始输出**，里面仍残留 `#define RV_BUILD_AHB_LITE 1`、`ASSERT_ON`、ECC 单元 `ram_2048x39` 等，**与活跃的 `common_defines.vh` 不一致**。真正生效的是 `common_defines.vh`（手工精简版），`defines.h` 已废弃（见 §7）。

### 2.3 模块层级

- `veer_wrapper.sv`（顶层）→ 实例化 `veer`（core）、`mem`（存储）、`dmi_wrapper`（JTAG/DMI）。
- `veer.sv`：实例化 `ifu` / `exu` / `lsu` / `dec` / `dbg`，并显式把 PIC/DMA 相关信号接 0（`veer.sv:1034-1055`，注释“no PIC / no DMA”）。
- `mem.sv`：按 `RV_DCCM_ENABLE` / `RV_ICCM_ENABLE` 生成 `lsu_dccm_mem` 与 `ifu_iccm_mem`；ICACHE 分支被 `RV_TCM_ONLY` 关掉。
- 流水线：`ifu/`（取指、对齐、分支预测 BTB/BHT、ICCM）、`dec/`（译码、GPR、指令缓冲、TLU、trigger）、`exu/`（ALU、乘法、除法）、`lsu/`（地址检查、load/store 控制、DCCM、跨时钟域、bus intf）。
- `dec/csrdecode` 与 `dec/decode`：**无扩展名的“译码源描述”文件**（`.definition` DSL）。它们**不被 RTL 编译/`include`**，只在 `dec_tlu_ctl.sv:2337` 等注释中被提及，作为用 `coredecode`/`espresso` 生成译码等式的**源文件留档**。属“provenance / 再生成源”，非编译依赖。
- `dmi/`：`dmi_wrapper.v`、`dmi_jtag_to_core_sync.v`、`rvjtag_tap.sv`，供 JTAG 调试；在 `soc_top` 中 JTAG 引脚被接地/接常量（`jtag_tck=0` 等），DMI 实际不可用，仅保持端口可综合。

### 2.4 FPU（`fpu/`）

- `eh1_fpr_ctl.sv` + `eh1_fpu.sv`：把 EH1 的 FP 指令译码成 fpnew 请求。
- `eh1_fpu.sv` 实例化 `fpnew_top`：`.Features(RV32F)`、`.src_fmt_i(FP32)`、`.dst_fmt_i(FP32)`、`.int_fmt_i(INT32)`、`.DivSqrtSel(PULP)`（`eh1_fpu.sv:144-158`）。
- 即 **只启用单精度 RV32F**，FP16/FP64 由 `Features(RV32F)` 参数化裁掉；`vendor/fpnew/` 下的整棵树仍被 filelist 全部编译（参数化后再综合裁剪）。
- license：`fpu/vendor/fpnew/LICENSE.solderpad`（Solderpad 0.51，可等同 Apache-2.0）与 `LICENSE.apache`。

---

## 3. SoC（`rtl/soc`）详解

### 3.1 顶层 `soc_top.sv`

端口：`core_clk`、`peripheral_clk`、`rst_n`、`uart_rx/tx`、`gpio_in/out/oe`、`test_status/test_code`。
参数：`CORE_CLOCK_HZ=100MHz`、`PERIPHERAL_CLOCK_HZ=50MHz`、`UART_BAUD=115200`、`GPIO_WIDTH=16`、12 个 ICCM/DCCM 初始化文件。

内部结构：
1. **外设复位释放**（`soc_top.sv:59-65`）：在 `peripheral_clk` 域用 2 级移位生成 `peripheral_rst_n`（假设外设域更慢）。
2. **MMIO 跨时钟桥** `soc_clock_bridge`：把 core 域的本地 MMIO 请求（`lsu_mmio_*`）传到外设域。
3. **外设子模块** `local_peripheral_subsystem`：按地址译码分发到 timer/uart/gpio/sysctrl。
4. **中断同步**（`soc_top.sv:111-131`）：`timer_irq`、`software_irq`、`test_status`、`test_code` 经 2 级同步回到 core 域。
5. **core 实例化** `veer_wrapper`：`timer_int = timer_irq_sync_q | software_irq_sync_q`（`soc_top.sv:168`），`extintsrc_req='0`。

### 3.2 地址映射（`soc_memory_map_pkg.sv`）

| 区域 | 基址 | 大小 |
|---|---|---|
| CODE（ICCM） | `0x0000_0000` | 128 KiB |
| DATA（DCCM） | `0x0002_0000` | 64 KiB |
| TIMER | `0x1000_0000` | 4 KiB |
| UART | `0x1000_1000` | 4 KiB |
| GPIO | `0x1000_2000` | 4 KiB |
| SYSCTRL | `0x1000_3000` | 4 KiB |

> 与 EH1 的 `RV_SERIALIO=0xf0580000`（console 调试串口）不同，本 SoC 用本地 MMIO 的 UART@`0x1000_1000`。`common_defines.vh` 里的 `RV_SERIALIO` 属遗留宏，核心 lsu 的本地 MMIO 端口才是真正的外设通路。

### 3.3 外设寄存器一览

- **machine_timer**：`0x00/0x01` mtime 低/高 32 位、`0x02/0x03` mtimecmp、`0x04` ctrl（bit0 使能、bit1 中断使能）、`0x05` 比较结果。`timer_irq = ctrl[0]&ctrl[1]&(mtime>=mtimecmp)`。复位 `ctrl=2'b01`。写支持字节使能合并（`merge_wstrb`）。
- **uart**：见 §4。
- **gpio**：`0x00` 输入（双级同步）、`0x01` 输出、`0x02` 输出使能、`0x03/0x04/0x05` 置位/清零/异或。宽度 16。
- **sysctrl**：`0x00` 魔数 `0x4548_3146`（"EH1F"）、`0x01` `CORE_CLOCK_HZ`、`0x02` reset_cause、`0x03` BUILD_ID、`0x04` software_irq、`0x05/0x06` test_status/test_code、`0x08` `PERIPHERAL_CLOCK_HZ`。

### 3.4 跨时钟桥 `soc_clock_bridge.sv`

单笔事务 toggle 握手桥：core 域捕获请求并翻转 `req_toggle`；外设域同步后执行，完成时翻转 `resp_toggle` 回传；`core_req_ready = req_busy_q && (resp_toggle_sync_q == req_toggle_q)`。请求/响应的数据总线与 toggle 一起经 2 级同步。特点与约束：
- **阻塞式、单 outstanding**：core 的 LSU 在 `ready=0` 期间停等（EH1 本地 MMIO 是阻塞通道），因此 UART 发送 FIFO 满时会反压整个 core 访存（见 §4 第 4 点）。
- 依赖 `core_req_valid` 在 `ready` 前保持有效（`soc_clock_bridge.sv:83-91` 的 else-if 需要 `core_req_valid`），适配 EH1 的阻塞 MMIO；不适用于单拍 valid 脉冲协议。

---

## 4. 串口（UART）审查结论

`uart.sv`（`CLOCK_HZ`、`BAUD` 参数；`local_peripheral_subsystem.sv:63` 用 `.CLOCK_HZ(PERIPHERAL_CLOCK_HZ)=50MHz`、`.BAUD(UART_BAUD)=115200` 例化）。TX/RX 各 4 深 FIFO，8-N-1，波特率由分频计数（使能式，不产生新时钟域）。

**发现的问题（按严重度）：**

1. **[高] UART 中断未接入核心。** `uart_irq` 在 `soc_top.sv:48` 声明为 `uart_irq_unused`，并在 `soc_top.sv:103` 接到这个悬空名，**没有接到 core 的中断输入**；core 侧 `extintsrc_req='0`。因此 UART 接收中断被完全丢弃，软件只能**轮询**状态寄存器（`0x08`，bit0 = `!rx_empty`）。这是本次审查发现的最主要“串口问题”。
2. **[中] 无发送中断。** `irq_pending` 只在 `rx_push` 置位（`uart.sv:166`），TX 发送完成/空闲不产生中断。轮询驱动没问题，中断驱动拿不到 TX 完成。
3. **[中] 无溢出/帧错误标志。** RX FIFO 满时新字节被**静默丢弃**（`uart.sv:144` 的 `!rx_full` 门控，无 overrun 标志）；停止位未采样为高时字节同样静默丢弃（无 frame-error）。8-N-1 无校验位属设计选择，可接受。
4. **[低] TX FIFO 满反压阻塞 core。** 4 深 FIFO + 单 outstanding 阻塞桥：向 `txdata` 连写超过 4 字节（每字节 10 bit 时间 @115200 ≈ 86.8 µs）会拉低 `req_ready`，进而停等整个 LSU。软件需在写前查 `tx_full`（状态 `0x08` bit1 = `!tx_full`）。
5. **[低] 模块默认参数误导。** `uart.sv:2` 默认 `CLOCK_HZ=250_000_000`，但 SoC 中已用 50 MHz 覆盖。独立例化该模块而未覆盖时会算错波特率。建议把默认值改为 50 MHz 或直接去掉默认。
6. **[信息] 波特率误差。** `RESET_DIV = 50_000_000/115_200 = 434`（整除），实际波特率 115_207，误差 +0.006%，在 UART 常见 ±2% 容限内，可用。
7. **[信息] 复位态。** `uart_ctrl` 复位为 `2'b11`（TX+RX 同时使能，`uart.sv:163`），上电即允许接收。

**配套注意事项（非 UART 本身，但与中断相关）：**
- EH1 只暴露一个 `timer_int` 引脚、无 MSIP 引脚，于是 `soc_top` 把 `software_irq` 与 `timer_irq` **或**在一起走 cause 7（`soc_top.sv:166-168`）。软件中断与定时器中断共用同一 cause，无标准 `mip.MSIP`（cause 3），BSP 需先读 pending 位区分（代码注释已说明）。
- 若未来要接入 UART 中断，需与 `timer_irq` 同样做 2 级同步，并考虑 EH1 中断源有限（`timer_int` + `extintsrc_req`，当前 `extintsrc_req='0`）的约束。

---

## 5. 时钟架构专项回答（外设 50 MHz 固定 / core 可配置）

结论：**成立**。证据链如下（RTL 之外，时钟在 FPGA 层生成）：

1. **板级输入**：200 MHz 差分时钟（`clocks.xdc:1`，period 5.000 ns）。
2. **MMCM**（`fpga/common/rtl/xilinx_clock_wrapper.sv`）：`CLKIN1_PERIOD=5.000`、`CLKFBOUT_MULT_F=5.0` → **VCO = 1 GHz**。
   - `CLKOUT0`（`core_clk`）= VCO ÷ `CORE_CLKOUT_DIVIDE_F`，默认 `10.0` → **100 MHz**；`clocks.xdc:3-4` 注释说明可改 `4.0` → **250 MHz**（可配置）。
   - `CLKOUT1`（`peripheral_clk`）= VCO ÷ `PERIPHERAL_CLKOUT_DIVIDE=20` → **50 MHz（固定）**。
3. **参数链**：`board_clock_reset.sv` / `fpga_top.sv` 默认 `CORE_CLOCK_HZ=100MHz`、`PERIPHERAL_CLOCK_HZ=50MHz`，传入 `soc_top`；`soc_top` 再把 `PERIPHERAL_CLOCK_HZ` 传给 UART 算波特率、传给 SYSCTRL 供软件读取（`sysctrl.sv:37`）。
4. **频率在 RTL 内不是硬件参数**：core/外设只接收 `core_clk`/`peripheral_clk` 输入，实际频率由板级 MMCM 参数 + 时序约束决定；`CORE_CLOCK_HZ`/`PERIPHERAL_CLOCK_HZ` 只是“软件可读的标称值”。

**强耦合点（务必保持一致）**：UART 波特率分频是**编译期**由 `PERIPHERAL_CLOCK_HZ` 算出的，不是运行时测量。因此“外设 50 MHz”由两处共同锁定：① MMCM `PERIPHERAL_CLKOUT_DIVIDE=20`；② `PERIPHERAL_CLOCK_HZ=50_000_000`。改任一处而不改另一处都会让波特率错掉。

**仿真侧**（`tb/soc/soc_sim_top.sv:34-39`）：用 `peripheral_clk <= ~peripheral_clk` 做 /2 分频，仅在 core=100MHz 时得到 50MHz 外设；core 改成 250MHz 时该分频假设失效（且 `soc_top` 复位释放假设外设域更慢）。`rtl/README.md:7` 也提示旧 `soc_sim_top.sv` 尚未迁移、filelist 通过≠可编译运行。

---

## 6. 文件清单与“在用 / 废弃”分类

### 6.1 在用（编译依赖，`filelist_stage_e.f`）

- `soc/` 全部 8 个文件。
- `core/eh1f/`：`veer_wrapper.sv`、`veer.sv`、`mem.sv`；`include/{veer_types.sv,global.h}`；`lib/{beh_lib.sv,mem_lib.sv}`；`ifu/*`（6）；`dec/*`（6，不含 csrdecode/decode）；`exu/*`（4）；`lsu/*`（9）；`fpu/{eh1_fpr_ctl.sv,eh1_fpu.sv}` + `fpu/vendor/fpnew/**`（filelist 全量）；`dbg/dbg.sv`；`dmi/*`（3）；`config/eh1_stage_a/common_defines.vh`、`config/eh1_stage_a/build.h`。

### 6.2 在用但被遮蔽 / 属留档

- `include/build.h`：被 `config/eh1_stage_a/build.h` 遮蔽（incdir 顺序 `config/eh1_stage_a` 在前，`filelist_stage_e.f:4`）。`include/build.h` 是带大量注释宏的旧版，**重复/失效**。
- `dec/csrdecode`、`dec/decode`：译码源留档，非编译依赖（见 §2.3）。

### 6.3 建议删除 / 归档（无编译依赖）

| 文件 | 说明 |
|---|---|
| `core/eh1f/flist.questa` | 陈旧的 Questa filelist，指向 `$RV_ROOT/design/...` 且引用已删除的 `pic_ctrl.sv`、`dma_ctrl.sv`、`lsu_ecc.sv`、`lib/svci_to_axi4.sv` 等 |
| `filelist_stage_a.f` / `_b.f` / `_c.f` / `_d.f` | 历史阶段；a/b/c 引用了已删除的 `pic_ctrl.sv`、`dma_ctrl.sv`、`ifu_ic_mem.sv`、`ifu_compress_ctl.sv`、`lsu_ecc.sv`、`lsu_bus_buffer.sv`、`lib/{svci_to_axi4,ahb_to_axi4,axi4_to_ahb}.sv` 等；仅 `stage_e` 有效（`filelist.f` 指向它） |
| `config/eh1_stage_a/defines.h` | 生成器原始输出，含 `RV_BUILD_AHB_LITE`/`ASSERT_ON`/ECC 单元，与活跃 `common_defines.vh` 矛盾 |
| `config/eh1_stage_a/pd_defines.vh` | 物理综合配置（`TEC_RV_ICG` 工艺单元、`PHYSICAL`），RTL 构建不引用 |
| `config/eh1_stage_a/link.ld` | 链接脚本，已由 `software/linker/` 承接 |
| `config/eh1_stage_a/perl_configs.pl` | 生成器产物（perf 脚本用 hash） |
| `config/eh1_stage_a/whisper.json` | 生成器产物（whisper ISS 用） |
| `config_gen/veer.config` + `veer_config_gen.py` | 配置生成器；**若不再重新生成可删**，若想保留可复现性则保留 |
| `include/build.h` | 被遮蔽的重复文件（见 6.2） |

> 若对 a/b/c/d 或生成器产物不舍得删，可统一移到 `rtl/_archive/` 或 `docs/backup/`，避免与活跃构建混淆。

### 6.4 License / 来源标注：**已删除（attribution 移至 RTL 之外统一维护）**

| 文件 | 对应代码 | 处理 |
|---|---|---|
| `core/eh1f/LICENSE.upstream` | VeeR EH1 core（Apache-2.0，Western Digital） | **已删除** |
| `core/eh1f/fpu/vendor/fpnew/LICENSE.solderpad` | FPnew FPU（Solderpad 0.51，可视为 Apache-2.0） | **已删除** |
| `core/eh1f/fpu/vendor/fpnew/LICENSE.apache` | 同上（附带的 Apache 副本） | **已删除** |
| `core/eh1f/UPSTREAM.md` | 上游来源说明 | **已删除** |

**说明**：这三份 license 对应**实际编译进设计的代码**，删除后对外分发需另行附许可与版权声明（Apache-2.0 / Solderpad 再分发条款）。经确认，来源与许可标注由项目方**在 RTL 目录之外统一维护**，故本目录不再保留这些文件。每个源文件头部仍带 SPDX 头。

---

## 7. 建议的后续行动（供“清洗与过滤”阶段执行）

1. **修复串口中断**：将 `uart_irq`（经 2 级同步后）接入 core 的可用中断源；若资源受限，至少明确“UART 只能轮询”并在 BSP 与文档中固化该约定。
2. **补齐 UART 状态位**（可选）：加 overrun/frame-error 标志，避免静默丢字节。
3. **清理文件**：删除/归档 §6.3 列出的历史 filelist、陈旧 `flist.questa`、废弃配置产物、被遮蔽的 `include/build.h`；§6.4 的三份 license 与 `UPSTREAM.md` 也已删除（来源/许可标注移至 RTL 之外统一维护）。
4. **消除配置歧义**：删除 `defines.h` 这类与 `common_defines.vh` 冲突的遗留生成物，避免后来者误读。
5. **修正文档**：`rtl/README.md:7,9` 中的 `doc/rtl_stage2_integration_review.md` 路径应为 `docs/`；并在迁移 `soc_sim_top.sv` 后更新“尚未迁移”的说明。
6. **时钟一致性**：如需把 core 调到 250 MHz，同步更新 MMCM `CORE_CLKOUT_DIVIDE_F`、`CORE_CLOCK_HZ` 与 `clocks.xdc` 注释；外设保持 50 MHz 时 `PERIPHERAL_CLKOUT_DIVIDE` 与 `PERIPHERAL_CLOCK_HZ` 必须一致。
