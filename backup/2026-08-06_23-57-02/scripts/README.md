# Scripts

根 `Makefile` 是稳定的人类入口，`scripts/` 负责参数解析、工具调用、内容指纹和
结果 manifest。

主要链路：

```text
fetch_dependencies.py
  -> 固定 RT-Thread / riscv-tests / CoreMark

generate_soc_contract.py
  -> Memory Map / 软件合同
  -> BSP 头文件和 linker 常量

generate_isa_data.py
  -> 官方 riscv-tests + SocRV environment
  -> data/isa/

build_software.py
  -> RV32 ELF
  -> code.mem / data.mem / image.json

run_verilator.py
  -> 内容指纹检查与模型构建
  -> 可选 UART 命令注入
  -> result/log/wave

run_regression.py
  -> data/tests/soc.json
  -> build/regression/<suite>/summary.json

run_vivado.py
  -> software image
  -> synth / implementation / bitstream / report gate
```

推荐入口：

```text
make sim-quick
make sim-full
make software-fpga
make fpga-build
```

详细说明见
[`docs/cpu_iteration_sim_software_fpga_guide.md`](../docs/cpu_iteration_sim_software_fpga_guide.md)。
