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

切换到 RV32IM 前，3 轮命令仿真结果为：

```text
status                  PASS
CoreMark window         7,136,021 cycles
cycles/iteration        2,378,673.67
IPC                     0.313871
simulated window time   0.142720 s @ 50 MHz
```

切换到 RV32IM、O2、50 MHz 后，10 轮 performance regression 通过：

```text
CoreMark window          9,885,635 cycles
cycles/iteration           988,563.50
iterations/second            50.5784 @ 50 MHz
IPC                          0.316965
CRC check                 PASS
```

与 RV32I 的 10 轮窗口相比，周期数下降约 58.4%，速度约为原来的 2.41 倍；
`coremark 10000` 的线性预计时间由约 7 分 56 秒降到约 3 分 18 秒。

当前全国赛整数配置使用 RV32IM、O3、100 MHz，并关闭软件合同未要求的 F
执行单元。10 轮端到端回归结果：

```text
CoreMark window          9,449,972 cycles
cycles/iteration           944,997.20
iterations/second           105.8204 @ 100 MHz
IPC                          0.317322
CRC check                 PASS
```

相对 RV32IM/O2/50 MHz 版本，O3 减少约 4.4% 周期，时钟翻倍后总吞吐提升约
2.09 倍；`coremark 10000` 的线性预计时间约为 94.5 秒。

结果文件：

```text
build/result/soc/rtthread-coremark-o3-100mhz-no-f-command-10.json
build/log/soc/rtthread-coremark-o3-100mhz-no-f-command-10.log
build/vivado/kintex7-100mhz-rtthread-coremark/result.json
```

100 MHz Vivado 实现通过：WNS `+0.959 ns`、TNS 0、DRC Error 0，并已生成
bitstream。板上 `coremark 10000` 仍需按操作文档实测。

## ISA 状态说明

当前 core 的软件构建已提升为
`rv32im_zicsr_zicntr_zifencei/ilp32`：

```text
RV32IM + Zicsr + Zicntr + Zifencei
required tests: RV32UI + RV32MI + RV32UM
```

RV32UM 的 8 项乘除法测试均已通过；RT-Thread 和 CoreMark 也使用相同的 M 扩展
编译目标。浮点在 F 或 FD 中后续确定，完整最终 gate 仍需等待浮点方案确定。

详细操作见
[`cpu_iteration_sim_software_fpga_guide.md`](cpu_iteration_sim_software_fpga_guide.md)。
