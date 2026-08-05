# CoreMark integration

`upstream/` 是固定版本且不修改的 EEMBC CoreMark v1.01。SocRV 的 timer、UART、
RT-Thread 和命令适配全部位于 `port/`。

项目主 profile 是 `rtthread-coremark`：

- 启动 RT-Thread 和 FinSH/MSH；
- 注册 `coremark [iterations]`；
- 不在 `main()` 中自动运行；
- 默认参数是 10000；
- 使用 64 位 tick，避免 10000 轮累计溢出；
- 完成后返回 shell。

仿真示例：

```text
make sim-coremark COREMARK_ITERATIONS=3
```

FPGA 软件：

```text
make software-fpga
```

板上串口命令：

```text
coremark 10000
```

短仿真用于 CRC 和性能趋势，不满足官方 10 秒规则，不应作为正式分数。
