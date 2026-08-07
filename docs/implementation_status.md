# SocRV framework implementation status

## 当前主链路

```text
RT-Thread + FinSH + CoreMark
  -> RV32 ELF
  -> code.mem / data.mem
  -> soc_sim_top 或 fpga_top
  -> UART 命令 `coremark <iterations>`
```

当前已实现：

- 固定版本 RT-Thread、riscv-tests 和 CoreMark；
- 从官方 riscv-tests 按当前 Memory Map 生成 ISA 数据；
- `current` 与最终 RV32UI/RV32MI/RV32UM、F/FD 候选 gate；
- 统一 `rtthread-coremark` 固件；
- 完整检测 UART `msh >` 后才通过真实 UART RX 注入 FinSH 命令；
- 可执行 UART/CoreMark checker、64 位 tick、CRC 判定和性能窗口；
- I-HXI/D-HXI 每 Master 一笔 outstanding，不同 Slave 可并行；
- Verilator 模型内容指纹；
- 仿真/FPGA 共用 generic ROM/RAM 与可配置响应延迟；
- 简化后的 Make 日常、里程碑、软件和 FPGA 入口。

## 2026-08-05 HXI 与 UART checker 修复

已完成：

- 移除 Crossbar 的全局 `busy`，改为每 Master 和每 Slave 独立占用状态；
- I/D 命中不同 Slave 时可同周期接受，命中同一 Slave 时 per-slave round-robin；
- 移除固定 cycle UART 注入，完整识别 `msh >` 后才发送命令；
- checker 使用实际解码 transcript 判定 UART framing、必需/禁止文本、CoreMark
  迭代次数、三项参考 CRC、精确 tick、Test Status 和性能窗口；
- checker 判定及提示符/命令周期写入单次结果 JSON。

已执行且通过：

```text
python -B scripts/validate_schemas.py
python -B -m unittest discover -s scripts/tests -v
python -B scripts/lint_rtl.py
python -B scripts/run_verilator.py --build-only
make regression SUITE=correctness
make regression SUITE=performance
make sim-isa ISA_GATE=current
```

`current` ISA gate 为 40/40 RV32UI PASS。另做两组负向自检：缺失预期 UART
文本会得到 `checker_failed`；使用错误提示符会得到 `uart_prompt_timeout`，
且 `checker.command_sent=false`。本轮未调用 Vivado。

## 2026-08-04 本轮验证

已执行且通过：

```text
python -B scripts/validate_schemas.py
python -B scripts/build_software.py --profile rtthread-coremark --force
python -B scripts/lint_rtl.py
python -B scripts/run_verilator.py \
  --profile rtthread-coremark \
  --test rtthread-coremark-command-3 \
  --benchmark-iterations 3 \
  --uart-command "coremark 3"
```

3 轮命令仿真结果：

```text
status                  PASS
CoreMark window         7,136,021 cycles
cycles/iteration        2,378,673.67
IPC                     0.313871
simulated window time   0.142720 s @ 50 MHz
```

10 轮 performance regression 也已通过：

```text
CoreMark window         23,786,691 cycles
cycles/iteration        2,378,669.10
IPC                     0.313871
```

结果文件：

```text
build/result/soc/rtthread-coremark-command-3.json
build/log/soc/rtthread-coremark-command-3.log
build/regression/performance/summary.json
```

本轮未调用 Vivado。综合、bitstream 和板上 `coremark 10000` 仍需用户按操作文档
显式执行。

## ISA 状态说明

2026-08-06 已完成 superscalar 正式 core 接入与整数 ISA 签核，当前默认软件构建为：

```text
rv32im_zicsr_zicntr_zifencei / ilp32
required tests: RV32UI + RV32MI + RV32UM
```

final-base Spike DiffTest 65/65、RT-Thread/MSH/CoreMark、50 MHz FPGA timing 与 DRC gate
均已通过。CoreMark 10 的 RV32IM 仿真结果为 6,653,657 exact ticks；UART newline 已输出
CRLF。浮点仍在 F 或 FD 中后续确定。

详细操作见
[`cpu_iteration_sim_software_fpga_guide.md`](cpu_iteration_sim_software_fpga_guide.md)。

## 2026-08-07 RV32IMFD、O3、CoreMark tick 与 FPGA 最终基线

当前正式软硬件基线已经升级为：

```text
ISA/ABI       rv32imfd_zicsr_zicntr_zifencei / ilp32d
optimization  -O3
CPU clock     50 MHz
FPU           FPnew，可综合 RV32F + RV32D，32 x 64-bit FPR
```

CoreMark 命令执行期间暂停 RT-Thread tick，退出性能测量窗口后重新调用
`timer_init_tick(RT_TICK_PER_SECOND)` 恢复节拍。仿真已在同一轮 UART 会话中执行
`coremark 3`、`ps`、`help`，观察到 4 次完整 `msh >`，证明 CoreMark 结束后 shell
能够继续接收输入。短功能运行输出包括：

```text
Total ticks      : 1903972
Total time (secs): 0.038079
Iterations/Sec   : 78.782671
Compiler flags   : O3-rv32imfd_zicsr_zicntr_zifencei-ilp32d-rtthread-command
SocRV CoreMark CRC check PASS
```

RV32D RT-Thread 上下文已保存/恢复全部 FPR 与 FCSR，初始线程栈按 RISC-V ABI
改为 16-byte 对齐。ISA 回归为 86/86 PASS，其中 FP32/FP64 聚焦门禁为 21/21 PASS。

FPnew 的 ADDMUL/CONV 使用输入、内部和输出分布式流水，DIVSQRT/NONCOMP 使用一个
FPnew 定义的流水边界；FPU wrapper 用寄存器 `active_q` 跟踪唯一未完成事务，避免
FPnew 组合 busy 信号反馈到 fence.i/full-flush。最终 Vivado 2023.2 签核结果：

```text
Device          xc7k325tffg900-2
WNS / TNS       +4.615 ns / 0.000 ns
Fail endpoints  0
DRC errors      0
DRC warnings    81
LUT / FF        16639 / 9367
RAMB36 / RAMB18 41 / 1
DSP             15
Bitstream bytes 11443717
SHA-256         34b6306322148758b8097a2ba2a89ddb6ccd5f918e93a094d8521caa6b2ff9e4
```

DRC warning 仅包含配置电压属性、DSP 流水建议和既有 BRAM 异步复位检查；没有
LUTLP-1、Error 或 Critical Warning。bitstream 已准备好，但本次未连接物理开发板，
实际烧写和板上 `coremark 10000` 仍需人工执行。
