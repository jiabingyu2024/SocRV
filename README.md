# SocRV

SocRV 是一套面向 RV32 CPU、HXI SoC、Verilator 和 Xilinx FPGA 的工程框架。

当前设计依据位于 [`docs/designPlan/`](docs/designPlan/)。项目约束：

- `rtl/` 只放厂商无关、可综合设计；
- `tb/` 保存 Testbench、Harness 和仿真模型；
- `sim/` 保存 filelist、工具配置和回归清单；
- `software/` 保存启动、BSP、RT-Thread 和应用；
- `fpga/` 保存板级 RTL、XDC、Vivado Tcl 和 Xilinx Wrapper；
- `data/` 保存受控输入；
- `build/` 保存全部可删除生成物。

## 快速开始

```text
make help
make deps
make check
make isa-data
make isa-gates
make sim-isa
make sim-smoke
make sim-trap-timer
make sim-rtthread
make sim-rtthread-coremark-smoke
make sim-rtthread-coremark-perf
make sim-required
make fpga-bitstream PROFILE=smoke
make fpga-check PROFILE=smoke
```

`sim-smoke` 会编译裸机程序、生成 CODE/DATA 镜像、在 WSL 中构建
Verilator，并运行完整 SoC。`sim-trap-timer` 验证 M-mode ecall 返回和
Timer IRQ。`sim-rtthread` 使用固定到 commit
`ddf52e2cdd977f14fc04035c88672ac204aec713` 的 RT-Thread v5.2.2，并启用
FinSH/MSH。`isa-data` 从锁定官方 riscv-tests 源码按当前 Memory Map
重新生成 RV32UI、RV32MI、RV32UM、RV32UF 和 RV32UD 共 86 个镜像；
不再复用上一轮地址布局的二进制。`sim-isa` 仍是当前 demo core 的快速门；
最终整数门为 `sim-isa-final-base`，浮点可分别试跑
`sim-isa-fp-single`/`sim-isa-fp-double`。F/FD 未选择前，
`sim-isa-final` 会明确阻塞。

CoreMark v1.01 同时提供裸机短仿真、RT-Thread 1 轮正确性、RT-Thread
10 轮简单性能仿真和裸机 FPGA 正式测量候选 Profile。仿真由软件通过
Test Status MMIO 标记精确测量窗口，结果给出 cycles、commits、IPC 和
cycles/iteration；其合成 tick 配置只服务于 RTL 仿真，不能作为官方分数。

FPGA 默认目标是 `xc7k325tffg900-2`，输入差分时钟 200 MHz，SoC 时钟
50 MHz。Vivado 的工程、报告与 bitstream 全部进入
`build/vivado/kintex7-<profile>/`。

## 替换 CPU Core

当前 `rtl/cpu/demo/demo_cpu_core.sv` 是验证框架用的多周期 RV32I+Zicsr
参考核。正式 CPU 只需在 `rtl/cpu/cpu_subsystem.sv` 内替换实例，并保持：

- instruction/data 两个 HXI master；
- software/timer/external 三路 machine interrupt；
- `commit_trace_t` 调试边界；
- active-low synchronous-use reset 语义。

SoC、Software、Verilator harness 和 FPGA 顶层不依赖 demo core 的内部层次。
正式核目标为 RV32IM + Zicsr + Zicntr + Zifencei，必须通过 RV32UI、
RV32MI、RV32UM；浮点后续在 F 与 FD 中选择，并分别以 RV32UF/RV32UD
验收。现有软件 Profile 在正式核支持前继续使用 `rv32i_zicsr/ilp32`。

## 结果位置

```text
build/software/      ELF、MAP、反汇编
build/images/        CODE/DATA MEM 与 image.json
build/verilator/     模型与模型内容指纹
build/result/        单次仿真 JSON
build/log/           单次仿真日志
build/wave/          可选 VCD
build/regression/    回归汇总
build/vivado/        Vivado 工程、报告和 bitstream
build/release/       可校验发布包
```

## 工具

- Verilator 在 WSL2 中运行；
- RISC-V GCC 可在 WSL2 中生成 RV32 ELF；
- Vivado 2023.2 从 Windows 批处理入口运行。

所有脚本从自身位置解析仓库根目录，不依赖调用者当前目录。
