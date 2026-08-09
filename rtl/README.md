# SocRv RTL

有效 RTL 是从 VeeR EH1 精简得到的 TCM-only SoC：RV32IMF_Zicsr、`ilp32f`、无 C、无 cache、无 ECC、无 AXI/AHB 和外部存储器。片上存储为 128 KiB ICCM 与 64 KiB DCCM；本地 MMIO 连接 machine timer、UART、GPIO 和 SYSCTRL。

`rtl/filelist.f` 选择 `rtl/filelist_stage_e.f`。`rtl/core/eh1f/` 保存 core，`rtl/soc/` 保存精简 SoC 外设与互联。FPGA 目标为 250 MHz，CoreMark/MHz 大于 4 是待综合和板上实测关闭的性能门槛。

FPGA 通过 top parameters 固定装载 4 个 ICCM lane 和 8 个 DCCM bank；仿真使用同名 plusargs 动态选择每个测试的十二个镜像文件，不需要为每个固件重新编译 RTL 模型。当前 Stage 2 集成复核已经完成，但旧 `tb/soc/soc_sim_top.sv` 尚未迁移到新的 `soc_top` 接口，不能把 filelist 路径检查通过解释为可编译或可运行。阻塞项和后续入口见 `doc/rtl_stage2_integration_review.md`。

完整设计说明见 `learn/01-yjb/documents/20_veer_eh1_tcm_soc_fpga_rtthread_coremark_migration.md`。
