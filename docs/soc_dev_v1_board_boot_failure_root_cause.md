# soc_dev_v1 实板无法启动问题根因分析

## 1. 问题概述

在 CoreMark 性能优化过程中，SoC 的取指通路由原有 HXI 总线访问改为独立的流水取指旁路。修改后的版本在 Verilator 仿真中能够启动 RT-Thread、输出 UART 并运行 CoreMark，但在数字孪生平台实板上没有 UART 启动输出，按 Enter 也没有响应。

同一平台、同一串口链路和同一烧录方法下，已知良品能够正常进入 `msh >`，因此问题位于新版本 SoC，而不是 MobaXterm、hub4com、远端串口或烧录平台。

## 2. 已知良品基线

真正经过实板验证的源码基线是提交：

```text
6811a74 fixed name mismatch and run sync & impl
```

该提交对应的 100 MHz 实现可以正常启动。其取指数据流为：

```text
CPU
  -> hxi_instruction_adapter
  -> HXI crossbar
  -> memory_subsystem
  -> generic_rom
```

后续失败版本将其替换为：

```text
CPU
  -> pipelined_instruction_adapter
  -> SoC/FPGA 顶层专用取指请求与响应端口
  -> generic_rom 专用读口
```

该新通路绕过了已经过实板验证的 HXI 请求、应答和背压路径。

## 3. 排查过程与证据

### 3.1 串口和平台已排除

- 相同 COM51、hub4com、数字孪生平台和板卡可以运行旧 bit。
- hub4com 协商得到 115200、8N1。
- 旧 bit 可以输出 RT-Thread 信息并进入 `msh >`。

因此串口转发、终端设置和远程平台不是根因。

### 3.2 时序违例已排除

`soc_dev_v1.7_100MHz_timing_clean` 的结果为：

```text
WNS  +1.237 ns
TNS   0
WHS  +0.059 ns
THS   0
DRC Error 0
```

该版本实板仍然完全没有 UART 输出，因此故障不是由 175 MHz 或更高频率下的超频及时序违例引起。

### 3.3 “代码 BRAM 合并”已排除为根因

最初观察到代码存储从两个独立 ROM 副本变为一个真双口 BRAM：

```text
旧结构：代码 ROM 32 RAMB36，两个独立的 16 RAMB36 副本
新结构：代码 ROM 16 RAMB36，同一组 BRAM 同时使用 A/B 两个读口
```

为验证这一点，依次进行了以下实验：

1. `v1.8.0` 恢复旧式门控读写法，但 Vivado 后端仍将其合并为 16 块双口代码 BRAM。该版本实板失败，因此它不是有效的 BRAM A/B 对照。
2. `v1.8.1` 声明两份数组，但 Vivado 综合仍将两份数组折叠为同一组双口 BRAM，因此在综合阶段淘汰。
3. `v1.8.2` 使用 `DONT_TOUCH` 和 `KEEP_HIERARCHY` 强制保留两个物理 ROM 副本。

`v1.8.2` 的 routed DCP 审计结果为：

```text
取指 ROM 副本       16 RAMB36，只使用 A 口
代码数据视图副本    16 RAMB36，只使用 A 口
数据 RAM             16 RAMB36
总计                 48 RAMB36

WNS  +0.931 ns
TNS   0
WHS  +0.057 ns
THS   0
DRC Error 0
```

两份代码 ROM 均成功读取同一个 `code.mem`，并在 routed DCP 中保持独立。该版本实板仍然无法启动。

因此可以确定：

> 真双口 BRAM 合并不是实板无法启动的根因。BRAM 数量和端口模式只是与故障版本同时出现的实现差异，而不是造成故障的必要条件。

### 3.4 恢复良品 HXI 取指通路后实板恢复

`v1.9.0` 保留当前 CPU 核心，只将 SoC 外围取指路径恢复为提交 `6811a74` 的 HXI 通路：

```text
CPU
  -> hxi_instruction_adapter
  -> HXI crossbar
  -> memory_subsystem
  -> 单端口 generic_rom
```

该版本结果为：

```text
WSL RT-Thread/UART/msh 回归 PASS
WNS  +0.871 ns
TNS   0
WHS  +0.032 ns
THS   0
DRC Error 0
代码 BRAM 16
数据 BRAM 16
```

`v1.9.0` 实板重新出现 RT-Thread shell，并能够执行 CoreMark。

这个 A/B 结果说明故障随专用流水取指旁路加入而出现，随该旁路撤销而消失；CPU 核心未随 v1.9.0 一起回退。

## 4. 根因结论

### 4.1 已证实的架构级根因

实板无法启动的根因是：

> 新增的 `pipelined_instruction_adapter` 与 SoC/FPGA 顶层专用取指请求、响应旁路没有保持已验证 HXI 取指通路的完整事务语义，在实板综合实现中不能可靠启动 CPU。

故障范围包括：

- `pipelined_instruction_adapter`
- `cpu_subsystem` 新增的专用取指接口
- `soc_core` 对 HXI instruction master 的停用
- `fpga_top`/`soc_top_generic` 新增的顶层取指旁路
- `generic_rom` 新增的专用请求、响应和地址标签接口

该问题不是 CPU CoreMark 算法本身、UART、远程平台、单纯超频或代码 BRAM 双口合并造成的。

### 4.2 最可能的事务级机制

当前专用适配器存在以下高风险行为：

- `fetch_req_valid_o` 直接跟随 CPU 请求，没有独立的请求接受状态和 outstanding transaction 记录。
- 一旦当前响应地址匹配，适配器立即把 ROM 地址切换为 `PC+4`，但该切换不受 `core_rsp_ready_i` 控制。
- 请求端没有 `ready`，无法证明 ROM 已在预期周期接受某个地址。
- 响应是否合法依赖“返回地址等于 CPU 当前 PC”，而 CPU stall、redirect 和响应到达可能同时发生。
- 专用旁路绕开了 HXI crossbar 中已经验证过的请求保持、响应保持和背压约束。

这些行为可能在理想 RTL 仿真中因固定的一周期 ROM 模型而表现正常，但并不构成一个完整、自保持、可背压的硬件事务协议。

目前没有 ILA 或内部信号采样能够指出第一个错误周期，因此上述内容应称为“最可能的事务级机制”，不能进一步武断地归因于某一根信号或某一个 always block。

## 5. 为什么仿真没有发现问题

现有 Verilator 仿真证明了软件镜像、ISA 功能和理想 RTL 时序下的行为正确，但没有证明新专用接口具备完整的硬件协议约束：

- ROM 模型固定为理想的一周期同步响应。
- 请求端没有随机 ready/backpressure。
- 没有针对 stall、redirect、响应返回同周期组合的接口断言。
- 没有检查请求在未被接受时是否保持稳定。
- 没有门级或 post-route 时序仿真覆盖该专用取指接口。

后续若重新实现流水取指，仿真必须增加请求/响应协议断言、随机停顿以及分支重定向压力测试。

## 6. 性能结论

`v1.9.0` 的目的只是恢复实板并完成故障二分。它回到了原始串行 HXI 取指路径，因此不会带来 CoreMark 性能提升。该版本不能作为最终优化成果。

正确的后续方向应是：保留已经实板验证的 HXI 边界，在 HXI instruction adapter 内部增加可验证的顺序预取和响应缓冲，或者定义带 `valid/ready` 的完整流水取指协议。不能继续使用当前没有请求 `ready` 和 outstanding 状态的顶层旁路。

## 7. 同时发现的次要构建问题

`v1.9.0` 是 100 MHz 实现，但实板 CoreMark 输出显示：

```text
clock=175000000 Hz
```

这说明改变 SoC 频率后，软件构建系统复用了先前的 175 MHz 对象文件。原因是频率和 `COREMARK_TICKS_PER_SEC` 等编译参数没有作为对象文件的显式依赖，Make 无法感知仅由配置变量引起的重编译需求。

该问题不会造成 CPU 无法启动，但会导致：

- CoreMark 秒数换算错误；
- RT-Thread timer 配置可能与硬件频率不一致；
- 不同频率 bit 之间复用陈旧软件镜像；
- 不能用当前打印的时间评价频率变化效果。

后续构建不同频率的 bit 时，必须强制 clean/rebuild 软件，或将时钟配置与编译参数哈希纳入对象文件依赖和镜像 manifest 校验。

## 8. 最终结论摘要

```text
已排除：串口平台、烧录链路、单纯超频、setup/hold 违例、代码 BRAM 双口合并

已证实：新增的专用流水取指旁路导致实板无法启动

恢复方法：回到良品提交 6811a74 的 HXI 取指外围通路

当前状态：v1.9.0 可启动，但性能没有提升，只是诊断和恢复版本

附带问题：100 MHz bit 复用了 175 MHz 软件对象，CoreMark 时间显示不可信
```
