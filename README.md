# SocRV

SocRV 是面向自研 RV32 CPU、HXI SoC、Verilator 和 Kintex-7 FPGA 的统一工程框架。
最终目标是在 FPGA 上启动 RT-Thread，在 FinSH/MSH 中输入：

```text
coremark 10000
```

仿真使用同一个 `rtthread-coremark` 固件，完整检测到 UART `msh >` 后自动注入
较小轮次命令；可执行 checker 检查 CoreMark CRC、tick、Test Status 和性能窗口，
用于上板前的正确性和性能趋势检查。HXI 保持哈佛双 Master：I/D 各一笔
outstanding，访问不同 Slave 时可并行。

## 快速开始

```text
make help
make deps
make check
make sim-quick
make software-fpga
```

常用单项：

```text
make sim-smoke
make sim-isa ISA_GATE=current
make sim-rtthread
make sim-coremark COREMARK_ITERATIONS=3
```

正式 CPU 完成 RV32IM/Machine Mode 后：

```text
make sim-isa ISA_GATE=final-base
make sim-full
```

`final-base` 包含 RV32UI、RV32MI 和 RV32UM。浮点在 F/FD 方案确定后，分别使用
`fp-single` 或 `fp-double` gate。

FPGA 命令会调用 Vivado，应由用户显式执行：

```text
make fpga-build
make fpga-check
make fpga-program
```

完整操作说明见
[`docs/cpu_iteration_sim_software_fpga_guide.md`](docs/cpu_iteration_sim_software_fpga_guide.md)。

## 目录边界

- `rtl/`：厂商无关、可综合 RTL；
- `tb/`：Testbench 与 C++ harness；
- `sim/`：filelist 与仿真器配置；
- `software/`：启动、BSP、RT-Thread、riscv-tests、CoreMark；
- `fpga/`：板级 RTL、XDC 和 Vivado Tcl；
- `data/`：Memory Map、软件合同、测试清单和 ISA 镜像；
- `scripts/`：构建、运行、检查和结果收集；
- `build/`：全部可重新生成的产物。

## 结果位置

```text
build/software/      ELF、MAP、反汇编和构建 manifest
build/images/        CODE/DATA MEM 和 image.json
build/result/        单次仿真 JSON
build/log/           仿真串口与运行日志
build/wave/          可选 VCD
build/regression/    ISA/测试套件汇总
build/vivado/        Vivado 工程、报告、result.json 和 bitstream
```

当前参考 core 的软件 ISA 是 `rv32i_zicsr/ilp32`。最终整数目标是
RV32IM + Zicsr + Zicntr + Zifencei，并通过 RV32UI/RV32MI/RV32UM；浮点在
F 或 FD 中后续确定。
