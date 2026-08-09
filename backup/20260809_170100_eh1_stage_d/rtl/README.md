# SocRv RTL implementation

This directory is being rebuilt around a copied VeeR EH1 RTL baseline.

Current stage: D - fixed-width RV32IM with TCM-only local-MMIO SoC integration.

Frozen target:

- RV32IMF_Zicsr, ilp32f
- no C extension
- 128 KiB ICCM without ECC/parity
- 64 KiB DCCM without ECC/parity
- no instruction/data cache
- no AXI or external memory
- local MMIO timer, UART, GPIO and system control
- CoreMark/MHz > 4.0
- FPGA timing target 250 MHz

Stage A is preserved under backup/20260809_160500_eh1_stage_a and Stage B under
backup/20260809_162200_eh1_stage_b. The active Stage-D core advertises the
intermediate RV32IM_Zicsr ISA, treats every instruction as 32 bits, implements
precise IALIGN=32 cause-0 traps, and uses 128 KiB ICCM plus 64 KiB DCCM arrays
with pure 32-bit storage. Cache RAM, cache diagnostics and active ECC/parity
logic are absent. PIC, DMA, the selected AHB/AXI converters, and the legacy LSU
bus buffer are removed; timer/UART/GPIO/sysctrl are connected through one
commit-safe local MMIO request.

rtl/filelist.f selects rtl/filelist_stage_d.f. Historical stage filelists are
retained as inventories for their backup snapshots.

The authoritative architecture document is:

    learn/01-yjb/documents/20_veer_eh1_tcm_soc_fpga_rtthread_coremark_migration.md
