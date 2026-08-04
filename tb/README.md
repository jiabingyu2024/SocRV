# Testbench

当前全部软件验收流共用 `tb/soc/soc_sim_top.sv`。40 个 RV32UI 用例在该顶层
已经足够快，因此本阶段没有另建一套 `cpu_sim_top`，避免复制镜像加载、
Test Status 和结果协议。模块级 BFM、DiffTest 或缓存专项验证出现后，再按
设计文档补 `unit_sim_top`/`cpu_sim_top`。

C++ Harness 位于 `tb/cpp/`：

```text
soc_main.cpp                  只组合各组件
common/sim_config.*           解析并校验运行参数
common/sim_control.*          reset、主循环、watchdog、结束判定
common/uart_decoder.*         UART Host 解码
common/perf_stats.*           commit 与 CoreMark 测量窗口统计
common/sim_result.*           JSON 结果和退出码
adapter/soc_dut_adapter.*     唯一知道 Vsoc_sim_top 端口的层
```

软件通过 `TEST_STATUS_BASE` 明确结束测试，不依赖深层层次或 UART 文本作为
唯一判据。CoreMark 在同一寄存器的 CODE 字段发送 start/stop magic，
Harness 据此统计周期和提交指令。CODE/DATA 镜像使用运行时 plusarg 加载，
同一个 Verilator executable 可运行 ISA、bare-metal、RT-Thread 与 CoreMark。
