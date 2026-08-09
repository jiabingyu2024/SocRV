# SocRv RTL implementation

This directory is being rebuilt around a copied VeeR EH1 RTL baseline.

Current stage: B - compressed extension removed from the active instruction path.

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

Stage A is preserved under backup/20260809_160500_eh1_stage_a. The active
Stage-B core advertises the intermediate RV32IM_Zicsr ISA, treats every
instruction as 32 bits, implements precise IALIGN=32 cause-0 traps, and has
no compressed decoder dependency. TCM ECC, PIC, DMA and the upstream wrapper
remain for the next staged edits.

rtl/filelist.f selects rtl/filelist_stage_b.f. The historical Stage-A
filelist is retained as an inventory for the backup snapshot.

The authoritative architecture document is:

    learn/01-yjb/documents/20_veer_eh1_tcm_soc_fpga_rtthread_coremark_migration.md
