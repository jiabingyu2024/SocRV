# SocRv 软件

`software/` 包含启动代码、链接脚本、BSP、RT-Thread port、CoreMark port 和 RISC-V ISA 测试清单。最终工具链合同为：

```text
-march=rv32imf_zicsr
-mabi=ilp32f
```

硬件/软件的权威地址与寄存器定义在：

```text
data/soc/memory_map.json
data/soc/software_contract.json
```

修改合同后运行 `make soc-contract` 重新生成 BSP 头文件和 linker 常量，不要手改生成文件。

主要 profile：

| Profile | 用途 |
| --- | --- |
| `smoke` | 裸机基本路径 |
| `trap-timer` | M-mode trap 与 timer IRQ |
| `rtthread` | RT-Thread 启动与调度 |
| `coremark-smoke` | CoreMark 快速功能检查 |
| `rtthread-coremark` | 最终 RT-Thread + UART 命令固件 |

构建最终固件后会生成 ELF、map、反汇编、构建清单，以及 4 个 ICCM lane 和 8 个 DCCM bank 初始化文件。板上进入 `msh >` 后运行：

```text
coremark 10000
```

CoreMark 运行期间关闭 RT tick，以 250 MHz `mtime` 统计准确周期；结束后重新设置下一次 tick。报告有效的前提是 CRC 通过、编译 flags 与合同一致，并在真实 bitstream 上记录运行时间。
