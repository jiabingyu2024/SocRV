# Stage-D TCM-only local-MMIO SoC integration baseline.
# Paths are relative to the SocRv repository root.

+incdir+rtl/core/eh1f/config/eh1_stage_a
+incdir+rtl/core/eh1f/include
+incdir+rtl/core/eh1f/lib
+incdir+rtl/core/eh1f/dmi

rtl/core/eh1f/include/veer_types.sv
rtl/core/eh1f/lib/beh_lib.sv
rtl/core/eh1f/lib/mem_lib.sv

rtl/core/eh1f/mem.sv

rtl/core/eh1f/ifu/ifu_aln_ctl.sv
rtl/core/eh1f/ifu/ifu_ifc_ctl.sv
rtl/core/eh1f/ifu/ifu_bp_ctl.sv
rtl/core/eh1f/ifu/ifu_mem_ctl.sv
rtl/core/eh1f/ifu/ifu_iccm_mem.sv
rtl/core/eh1f/ifu/ifu.sv

rtl/core/eh1f/dec/dec_decode_ctl.sv
rtl/core/eh1f/dec/dec_gpr_ctl.sv
rtl/core/eh1f/dec/dec_ib_ctl.sv
rtl/core/eh1f/dec/dec_tlu_ctl.sv
rtl/core/eh1f/dec/dec_trigger.sv
rtl/core/eh1f/dec/dec.sv

rtl/core/eh1f/exu/exu_alu_ctl.sv
rtl/core/eh1f/exu/exu_mul_ctl.sv
rtl/core/eh1f/exu/exu_div_ctl.sv
rtl/core/eh1f/exu/exu.sv

rtl/core/eh1f/lsu/lsu_dccm_mem.sv
rtl/core/eh1f/lsu/lsu_dccm_ctl.sv
rtl/core/eh1f/lsu/lsu_clkdomain.sv
rtl/core/eh1f/lsu/lsu_addrcheck.sv
rtl/core/eh1f/lsu/lsu_lsc_ctl.sv
rtl/core/eh1f/lsu/lsu_stbuf.sv
rtl/core/eh1f/lsu/lsu_bus_intf.sv
rtl/core/eh1f/lsu/lsu_trigger.sv
rtl/core/eh1f/lsu/lsu.sv

rtl/core/eh1f/dbg/dbg.sv
rtl/core/eh1f/dmi/dmi_wrapper.v
rtl/core/eh1f/dmi/dmi_jtag_to_core_sync.v
rtl/core/eh1f/dmi/rvjtag_tap.sv

rtl/core/eh1f/veer.sv
rtl/core/eh1f/veer_wrapper.sv

rtl/soc/machine_timer.sv
rtl/soc/uart.sv
rtl/soc/gpio.sv
rtl/soc/sysctrl.sv
rtl/soc/local_peripheral_subsystem.sv
rtl/soc/soc_top.sv
