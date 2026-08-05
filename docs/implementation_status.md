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
- 仿真通过真实 UART RX 注入 FinSH 命令；
- CoreMark 64 位 tick、CRC 判定和性能窗口；
- Verilator 模型内容指纹；
- 仿真/FPGA 共用 generic ROM/RAM 与可配置响应延迟；
- 简化后的 Make 日常、里程碑、软件和 FPGA 入口。

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

当前参考 core 的软件构建能力仍是 `rv32i_zicsr/ilp32`。最终整数目标不变：

```text
RV32IM + Zicsr + Zicntr + Zifencei
required tests: RV32UI + RV32MI + RV32UM
```

浮点在 F 或 FD 中后续确定。完整 ISA 数据已经准备好，不代表当前参考 core 已通过
最终 gate。

详细操作见
[`cpu_iteration_sim_software_fpga_guide.md`](cpu_iteration_sim_software_fpga_guide.md)。
