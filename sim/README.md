# Simulation configuration

- `filelists/soc_verilator.f`：厂商无关 SoC 与仿真顶层
- `filelists/fpga_kintex7.f`：共享 RTL 与 Kintex-7 backend/top
- `verilator/common_flags.f`：统一 Verilator 编译、trace 和 warning 策略

常用入口：

```text
make sim-isa
make sim-smoke
make sim-rtthread
make sim-rtthread-coremark-smoke
make sim-rtthread-coremark-perf
make sim-required
make regression
make sim PROFILE=smoke TRACE=1
```

Runner 会对 RTL filelist、所列 RTL、C++ Harness、Verilator flags 和工具版本
计算模型指纹。指纹变化时完整重建 `obj_dir`；`--no-rtl-build` 只允许复用
指纹匹配的模型，避免误跑旧 executable。

运行产物按类型分开：

```text
build/result/soc/<test>.json
build/log/soc/<test>.log
build/wave/soc/<test>.vcd
build/regression/<suite>/summary.json
```
