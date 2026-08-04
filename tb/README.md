# Testbench

`tb/soc/soc_sim_top.sv` 是完整 SoC 仿真顶层，C++ harness 负责时钟、复位、
watchdog、UART 解码、PASS/FAIL 判定、VCD 和 JSON 结果。软件通过
`TEST_STATUS_BASE` 明确结束测试，不依赖深层层次或日志字符串作为唯一判据。

CODE/DATA 镜像使用运行时 plusarg 加载，因此同一 Verilator executable 可
运行 bare-metal 与 RT-Thread profile。
