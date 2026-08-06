# Software

`software/` 包含启动代码、linker、BSP、RT-Thread port、应用、riscv-tests 和
CoreMark 适配。第三方源码由 `dependency.lock.json` 固定版本，项目不修改
`upstream/`。

## 权威合同

硬件/软件合同位于：

```text
data/soc/memory_map.json
data/soc/software_contract.json
```

修改后运行：

```text
make soc-contract
make isa-data
make check
```

生成的 BSP 头文件和 linker 常量禁止手工维护。

## 主要 profile

| Profile | 用途 |
| --- | --- |
| `smoke` | 裸机基础路径 |
| `trap-timer` | M-mode trap 与 timer IRQ |
| `rtthread` | RT-Thread 启动冒烟 |
| `rtthread-coremark` | 最终 FPGA 固件与 UART 命令仿真 |

构建最终固件：

```text
make software-fpga
```

产物：

```text
build/software/rtthread-coremark/firmware.{elf,map,dis,bin}
build/software/rtthread-coremark/{size.json,build_manifest.json}
build/images/rtthread-coremark/{code.mem,data.mem,image.json}
```

板上进入 `msh >` 后运行：

```text
coremark 10000
```

The same image also contains the SHT30 temperature monitor:

```text
temp_start        # print once per second in a background thread
temp_start 500    # select a 500 ms period
temp_stop         # stop sampling and printing
```

当前参考 core 使用 `rv32i_zicsr/ilp32`。最终整数目标是 RV32IM + Zicsr +
Zicntr + Zifencei，并通过 RV32UI/RV32MI/RV32UM；浮点在 F/FD 中后续确定。
