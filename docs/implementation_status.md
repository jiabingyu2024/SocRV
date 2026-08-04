# SocRV framework implementation

本文记录设计规划落地后的工程事实；规划依据仍是 `docs/designPlan/`。

## 已打通路径

```text
C / Assembly
  -> WSL RV32 GCC
  -> ELF
  -> CODE/DATA MEM + hash manifest
  -> demo RV32I core
  -> HXI crossbar
  -> BRAM / Timer / IRQ / HXI-to-APB
  -> UART / GPIO / Test Status
  -> Verilator result
  -> Kintex-7 inferred BRAM + MMCM
  -> Vivado synth / place / route / bitstream
```

验证 profile：

- `smoke`：初始化 DATA/BSS、UART、GPIO、Test Status；
- `trap-timer`：M-mode ecall 返回、完整 Trap Frame、machine timer interrupt；
- `rtthread`：RT-Thread v5.2.2、heap、scheduler、线程上下文、timer/software
  interrupt、FinSH/MSH、UART 和 Test Status；
- `coremark-smoke`：裸机短迭代与官方 CRC；
- `coremark-rtthread`：RT-Thread 下 1 iteration CoreMark，检查官方 CRC、
  Test Status 和 MMIO 测量窗口；
- `coremark-rtthread-perf`：RT-Thread 下 10 iterations CoreMark，检查正确性
  并统计 cycle/commit/IPC；
- `coremark-baremetal`：50 MHz Timer、2000 iterations 的 FPGA 正式测量候选。

官方 riscv-tests 已固定到
`447a5fcb8253627ddb5f6a226f64e43463afcdd5`。当前 `data/isa` 由该源码
及锁定的 `riscv-test-env` 子模块按 SocRV Memory Map 生成。数据集包含
RV32UI 41、RV32MI 16、RV32UM 8、RV32UF 11、RV32UD 10，共 86 个镜像。
已有的 40/40 Verilator 结果只属于 RV32I demo gate，不表示最终核已经通过
RV32MI、RV32UM 或浮点测试。

最终 CPU 目标为 RV32IM + Zicsr + Zicntr + Zifencei，必过
RV32UI/RV32MI/RV32UM；浮点后续在 F 与 FD 中选择，对应 RV32UF 或 RV32UD。
完整 final gate 在选择前保持阻塞，现有软件仍以
`-march=rv32i_zicsr -mabi=ilp32` 构建。

2026-08-04 的回归结果：

```text
smoke/BSP/RT-Thread     3/3 PASS
CoreMark functional    2/2 PASS，crcfinal 0xe714
RV32UI demo gate        40/40 PASS
RT-Thread CoreMark 1it  window 2,378,755 cycles，IPC 0.313869
RT-Thread CoreMark 10it window 23,786,681 cycles，2,378,668.1 cycles/it，
                        IPC 0.313871
coremark-baremetal FPGA timing met，DRC 0 error
```

CoreMark 仿真 Profile 为缩短 RTL 验证时间使用合成
`COREMARK_TICKS_PER_SEC=1`，但 Harness 的窗口秒数按实际 50 MHz SoC cycle
换算。因此这些数字可做同配置下的简单仿真对比，不作为官方 CoreMark 分数。

## TB/Sim 当前实现

当前五条验收入口是：

```text
make sim-isa
make sim-smoke
make sim-rtthread
make sim-rtthread-coremark-smoke
make sim-rtthread-coremark-perf
```

`make sim-required` 顺序运行以上全部入口。它们共用 `soc_sim_top` 和同一个
Verilator executable；运行时切换 CODE/DATA 镜像。C++ Harness 已拆分为
config、control、UART、result、performance 和 DUT adapter。模型 manifest
对 RTL、filelist、flags、Harness 和 Verilator 版本做内容指纹，输入变化时
完整重建，`--no-rtl-build` 不允许复用过期模型。

## CPU 替换边界

`cpu_subsystem` 是唯一 CPU 集成边界。未来正式 core 不得让 SoC 反向依赖
其内部模块；取指和数据访问都通过 HXI，interrupt 与 commit trace 使用稳定
端口。

## FPGA 已知非阻塞告警

当前板卡参考约束未提供 configuration bank 电压事实，因此 Vivado 保留
`CFGBVS-1` warning。SoC 中仍有异步断言复位的外设控制寄存器；综合优化后，
部分共享控制逻辑会驱动推断 BRAM 的 enable，Vivado 因而报告
`REQP-1839` warning。当前实现共 22 条 DRC warning、0 条 DRC error，且时序
约束满足。正式上板前应由板卡原理图确认 `CFGBVS/CONFIG_VOLTAGE`；后续正式
CPU 和新增控制逻辑应优先使用同步功能复位。
