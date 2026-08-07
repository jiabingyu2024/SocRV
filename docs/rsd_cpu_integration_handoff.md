# SocRV RSD CPU 迁移与上板交付说明

## 当前正式基线

SocRV 已采用 RSD 乱序 CPU，原 superscalar 与 demo CPU 不再参与活动 RTL。CPU 与 SoC 之间采用方案三：RSD ICache 和 DCache 边界分别连接现有 `instr_hxi` 与 `data_hxi`。SoC 顶层端口、Crossbar、外设和地址映射均未改变。

```text
ISA          RV32IMF + Zicsr + Zicntr + Zifencei
ABI          ilp32f
optimization -O3
floating     IEEE-754 single precision
clock        50 MHz
```

地址合同：

```text
reset/CODE  0x00000000, 64 KiB
DATA        0x10000000, 64 KiB
TIMER       0x20000000
UART/APB    继续使用 SocRV 原地址映射
```

## 数据通路

```text
RSD ICache -> rsd_icache_hxi_adapter -> instr_hxi -> SocRV Crossbar
RSD DCache -> rsd_dcache_hxi_adapter -> data_hxi  -> SocRV Crossbar
```

可缓存 CODE/DATA 访问继续使用 SocRV BRAM；MMIO 通过 D-HXI 以 uncached、顺序方式访问。RV32M 与 FP32 均由 RSD RTL 综合，不需要在 Vivado Tcl 中创建独立乘法、除法或 FPU IP。Vivado Tcl 递归读取活动 RTL filelist，因此仿真和 FPGA 使用同一套 CPU 源码。

## 已完成验证

- Verilator RTL lint：PASS。
- RV32UM：8/8 PASS；RV32UF：11/11 PASS。
- RT-Thread 启动、FinSH `help/ps/uptime`：PASS。
- CoreMark 3：CRC PASS，950939 ticks，0.019019 秒；结束后 `ps/help` 可继续输入。
- CoreMark 性能窗口：951042 cycles、899616 commits、IPC 0.945926678。
- 紧邻 `sb -> lbu/lb` O3 微测试：PASS。
- Vivado 2023.2 综合、实现、时序、DRC、bitstream：PASS。

FPGA 签核数据：

```text
device          xc7k325tffg900-2
WNS / TNS       +4.370 ns / 0.000 ns
failing paths   0
DRC errors      0
DRC warnings    66
LUT / FF        26322 / 13228
RAMB36 / RAMB18 36 / 25
DSP             18
bitstream SHA   11e55ae5beacf2369b03d9d2210c033403160d978c308cc7e01413b6a621cd94
```

## 上板文件与命令

bitstream：

```text
build/vivado/kintex7-rtthread-coremark/project/socrv.runs/impl_1/fpga_top.bit
```

烧写前检查：

```text
make fpga-check PROFILE=rtthread-coremark
make fpga-program PROFILE=rtthread-coremark
```

串口使用 115200、8-N-1、无流控。看到 `msh >` 后执行：

```text
help
ps
coremark 10000
ps
```

## 尚未收口的 RSD 兼容项

官方 ISA 集合中仍有 8 项未通过：`fence_i`、`csr`、`illegal`、`instret_overflow`、`ma_fetch`、`pmpaddr`、`scall`、`shamt`。它们属于 RSD 原始特权/异常语义与当前 SocRV 测试合同的差异，不影响本轮已通过的 RV32M、RV32F、RT-Thread、CoreMark 和 bitstream 生成，但在把 CPU 宣称为完整 ISA 签核前仍应继续修复。
