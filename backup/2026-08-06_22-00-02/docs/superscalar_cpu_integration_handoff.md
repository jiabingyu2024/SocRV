# SocRV superscalar CPU 移植与 FPGA 交付说明

日期：2026-08-06  
状态：RTL、Spike DiffTest、SoC/RT-Thread/CoreMark 仿真、FPGA 实现及 release 校验已通过；等待实体板串口验收。

## 1. 移植结论

`superScalar/` 中可综合的正式 CPU RTL 已整理并移入 `rtl/cpu/superscalar/`，由
`rtl/cpu/cpu_subsystem.sv` 直接实例化 `superscalar_cpu_core`。原
`rtl/cpu/demo/demo_cpu_core.sv` 已从 filelist 移除并删除，删除前备份位于：

```text
backup/2026-08-06_20-56-36/rtl/cpu/demo/demo_cpu_core.sv
```

SoC 侧 `cpu_subsystem` 端口、HXI Crossbar、memory subsystem、Timer、IRQ、APB、UART、
GPIO、TestStatus、SoC top 和 FPGA top 均未为新 CPU 改动。为遵守“CPU 适配现有 SoC”
边界，`data/soc/memory_map.json`、`data/soc/software_contract.json` 及其生成软件文件均保持
原样；正式 core 身份和签核结果由本文及 `docs/rtl_changes.json` 记录。

## 2. 地址与接口适配

地址映射由 SocRV 保持权威，core 读取生成的 package 常量，不保留原教学平台地址：

| 项目 | SocRV 合同 | core 内适配 |
| --- | --- | --- |
| Reset PC | `0x0000_0000` | `RESET_PC = cpu_config_pkg::CPU_RESET_VECTOR` |
| CODE | `0x0000_0000`，64 KiB | I-HXI 从 reset PC 取指；支持可变响应延迟与 redirect 后旧响应丢弃 |
| DATA | `0x1000_0000`，64 KiB | `DRAM_START/END = memory_map_pkg::DATA_BASE/SIZE`，仅该窗口可缓存 |
| MMIO | `0x2000_0000`/`0x3000_0000` 区域 | DATA 窗口外访存走 uncached、提交序约束的 D-HXI 路径 |
| sub-word | HXI 使用 word-aligned address/lane | CPU 边界完成 byte/halfword data 与 strobe lane 对齐 |

对外仍为 Harvard I-HXI + D-HXI，每个 master 最多一笔 outstanding；请求在 backpressure
期间保持稳定。instruction 与 data 访问不同 slave 时仍可由 SocRV Crossbar 并行处理。

中断输入保持 Machine software/timer/external 三路，cause 分别为 3、7、11。commit trace
已适配 SocRV 的单槽退休合同，用于 Spike 比较普通退休、同步异常、访存、CSR 和异步中断。

## 3. 正式 core 内容

有效 RTL 共 30 个 SystemVerilog 文件，包含 frontend/branch predictor、decode、scoreboard、
store buffer/load queue、D-cache、CSR/trap/recovery、RV32M mul/div、性能计数器和 commit trace。

- `MUL_0.sv`：可综合 33×33、3-cycle 流水乘法器。
- `DIV_0.sv`：32 步 unsigned restoring divider；请求到结果精确 34 cycles。
- Verilator 与 Vivado 使用相同的乘除 RTL，不存在仿真零延迟、FPGA 多周期的不一致模型。

## 4. 验证签核

| Gate | 结果 | 证据 |
| --- | --- | --- |
| `make check` | PASS | 环境、依赖、生成物、schema、filelist、memory map、lint |
| `make diff-isa ISA_GATE=final-base JOBS=4` | PASS，64/64 | `build/regression/isa/final-base/summary.json` |
| RV32UI / RV32MI / RV32UM | 41/41、15/15、8/8 | 同上 |
| `make difftest-selftest` | PASS | ORDER/NEXT_PC/GPR/MEM 自检 |
| `make diff-smoke` | PASS | `build/result/soc/baremetal-smoke-diff.json` |
| `make sim-trap-timer` | PASS，53,871 cycles | `build/result/soc/baremetal-trap-timer.json` |
| `make diff-rtthread` | PASS，进入并返回 `msh >` | `build/result/soc/rtthread-smoke-diff.json` |
| `make sim-full` | PASS | final-base、RT-Thread、MSH、CoreMark 10 |
| CoreMark 3 | CRC PASS，5,121,478 ticks | `build/result/soc/rtthread-coremark-command-3.json` |
| CoreMark 10 | CRC PASS，17,070,246 ticks | `build/result/soc/rtthread-coremark-command-10.json` |

CoreMark 10 结束后再次出现 `msh >`。这是短轮功能/趋势运行，不是正式 CoreMark 分数。

## 5. FPGA 产物

执行过：

```text
make software-fpga
make fpga-build PROFILE=rtthread-coremark JOBS=4
make fpga-check PROFILE=rtthread-coremark
```

Vivado 结果：PASS，50 MHz timing met，DRC error 0，DRC warning 46。

```text
build/vivado/kintex7-rtthread-coremark/result.json
build/vivado/kintex7-rtthread-coremark/project/socrv.xpr
build/vivado/kintex7-rtthread-coremark/project/reports/post_impl_timing_summary.rpt
build/vivado/kintex7-rtthread-coremark/project/reports/post_impl_drc.rpt
build/vivado/kintex7-rtthread-coremark/project/socrv.runs/impl_1/fpga_top.bit
```

Bitstream：11,443,717 bytes  
SHA256：`38891bce598cf02c972eb945a6ed4fdb769b2ee174db0f3f0e7b497f4c16427e`

46 条 warning 是 D-cache tag RAM 地址由带异步 reset 的寄存器驱动引发的 `REQP-1840`
风险提示；没有 DRC error，时序已满足。上板时应重点观察复位释放后的首次访存和稳定性。

Release 已通过生成与复核：

```text
build/release/socrv-rtthread-coremark/
build/release/socrv-rtthread-coremark.zip
```

`release-check` 已逐项校验 11 个交付文件。打包使用的 `code.mem` 和 `data.mem` 与完成
Vivado 实现及仿真验证的镜像 SHA256 一致。

## 6. 已知边界

- I-HXI `rsp_err` 会形成 instruction access fault；当前 D-HXI 的异常响应会置位
  `fault_o`。final-base/RT-Thread 回归未覆盖精确的 load/store access-fault 退休路径。
- 当前软件仍按既有 `rv32i_zicsr/ilp32` 编译，以保持 SoC 软件基线不变；CPU 的 RV32M
  能力由 RV32UM Spike DiffTest 独立签核。
- 本轮没有连接实体 FPGA 板，因此不能把 bitstream PASS 等同于板上 UART/CoreMark PASS。

## 7. 上板步骤

```text
make fpga-program PROFILE=rtthread-coremark
```

串口使用 115200、8N1、无流控。依次确认 RT-Thread banner、`msh >`，再执行：

```text
help
ps
socrv_info
coremark 10000
ps
```

保存完整 UART 日志；确认三项 CRC、项目 CRC checker、exact total ticks、返回 `msh >`，
以及第二次 `ps` 仍正常。板上日志和实测 ticks 应放在 release 压缩包旁保存。
