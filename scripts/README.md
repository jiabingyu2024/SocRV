# Scripts

根 `Makefile` 是稳定的人类入口，`scripts/` 负责参数解析、工具调用、结果
与 manifest。所有路径从脚本自身定位仓库，Verilator/RISC-V GCC 通过 WSL
执行，Vivado 通过 Windows batch launcher 执行。

主要链路：

```text
build_software.py
  -> WSL riscv64-unknown-elf-gcc
  -> elf2mem.py
  -> build/images/<profile>/image.json

run_verilator.py
  -> WSL Verilator build
  -> soc_sim_top
  -> build/verilator/.../result.json

run_regression.py
  -> data/tests/soc.json
  -> build/regression/<suite>/summary.json

run_vivado.py
  -> board Tcl
  -> synth/impl/bitstream
  -> check_fpga_reports.py
```

清理只能通过 `clean.py` 删除 `build/` 下的明确子目录。
