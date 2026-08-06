# Simulation

The retirement-level Spike DiffTest implementation and commands are documented
in [`../docs/difftest_spike_integration_and_debug_guide.md`](../docs/difftest_spike_integration_and_debug_guide.md).

常用入口：

```text
make sim-smoke
make sim-isa ISA_GATE=current
make sim-rtthread
make sim-msh
make sim-coremark COREMARK_ITERATIONS=3
make sim-quick
make sim-full
```

`sim-coremark` 启动与 FPGA 相同的 `rtthread-coremark` 镜像，再通过 UART RX
逐位解码 DUT 输出；只有完整检测到 `msh >` 后才注入
`coremark <iterations>\r`。它不是固定 cycle 盲发，也不是软件 `main()` 的
自动调用。UART/CoreMark checker 会检查 transcript、三项参考 CRC、精确 tick、
Test Status 和性能窗口，判定写入结果 JSON 的 `checker` 对象。

`sim-msh` 加载与上板相同的 `rtthread-coremark` 镜像，通过真实 UART RX 分别
执行 `help`、`ps` 和 `uptime`。每个用例都要求命令结束后重新出现 `msh >`，
并检查帮助表、线程表或 tick 输出，防止命令只被编译却没有正确注册或执行。

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
