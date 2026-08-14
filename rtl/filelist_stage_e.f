# Stage-E RV32IMF_Zicsr TCM-only local-MMIO SoC integration baseline.
# Paths are relative to the SocRv repository root.

+incdir+rtl/core/eh1f/config/eh1_stage_a
+incdir+rtl/core/eh1f/include
+incdir+rtl/core/eh1f/lib
+incdir+rtl/core/eh1f/dmi
+incdir+rtl/core/eh1f/fpu/vendor/fpnew

# EH1 configuration macros are a global compilation-unit input and must be
# parsed before veer_types and all implementation modules.
rtl/core/eh1f/config/eh1_stage_a/common_defines.vh

rtl/soc/soc_memory_map_pkg.sv

rtl/core/eh1f/fpu/vendor/fpnew/common_cells/cf_math_pkg.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_pkg.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/defs_div_sqrt_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/common_cells/lzc.sv
rtl/core/eh1f/fpu/vendor/fpnew/common_cells/rr_arb_tree.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/control_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/iteration_div_sqrt_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/norm_div_sqrt_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/nrbd_nrsc_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/preprocess_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/div_sqrt_top_mvp.sv
rtl/core/eh1f/fpu/vendor/fpnew/divsqrt/div_sqrt_mvp_wrapper.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_rounding.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_classifier.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_fma.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_fma_multi.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_cast_multi.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_noncomp.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_divsqrt_multi.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_opgroup_fmt_slice.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_opgroup_multifmt_slice.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_opgroup_block.sv
rtl/core/eh1f/fpu/vendor/fpnew/src/fpnew_top.sv

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

rtl/core/eh1f/fpu/eh1_fpr_ctl.sv
rtl/core/eh1f/fpu/eh1_fpu.sv
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

rtl/soc/soc_clock_bridge.sv
rtl/soc/machine_timer.sv
rtl/soc/uart.sv
rtl/soc/gpio.sv
rtl/soc/sysctrl.sv
rtl/soc/i2c_master.sv
rtl/soc/local_peripheral_subsystem.sv
rtl/soc/soc_top.sv
