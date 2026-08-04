# Scripts

根 `Makefile` 是稳定的人类入口，`scripts/` 负责参数解析、工具调用、结果
与 manifest。所有路径从脚本自身定位仓库，Verilator/RISC-V GCC 通过 WSL
执行，Vivado 通过 Windows batch launcher 执行。

主要链路：

```text
fetch_dependencies.py
  -> RT-Thread / riscv-tests / CoreMark dependency.lock.json
  -> software/<dependency>/upstream

generate_soc_contract.py
  -> data/soc/{memory_map,software_contract}.json
  -> generated C headers and linker/memory.ldh

build_software.py
  -> software/profiles/<profile>.mk
  -> WSL riscv64-unknown-elf-gcc
  -> elf2mem.py
  -> build/images/<profile>/image.json

generate_isa_data.py
  -> locked official riscv-tests + env/socrv
  -> data/isa/<suite>/<test>/

run_isa_tests.py
  -> current/final-base/fp-single/fp-double/final gate
  -> build/regression/isa/<gate>/summary.json

run_verilator.py
  -> 校验模型内容指纹并按需完整重建
  -> WSL Verilator build
  -> soc_sim_top
  -> build/{result,log,wave}/soc/<test>.*

run_regression.py
  -> data/tests/soc.json
  -> suite/tag 选测、wall timeout、性能窗口参数
  -> build/regression/<suite>/summary.json

run_vivado.py
  -> board Tcl
  -> synth/impl/bitstream
  -> check_fpga_reports.py
```

清理只能通过 `clean.py` 删除 `build/` 下的明确子目录。

`make isa-gates` 不调用仿真器，只显示 gate 状态。`make sim-isa` 运行当前
demo core gate；`make sim-isa-final-base` 对应 RV32UI/RV32MI/RV32UM，
F/FD 候选分别是 `make sim-isa-fp-single` 和
`make sim-isa-fp-double`。浮点配置为 pending 时，完整
`make sim-isa-final` 在启动模型前失败。

最小当前实现验收入口是 `make sim-required`，按顺序运行 RV32UI、裸机 smoke、
RT-Thread、RT-Thread + 1 轮 CoreMark 和 RT-Thread + 10 轮 CoreMark。
短档同时检查上游参考 CRC 与显式 Test Status；长档额外汇总测量窗口的
cycles、commits、IPC、cycles/iteration 和 iterations/sim-second。
