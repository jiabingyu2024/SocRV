# SoC/FPGA 100 MHz + 50 MHz 静态审查

日期：2026-08-10  
范围：仅阅读 RTL、XDC、Vivado Tcl 与软硬件时钟契约；功能结论以已经完成的 Verilator 回归为前置条件。本阶段未修改功能 RTL。

## 结论

当前设计具备进入 Kintex-7、core 100 MHz 上板验证的基本条件：core 与外设时钟均来自同一 MMCM，外设固定为 50 MHz；MMIO 使用单 outstanding 的 toggle/bundled-data 握手；外设复位在 50 MHz 域同步释放；timer/software IRQ 以电平方式同步到 core 域。未发现阻止生成 bitstream 或首次上板的 SoC 级静态 blocker。

仍需以本次实现后的 Vivado timing、DRC 和 CDC 报告作为最终 FPGA 签核证据。UART RX 和 GPIO 输入虽然都有两级采样，但同步寄存器未标记 `ASYNC_REG`，属于非阻塞的可靠性/方法学改进项；`test_status/test_code` 是 held-level 调试总线，不提供任意时刻的多位原子快照。

## 逐项审查

### 时钟与复位

- 200 MHz 差分输入经 `IBUFDS` 进入 `MMCME2_BASE`，VCO 为 1 GHz。
- `CLKOUT0_DIVIDE_F=10.0` 产生 100 MHz core clock；`CLKOUT1_DIVIDE=20` 固定产生 50 MHz peripheral clock；两个输出分别经过 `BUFG`。
- core reset 由 MMCM `LOCKED` 异步拉低、在 core 时钟域通过三级寄存器同步释放。
- peripheral reset 由 core reset 异步拉低、在 50 MHz 域通过两级寄存器同步释放。因此两个域都不会在本域时钟边沿之外释放复位；外设会比 core 晚若干周期启动，MMIO bridge 可保存这段时间内的首个 core 请求。
- 两个时钟是同一 MMCM 的相关输出。XDC 有 200 MHz 主时钟，Vivado会从 MMCM 自动推导两个 generated clock；未使用 `set_clock_groups -asynchronous`，因此 bundled payload 路径不会被错误切断。

### MMIO CDC bridge

- core 域只允许一个请求在途：地址、写数据、字节使能和读写属性先锁存，再翻转 request toggle，并在响应到达前保持不变。
- peripheral 域对 toggle 和 payload 各采样两拍；检测到新 toggle 后再把已经稳定的 payload 装入本域请求寄存器。请求保持有效直到外设返回 `ready`。
- 读数据和 error 在 peripheral 域锁存后更新 response toggle；core 域两拍采样响应，toggle 匹配后才向 EH1 返回 `ready`。
- 协议与 EH1 blocking local-MMIO 的“请求保持到完成”用法一致。请求/响应 payload 的稳定窗口覆盖 toggle 同步延迟，回归中已覆盖 UART、timer、SYSCTRL 访问。
- reset toggle 初值在两个域均为 0，统一复位断言时不会产生伪请求；core 先释放、peripheral 后释放时，core 已锁存的请求仍会在 peripheral 启动后被观察到。

### 中断和状态跨域

- machine timer IRQ 与 software IRQ 都是寄存器保持的电平信号，经两级 `ASYNC_REG` 同步到 core 域，不依赖捕获窄脉冲；同步延迟只增加 2–3 个 core 周期。
- EH1 只有直接 machine-timer 输入，当前 timer/software IRQ 合并到 cause 7；BSP 先读取 pending 来源再分派。这是既有架构契约，不是本次 CDC 引入的歧义。
- UART IRQ 当前未接入 core，不存在未处理的 UART IRQ CDC。
- `test_status/test_code` 在 core 域两拍采样。软件写完后持续保持，适合 PASS/FAIL 与板级显示；它们不是带握手的多位 CDC，总线变化瞬间可能出现短暂非原子值，但 PASS/FAIL 使用精确 magic value 解码，稳定后才会命中，不影响正常完成判定。

### 外设与板级 I/O

- UART、GPIO、machine timer、SYSCTRL 的全部状态机/寄存器都运行在固定 50 MHz 域。
- UART divider 的硬件参数与 BSP 均按 50 MHz 计算；TX empty 同时要求 FIFO 为空且 serializer idle，避免 flush 提前完成。
- UART RX 有两级采样后才进入接收状态机；GPIO input 也有两级采样。两处寄存器尚未标记 `ASYNC_REG`，建议后续加属性并通过 `report_cdc`/methodology report 固化检查，但不阻止当前首次上板。
- GPIO output/OE 由 50 MHz 寄存器直接驱动 board wrapper；board wrapper 仅作组合映射，不会把 GPIO 输出重新采入 core 域。

### 工程入口与参数传递

- FPGA filelist 已包含 `soc_clock_bridge.sv`、双时钟顶层与板级 clock/reset wrapper；filelist 检查通过。
- `run_vivado.py --core-mhz 100` 向 Tcl 传入 `SOCRV_CORE_DIVIDE=10.0` 和 `SOCRV_CORE_HZ=100000000`。
- Tcl 将两个值设为 `fpga_top` generics，12 个 ICCM/DCCM 初始化文件也在建工程前逐个检查存在性。
- bitstream gate 要求实现后 timing 全部满足、DRC 中无 Error/Critical Warning，并记录 bitstream SHA-256。

## 已有验证证据

- schema、filelist、memory-map、generated-tree 检查：PASS。
- Verilator build/lint：PASS；仅有 EH1/FPnew 既有 warning。
- smoke、trap-timer、RT-Thread 启动、final-base ISA 回归：PASS。
- RT-Thread CoreMark command-1：PASS，CRC PASS，无 UART framing error。

## 上板前签核清单

1. 用 `rtthread-coremark` profile、core 100 MHz 重新完整执行 synthesis、implementation、write_bitstream。
2. 确认 `post_impl_timing_summary.rpt` 显示所有用户时序约束满足，并记录 WNS/TNS。
3. 确认 `post_impl_drc.rpt` 无 Error/Critical Warning。
4. 阅读 `post_synth_cdc.rpt`：重点核对 MMIO toggle/payload、IRQ、UART RX、GPIO input 与调试状态总线；不接受新增的未知或不安全控制 CDC。
5. 上板首先核对 MMCM lock、UART 115200 8-N-1、PASS/FAIL LED，再运行 CoreMark 命令。
