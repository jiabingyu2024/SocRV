# Simulation configuration

- `filelists/soc_verilator.f`：厂商无关 SoC 与仿真顶层
- `filelists/fpga_kintex7.f`：共享 RTL 与 Kintex-7 backend/top
- `verilator/common_flags.f`：统一 Verilator 编译、trace 和 warning 策略

常用入口：

```text
make sim-smoke
make sim-rtthread
make regression
make sim PROFILE=smoke TRACE=1
```
