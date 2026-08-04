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
make isa-regression
make sim-smoke
make sim-trap-timer
make sim-rtthread
make regression
make sim-coremark-smoke
make fpga-bitstream PROFILE=smoke
make fpga-check PROFILE=smoke
```

`sim-smoke` 会编译裸机程序、生成 CODE/DATA 镜像、在 WSL 中构建
Verilator，并运行完整 SoC。`sim-trap-timer` 验证 M-mode ecall 返回和
Timer IRQ。`sim-rtthread` 使用固定到 commit
`ddf52e2cdd977f14fc04035c88672ac204aec713` 的 RT-Thread v5.2.2，并启用
FinSH/MSH。`isa-data` 从锁定官方 riscv-tests 源码按当前 Memory Map
重新生成 40 个 RV32UI 镜像；不再复用上一轮地址布局的二进制。

CoreMark v1.01 同时提供短仿真功能 Profile、裸机 FPGA 正式测量候选 Profile
和 RT-Thread Profile。短仿真结果仅用于 CRC 正确性，不能作为性能分数。

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

## 结果位置

```text
build/software/      ELF、MAP、反汇编
build/images/        CODE/DATA MEM 与 image.json
build/verilator/     模型、单次结果和可选 VCD
build/regression/    回归汇总
build/vivado/        Vivado 工程、报告和 bitstream
build/release/       可校验发布包
```

## 工具

- Verilator 在 WSL2 中运行；
- RISC-V GCC 可在 WSL2 中生成 RV32 ELF；
- Vivado 2023.2 从 Windows 批处理入口运行。

所有脚本从自身位置解析仓库根目录，不依赖调用者当前目录。
