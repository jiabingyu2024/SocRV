# SocRv RTL

有效 RTL 是从 VeeR EH1 精简得到的 TCM-only SoC：RV32IMF_Zicsr、`ilp32f`、无 C、无 cache、无 ECC、无 AXI/AHB 和外部存储器。片上存储为 128 KiB ICCM 与 64 KiB DCCM；本地 MMIO 连接 machine timer、UART、GPIO 和 SYSCTRL。

`rtl/filelist.f` 选择 `rtl/filelist_stage_e.f`。`rtl/core/eh1f/` 保存 core，`rtl/soc/` 保存精简 SoC 外设与互联。FPGA 目标为 250 MHz，CoreMark/MHz 大于 4 是待综合和板上实测关闭的性能门槛。

完整设计说明见 `learn/01-yjb/documents/20_veer_eh1_tcm_soc_fpga_rtthread_coremark_migration.md`。
