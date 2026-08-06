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

当前参考 core 的软件构建能力仍是 `rv32i_zicsr/ilp32`。最终整数目标不变：

```text
RV32IM + Zicsr + Zicntr + Zifencei
required tests: RV32UI + RV32MI + RV32UM
```

浮点在 F 或 FD 中后续确定。完整 ISA 数据已经准备好，不代表当前参考 core 已通过
最终 gate。

详细操作见
[`cpu_iteration_sim_software_fpga_guide.md`](cpu_iteration_sim_software_fpga_guide.md)。
