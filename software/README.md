# Software

`software/` 保存启动、链接脚本、BSP、轻量 runtime、应用、RT-Thread、
riscv-tests 与 CoreMark 适配。第三方 `upstream/` 由 lock 文件管理且不修改；
所有 SocRV 私有代码位于 `port/`、`env/`、`bsp/` 或 `applications/`。

## 硬件合同

权威输入是 `data/soc/memory_map.json` 和
`data/soc/software_contract.json`。以下文件由
`scripts/generate_soc_contract.py` 生成，禁止手改：

- `bsp/include/soc_memory_map.h`
- `bsp/include/soc_config.h`
- `bsp/include/soc_irq.h`
- `bsp/include/soc_registers.h`
- `linker/memory.ldh`

当前固件固定为 `-march=rv32i_zicsr -mabi=ilp32`，CODE 和 DATA 各
64 KiB，分别从 `0x0000_0000`、`0x1000_0000` 开始。

这是 demo core 的当前构建能力，不是最终 CPU 上限。最终整数目标为
RV32IM + Zicsr + Zicntr + Zifencei，必过 RV32UI/RV32MI/RV32UM；浮点在
F 与 FD 中待选。正式核实现相应指令、CSR 和上下文保存前，不得把普通
Profile 的 `-march` 提前改强。

ISA 数据与 gate：

```text
make isa-data
make isa-gates
make sim-isa                 # 当前 demo
make sim-isa-final-base      # 最终整数
make sim-isa-fp-single       # F 候选
make sim-isa-fp-double       # FD 候选
```

## 构建 Profile

从仓库根目录执行：

```text
make software PROFILE=smoke
make software-trap-timer
make software-rtthread
make coremark-smoke
make software-coremark
make coremark-rtthread
```

产物统一位于：

```text
build/software/<profile>/firmware.elf
build/software/<profile>/firmware.map
build/software/<profile>/firmware.dis
build/software/<profile>/firmware.bin
build/software/<profile>/size.json
build/software/<profile>/build_manifest.json
build/images/<profile>/code.mem
build/images/<profile>/data.mem
build/images/<profile>/image.json
```

`firmware.elf` 是权威产物；同一 `image.json` 被 Verilator 和 FPGA
流程消费。构建会检查 ELF section 是否越过 CODE/DATA 边界。

## 外部依赖

```text
make deps
make deps-check
```

该入口统一管理 RT-Thread、riscv-tests 和 CoreMark。正式 CoreMark 分数只
能来自 `coremark-baremetal` 的 FPGA 运行并满足官方迭代/有效性条件；
`coremark-smoke` 只用于快速 CRC 功能验证。
