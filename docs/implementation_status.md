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
- `coremark-rtthread`：RT-Thread 下的 CoreMark 功能运行；
- `coremark-baremetal`：50 MHz Timer、2000 iterations 的 FPGA 正式测量候选。

官方 riscv-tests 已固定到
`447a5fcb8253627ddb5f6a226f64e43463afcdd5`。当前 `data/isa` 由该源码
按 SocRV Memory Map 生成，40 个 RV32UI 用例全部通过 Verilator。

2026-08-04 的回归结果：

```text
smoke/BSP/RT-Thread     3/3 PASS
CoreMark functional    2/2 PASS，crcfinal 0xe714
RV32UI                  40/40 PASS
coremark-baremetal FPGA timing met，DRC 0 error
```

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
