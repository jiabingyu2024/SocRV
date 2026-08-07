+incdir+rtl/cpu/include

# Migrated five-stage RV32IMF core.
rtl/cpu/core/pc/pc_reg.sv
rtl/cpu/core/pc/stage_pc.sv
rtl/cpu/core/if/stage_if.sv
rtl/cpu/core/id/imm_unit.sv
rtl/cpu/core/id/regfile.sv
rtl/cpu/core/id/fregfile.sv
rtl/cpu/core/id/control_unit.sv
rtl/cpu/core/id/stage_id.sv
rtl/cpu/core/ex/alu.sv
rtl/cpu/core/ex/branch_cmp.sv
rtl/cpu/core/ex/m_unit.sv
rtl/cpu/core/ex/rv32f_unit.sv
rtl/cpu/core/ex/stage_ex.sv
rtl/cpu/core/m2/stage_m2.sv
rtl/cpu/core/memory/DCache.sv
rtl/cpu/core/wb/stage_wb.sv
rtl/cpu/core/pipeline_regs/reg_pc_if.sv
rtl/cpu/core/pipeline_regs/reg_if_id.sv
rtl/cpu/core/pipeline_regs/reg_id_ex.sv
rtl/cpu/core/pipeline_regs/reg_ex_m1.sv
rtl/cpu/core/pipeline_regs/reg_m1_m2.sv
rtl/cpu/core/pipeline_regs/reg_m2_wb.sv
rtl/cpu/core/control/forward_unit.sv
rtl/cpu/core/control/bpu_top.sv
rtl/cpu/core/control/hazard_unit.sv
rtl/cpu/core/regs/csr_file.sv
rtl/cpu/core/core.sv
rtl/cpu/core/myCPU.sv

# SoC protocol adapters remain inside the CPU subsystem boundary.
rtl/cpu/adapter/hxi_instruction_adapter.sv
rtl/cpu/adapter/pipelined_instruction_adapter.sv
rtl/cpu/adapter/hxi_data_adapter.sv
rtl/cpu/cpu_subsystem.sv
