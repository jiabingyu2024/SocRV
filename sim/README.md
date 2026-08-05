# Simulation

常用入口：

```text
make sim-smoke
make sim-isa ISA_GATE=current
make sim-rtthread
make sim-coremark COREMARK_ITERATIONS=3
make sim-quick
make sim-full
```

`sim-coremark` 启动与 FPGA 相同的 `rtthread-coremark` 镜像，再通过 UART RX
逐位注入 `coremark <iterations>\r`。它不是软件 `main()` 的自动调用。

模型指纹覆盖 RTL、递归 filelist、Verilator flags、C++ harness、头文件和工具
版本。输入变化时自动完整重建，避免复用过期模型。

结果：

```text
build/result/soc/<test>.json
build/log/soc/<test>.log
build/wave/soc/<test>.vcd
build/regression/<suite>/summary.json
```

只有定位失败时建议使用 `TRACE=1`。
