# SocRV scripts

根目录 `Makefile` 是稳定的人类入口，`scripts/` 负责参数检查、工具调用、内存镜像生成以及结果 manifest。当前唯一目标配置是：

- ISA：`RV32IMF_Zicsr`
- ABI：`ilp32f`
- ICCM：128 KiB
- DCCM：64 KiB
- 无 C、无 cache、无 ECC、无 AXI/AHB 外部存储
- FPGA 默认 core 目标频率：100 MHz；外设固定 50 MHz

主要链路：

```text
fetch_dependencies.py
  -> 固定 RT-Thread / riscv-tests / CoreMark 依赖

generate_soc_contract.py
  -> 根据 data/soc/ 生成 BSP 头文件和 linker 常量

generate_isa_data.py
  -> 生成官方 riscv-tests 的 ICCM/DCCM 镜像与 manifest

build_software.py
  -> 编译 RV32 ELF
  -> 生成 ICCM 四个 lane 与 DCCM 八个 bank 的初始化文件

run_verilator.py
  -> 构建/运行 SoC 仿真模型并记录 UART、状态和结果

run_regression.py
  -> 按 data/tests/soc.json 运行受控回归

run_vivado.py
  -> 构建软件镜像、综合、实现、bitstream 与报告门禁
```

推荐入口：

```text
make doctor
make check
make sim-quick
make sim-full
make software-fpga
make fpga-build
```

注意：仓库中旧的 `data/isa/` 或 `build/images/` 只有在 `check_images.py` 同时确认内存映射哈希、CODE/DATA 范围和测试状态地址后才可使用。更改 `data/soc/` 后必须重新生成镜像，不能继续使用旧 `.mem` 文件。
