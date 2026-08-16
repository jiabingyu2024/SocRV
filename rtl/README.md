# SocRV RTL

当前设计使用 `mycpu` 双发射 RV32IMF_Zicsr 核心，ABI 为 `ilp32f`。核心只保留 128 KiB ICCM、64 KiB DCCM 和本地 MMIO 数据通路，不包含指令/数据 cache、ECC、AXI、AHB、DMA、PIC、JTAG 或 DMI。

入口 filelist 为 `rtl/filelist.f`，它引用 `rtl/filelists/soc.f`；核心源文件集中在 `rtl/core/mycpu/`，SoC 外设、跨时钟桥和互联位于 `rtl/soc/`。`rtl/core/mycpu/third_party/fpnew/` 是独立第三方代码，清理脚本不会修改其中的代码、命名或注释。

核心配置集中在 `rtl/core/mycpu/config/mycpu_config.vh`。该文件只保留当前硬件实际引用的流水线、DCCM、ICCM 和分支预测参数。片上 RAM 实现在 `rtl/core/mycpu/memory/`，通用时序与组合 primitive 位于 `rtl/core/mycpu/primitives/`。

FPGA top parameter 固定装载 4 个 ICCM lane 和 8 个 DCCM bank；仿真通过同名 plusarg 为每个测试选择十二个镜像文件。修改 RTL 后应至少运行：

```text
python scripts/check_filelists.py
python scripts/lint_rtl.py
python scripts/run_verilator.py --profile smoke --force-rtl-build
```
