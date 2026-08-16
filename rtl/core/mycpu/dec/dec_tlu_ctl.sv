// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.


module dec_tlu_ctl
   import mycpu_types::*;
(
   input logic clk,
   input logic active_clk,
   input logic free_clk,
   input logic rst_l,
   input logic scan_mode,

   input logic [31:1] rst_vec,
   input logic        nmi_int,
   input logic [31:1] nmi_vec,
   input logic  i_cpu_halt_req,
   input logic  i_cpu_run_req,

   input logic mpc_debug_halt_req,
   input logic mpc_debug_run_req,
   input logic mpc_reset_run_req,


   input logic [1:0] ifu_pmu_instr_aligned,
   input logic       ifu_pmu_align_stall,
   input logic       ifu_pmu_fetch_stall,
   input logic       ifu_pmu_fetch_miss,
   input logic       ifu_pmu_fetch_hit,
   input logic       ifu_pmu_bus_error,
   input logic       ifu_pmu_bus_busy,
   input logic       ifu_pmu_bus_trxn,
   input logic [1:0] dec_pmu_instr_decoded,
   input logic       dec_pmu_decode_stall,
   input logic       dec_pmu_presync_stall,
   input logic       dec_pmu_postsync_stall,
   input logic       lsu_freeze_dc3,
   input logic       lsu_store_stall_any,
   input logic       exu_pmu_i0_br_misp,
   input logic       exu_pmu_i0_br_ataken,
   input logic       exu_pmu_i0_pc4,
   input logic       exu_pmu_i1_br_misp,
   input logic       exu_pmu_i1_br_ataken,
   input logic       exu_pmu_i1_pc4,
   input logic       lsu_pmu_bus_trxn,
   input logic       lsu_pmu_bus_misaligned,
   input logic       lsu_pmu_bus_error,
   input logic       lsu_pmu_bus_busy,

   input    lsu_error_pkt_t lsu_error_pkt_dc3,
   input logic         lsu_single_ecc_error_incr,

   input logic lsu_load_ecc_stbuf_full_dc3,

   input logic dec_pause_state,
   input logic         lsu_imprecise_error_store_any,
   input logic         lsu_imprecise_error_load_any,
   input logic [31:0]  lsu_imprecise_error_addr_any,
   input logic         lsu_freeze_external_ints_dc3,

   input logic        dec_csr_wen_unq_d,
   input logic        dec_csr_any_unq_d,
   input logic        dec_csr_wen_wb,
   input logic [11:0] dec_csr_rdaddr_d,
   input logic [11:0] dec_csr_wraddr_wb,
   input logic [31:0] dec_csr_wrdata_wb,
   input logic        dec_csr_stall_int_ff,

   input logic dec_tlu_i0_valid_e4,
   input logic dec_tlu_i1_valid_e4,

   input logic dec_i0_load_e4,

   input logic [31:1] exu_npc_e4,
   input logic exu_i0_flush_lower_e4,
   input logic exu_i1_flush_lower_e4,
   input logic [31:1] exu_i0_flush_path_e4,
   input logic [31:1] exu_i1_flush_path_e4,
   input logic exu_i0_inst_misaligned_e4,
   input logic exu_i1_inst_misaligned_e4,
   input logic [31:1] exu_i0_inst_misaligned_addr_e4,
   input logic [31:1] exu_i1_inst_misaligned_addr_e4,

   input logic [31:1] dec_tlu_i0_pc_e4,
   input logic [31:1] dec_tlu_i1_pc_e4,

   input trap_pkt_t dec_tlu_packet_e4,

   input logic [31:0] dec_illegal_inst,
   input logic        dec_i0_decode_d,


   input logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i0_br_index_e4,
   input logic [1:0]  exu_i0_br_hist_e4,
   input logic [1:0]  exu_i0_br_bank_e4,
   input logic        exu_i0_br_error_e4,
   input logic        exu_i0_br_start_error_e4,
   input logic        exu_i0_br_valid_e4,
   input logic        exu_i0_br_mp_e4,
   input logic        exu_i0_br_middle_e4,
   input logic [`RV_BHT_GHR_RANGE]  exu_i0_br_fghr_e4,


   input logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i1_br_index_e4,
   input logic [1:0]  exu_i1_br_hist_e4,
   input logic [1:0]  exu_i1_br_bank_e4,
   input logic        exu_i1_br_error_e4,
   input logic        exu_i1_br_start_error_e4,
   input logic        exu_i1_br_valid_e4,
   input logic        exu_i1_br_mp_e4,
   input logic        exu_i1_br_middle_e4,
   input logic [`RV_BHT_GHR_RANGE]  exu_i1_br_fghr_e4,

   input logic        exu_i1_br_way_e4,
   input logic        exu_i0_br_way_e4,


   output logic dec_dbg_cmd_done,
   output logic dec_dbg_cmd_fail,
   output logic dec_tlu_flush_noredir_wb ,
   output logic dec_tlu_mpc_halted_only,
   output logic dec_tlu_dbg_halted,
   output logic dec_tlu_pmu_fw_halted,
   output logic dec_tlu_debug_mode,
   output logic dec_tlu_resume_ack,
   output logic dec_tlu_debug_stall,
   output logic dec_tlu_flush_leak_one_wb,
   output logic dec_tlu_flush_err_wb,
   input  logic dbg_halt_req,
   input  logic dbg_resume_req,
   input  logic ifu_miss_state_idle,
   input  logic lsu_halt_idle_any,
   output trigger_pkt_t  [3:0] trigger_pkt_any,


   input logic       mhwakeup,

   input logic mexintpend,
   input logic timer_int,
   input logic dec_fpu_fflags_valid,
   input logic [4:0] dec_fpu_fflags,
   input logic dec_fpu_dirty,
   output logic [2:0] dec_tlu_frm,
   output logic dec_tlu_fp_enabled,

   output logic o_cpu_halt_status,
   output logic o_cpu_halt_ack,
   output logic o_cpu_run_ack,
   output logic o_debug_mode_status,

   output logic mpc_debug_halt_ack,
   output logic mpc_debug_run_ack,
   output logic debug_brkpt_status,

   output br_tlu_pkt_t dec_tlu_br0_wb_pkt,
   output br_tlu_pkt_t dec_tlu_br1_wb_pkt,

   output logic [31:0] dec_csr_rddata_d,
   output logic dec_csr_legal_d,

   output logic dec_tlu_i0_kill_writeb_wb,
   output logic dec_tlu_i1_kill_writeb_wb,

   output logic dec_tlu_flush_lower_wb,
   output logic [31:1] dec_tlu_flush_path_wb,
   output logic dec_tlu_fence_i_wb,

   output logic dec_tlu_presync_d,
   output logic dec_tlu_postsync_d,

   output logic [31:0] dec_tlu_mrac_ff,

   output logic dec_tlu_cancel_e4,

   output logic dec_tlu_wr_pause_wb,
   output logic dec_tlu_flush_pause_wb,

   output logic [1:0] dec_tlu_perfcnt0,
   output logic [1:0] dec_tlu_perfcnt1,
   output logic [1:0] dec_tlu_perfcnt2,
   output logic [1:0] dec_tlu_perfcnt3,


   output logic dec_tlu_i0_valid_wb1,
   output logic dec_tlu_i1_valid_wb1,
   output logic dec_tlu_i0_exc_valid_wb1,
   output logic dec_tlu_i1_exc_valid_wb1,
   output logic dec_tlu_int_valid_wb1,
   output logic [4:0] dec_tlu_exc_cause_wb1,
   output logic [31:0] dec_tlu_mtval_wb1,


   output logic  dec_tlu_sideeffect_posted_disable,
   output logic  dec_tlu_dual_issue_disable,
   output logic  dec_tlu_core_ecc_disable,
   output logic  dec_tlu_sec_alu_disable,
   output logic  dec_tlu_non_blocking_disable,
   output logic  dec_tlu_fast_div_disable,
   output logic  dec_tlu_bpred_disable,
   output logic  dec_tlu_wb_coalescing_disable,
   output logic  dec_tlu_ld_miss_byp_wb_disable,
   output logic  dec_tlu_pipelining_disable,


   output logic  dec_tlu_misc_clk_override,
   output logic  dec_tlu_dec_clk_override,
   output logic  dec_tlu_exu_clk_override,
   output logic  dec_tlu_ifu_clk_override,
   output logic  dec_tlu_lsu_clk_override,
   output logic  dec_tlu_bus_clk_override,
   output logic  dec_tlu_dccm_clk_override,
   output logic  dec_tlu_icm_clk_override

   );

   logic         dec_csr_wen_wb_mod, clk_override, e4e5_int_clk, nmi_lsu_load_type, nmi_lsu_store_type, nmi_int_detected_f, nmi_lsu_load_type_f,
                 nmi_lsu_store_type_f, allow_dbg_halt_csr_write, dbg_cmd_done_ns, i_cpu_run_req_d1_raw, debug_mode_status, lsu_single_ecc_error_wb,
                 i0_mp_e4, i1_mp_e4, sel_npc_e4, sel_npc_wb, ce_int, mtval_capture_lsu_wb, wr_mdeau_wb, micect_cout_nc, miccmect_cout_nc,
                 mdccmect_cout_nc, nmi_in_debug_mode, dpc_capture_npc, dpc_capture_pc, tdata_load, tdata_opcode, tdata_action, perfcnt_halted, tdata_chain,
                 tdata_kill_write;


   logic reset_delayed, reset_detect, reset_detected;
   logic wr_mstatus_wb, wr_mtvec_wb, wr_mie_wb, wr_mcyclel_wb, wr_mcycleh_wb,
         wr_minstretl_wb, wr_minstreth_wb, wr_mscratch_wb, wr_mepc_wb, wr_mcause_wb, wr_mtval_wb,
         wr_mrac_wb, wr_dcsr_wb,
         wr_dpc_wb, wr_micect_wb, wr_miccmect_wb,
         wr_mdccmect_wb,wr_mhpme3_wb, wr_mhpme4_wb, wr_mhpme5_wb, wr_mhpme6_wb;
   logic wr_mgpmc_wb, mgpmc_b, mgpmc;
   logic wr_mtsel_wb, wr_mtdata1_t0_wb, wr_mtdata1_t1_wb, wr_mtdata1_t2_wb, wr_mtdata1_t3_wb, wr_mtdata2_t0_wb, wr_mtdata2_t1_wb, wr_mtdata2_t2_wb, wr_mtdata2_t3_wb;
   logic [31:0] mtdata2_t0, mtdata2_t1, mtdata2_t2, mtdata2_t3, mtdata2_tsel_out, mtdata1_tsel_out;
   logic [9:0]  mtdata1_t0_ns, mtdata1_t0, mtdata1_t1_ns, mtdata1_t1, mtdata1_t2_ns, mtdata1_t2, mtdata1_t3_ns, mtdata1_t3;
   logic [27:0] tdata_wrdata_wb;
   logic [1:0] mtsel_ns, mtsel;
   logic tlu_i0_kill_writeb_e4, tlu_i1_kill_writeb_e4;
   logic [1:0]  mstatus_ns, mstatus;
   logic [1:0]  mstatus_fs_ns, mstatus_fs;
   logic [4:0]  fflags_ns, fflags;
   logic [2:0]  frm_ns, frm;
   logic        wr_fflags_wb, wr_frm_wb, wr_fcsr_wb;
   logic mstatus_mie_ns;
   logic [30:0] mtvec_ns, mtvec;
   logic [15:2] dcsr_ns, dcsr;
   logic [5:0] mip_ns, mip;
   logic [5:0] mie_ns, mie;
   logic [31:0] mcyclel_ns, mcyclel;
   logic [31:0] mcycleh_ns, mcycleh;
   logic [31:0] minstretl_ns, minstretl;
   logic [31:0] minstreth_ns, minstreth;
   logic [31:0] micect_ns, micect, miccmect_ns, miccmect, mdccmect_ns, mdccmect;
   logic [26:0] micect_inc, miccmect_inc, mdccmect_inc;
   logic [31:0] mscratch;
   logic [31:0] mhpmc3, mhpmc3_ns, mhpmc4, mhpmc4_ns, mhpmc5, mhpmc5_ns, mhpmc6, mhpmc6_ns;
   logic [31:0] mhpmc3h, mhpmc3h_ns, mhpmc4h, mhpmc4h_ns, mhpmc5h, mhpmc5h_ns, mhpmc6h, mhpmc6h_ns;
   logic [5:0]  mhpme3, mhpme4, mhpme5, mhpme6;
   logic [31:0] mrac;
   logic [31:0] mdseac;
   logic mdseac_locked_ns, mdseac_locked_f, mdseac_en, nmi_lsu_detected;
   logic [31:1] mepc_ns, mepc;
   logic [31:1] dpc_ns, dpc;
   logic [31:0] mcause_ns, mcause;
   logic [31:0] mtval_ns, mtval;
   logic       mret_wb;
   logic dec_pause_state_f, dec_tlu_wr_pause_wb_f, pause_expired_e4, pause_expired_wb;
   logic       tlu_flush_lower_e4, tlu_flush_lower_wb;
   logic [31:1] tlu_flush_path_e4, tlu_flush_path_wb;
   logic i0_valid_wb, i1_valid_wb;
   logic [5:0] vectored_cause;
   logic       vpath_overflow_nc;
   logic [31:1] vectored_path, interrupt_path;
   logic        ebreak_e4, ebreak_to_debug_mode_e4, ecall_e4, illegal_e4, illegal_e4_qual, mret_e4, inst_acc_e4, fence_i_e4,
                 ic_perr_e4, iccm_sbecc_e4, ebreak_to_debug_mode_wb, kill_ebreak_count_wb, inst_acc_second_e4;
   logic        ebreak_wb, ecall_wb, illegal_wb,  illegal_raw_wb, inst_acc_wb, inst_acc_second_wb, fence_i_wb, ic_perr_wb, iccm_sbecc_wb;
   logic        inst_misaligned_i0_e4, inst_misaligned_i1_e4, inst_misaligned_e4, inst_misaligned_wb;
   logic [31:1] inst_misaligned_addr_e4, inst_misaligned_addr_wb;
   logic ce_int_ready, ext_int_ready, timer_int_ready, int_timer0_int_ready, int_timer1_int_ready, mhwakeup_ready,
         take_ext_int, take_ce_int, take_timer_int, take_int_timer0_int, take_int_timer1_int, take_nmi, take_nmi_wb, int_timer0_int_possible, int_timer1_int_possible;
   logic i0_exception_valid_e4, interrupt_valid, i0_exception_valid_wb, interrupt_valid_wb, exc_or_int_valid, exc_or_int_valid_wb, mdccme_ce_req, miccme_ce_req, mice_ce_req;
   logic synchronous_flush_e4;
   logic [4:0] exc_cause_e4, exc_cause_wb;
   logic        mcyclel_cout, mcyclel_cout_f;
   logic [31:0] mcyclel_inc;
   logic        mcycleh_cout_nc;
   logic [31:0] mcycleh_inc;
   logic        minstretl_cout, minstretl_cout_f, minstret_enable;
   logic [31:0] minstretl_inc, minstretl_read;
   logic        minstreth_cout_nc;
   logic [31:0] minstreth_inc, minstreth_read;
   logic [31:1] pc_e4, pc_wb, npc_e4, npc_wb;
   logic        mtval_capture_pc_wb, mtval_capture_inst_wb, mtval_clear_wb, mtval_capture_pc_plus2_wb,
                mtval_capture_target_wb;
   logic valid_csr;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] dec_tlu_br0_addr_e4, dec_tlu_br1_addr_e4;
   logic [1:0]  dec_tlu_br0_bank_e4, dec_tlu_br1_bank_e4;
   logic rfpc_i0_e4, rfpc_i1_e4;
   logic lsu_i0_rfnpc_dc4, lsu_i1_rfnpc_dc4;
   logic lsu_i0_rfpc_dc4, lsu_i1_rfpc_dc4;
   logic dec_tlu_br0_error_e4, dec_tlu_br0_start_error_e4, dec_tlu_br0_v_e4;
   logic dec_tlu_br1_error_e4, dec_tlu_br1_start_error_e4, dec_tlu_br1_v_e4;
   logic lsu_i0_exc_dc4, lsu_i1_exc_dc4, lsu_i0_exc_dc4_raw, lsu_i1_exc_dc4_raw, lsu_exc_ma_dc4, lsu_exc_acc_dc4, lsu_exc_st_dc4,
         lsu_exc_valid_e4, lsu_exc_valid_e4_raw, lsu_exc_valid_wb, lsu_i0_exc_wb,
         block_interrupts, lsu_block_interrupts_dc3, lsu_block_interrupts_e4, lsu_load_ecc_stbuf_full_dc4;
   logic tlu_i0_commit_cmt, tlu_i1_commit_cmt;
   logic i0_trigger_eval_e4, i1_trigger_eval_e4, lsu_freeze_e4, lsu_freeze_pulse_e3, lsu_freeze_pulse_e4;

   logic request_debug_mode_e4, request_debug_mode_wb, request_debug_mode_done, request_debug_mode_done_f;
   logic take_halt, take_halt_f, halt_taken, halt_taken_f, internal_dbg_halt_mode, dbg_tlu_halted_f, take_reset,
         dbg_tlu_halted, core_empty, lsu_halt_idle_any_f, lsu_halt_idle_any_ff,
         ifu_miss_state_idle_f, ifu_miss_state_idle_ff, resume_ack_ns,
          debug_halt_req_f, debug_resume_req_f_raw, debug_resume_req_f, enter_debug_halt_req, dcsr_single_step_done, dcsr_single_step_done_f,
          debug_halt_req_d1, debug_halt_req_ns, dcsr_single_step_running, dcsr_single_step_running_f, internal_dbg_halt_timers;

   logic [3:0] i0_trigger_e4, i1_trigger_e4, trigger_action, trigger_enabled,
               i0_trigger_chain_masked_e4, i1_trigger_chain_masked_e4;
   logic [2:0] trigger_chain;
   logic       i0_trigger_hit_e4, i0_trigger_hit_raw_e4, i0_trigger_action_e4,
               trigger_hit_e4, trigger_hit_wb, i0_trigger_hit_wb,
               mepc_trigger_hit_sel_pc_e4, i0_trigger_set_hit_e4, i1_trigger_set_hit_e4,
               mepc_trigger_hit_sel_pc_wb;
   logic       i1_trigger_hit_e4, i1_trigger_hit_raw_e4, i1_trigger_action_e4;
   logic [3:0] update_hit_bit_e4, update_hit_bit_wb, i0_iside_trigger_has_pri_e4, i1_iside_trigger_has_pri_e4,
               i0_lsu_trigger_has_pri_e4, i1_lsu_trigger_has_pri_e4;
   logic cpu_halt_status, cpu_halt_ack, cpu_run_ack, ext_halt_pulse, i_cpu_halt_req_d1, i_cpu_run_req_d1;

   logic inst_acc_e4_raw, trigger_hit_dmode_e4, trigger_hit_dmode_wb, trigger_hit_for_dscr_cause_wb;
   logic wr_mcgc_wb, wr_mfdc_wb;
   logic [8:0] mcgc;
   logic [18:0] mfdc;
   logic [14:0] mfdc_int, mfdc_ns;
   logic i_cpu_halt_req_sync_qual, i_cpu_run_req_sync_qual, pmu_fw_halt_req_ns, pmu_fw_halt_req_f, int_timer_stalled,
         fw_halt_req, enter_pmu_fw_halt_req, pmu_fw_tlu_halted, pmu_fw_tlu_halted_f, internal_pmu_fw_halt_mode,
         internal_pmu_fw_halt_mode_f, int_timer0_int_hold, int_timer1_int_hold, int_timer0_int_hold_f, int_timer1_int_hold_f;
   logic dcsr_single_step_running_ff;
   logic nmi_int_delayed, nmi_int_detected;
   logic [3:0] trigger_execute, trigger_data, trigger_store;
   logic mpc_run_state_ns, debug_brkpt_status_ns, mpc_debug_halt_ack_ns, mpc_debug_run_ack_ns, dbg_halt_state_ns, dbg_run_state_ns,
         dbg_halt_state_f, mpc_debug_halt_req_sync_f, mpc_debug_run_req_sync_f, mpc_halt_state_f, mpc_halt_state_ns, mpc_run_state_f, debug_brkpt_status_f,
         mpc_debug_halt_ack_f, mpc_debug_run_ack_f, dbg_run_state_f, dbg_halt_state_ff, mpc_debug_halt_req_sync_pulse,
         mpc_debug_run_req_sync_pulse, debug_brkpt_valid, debug_halt_req, debug_resume_req, dec_tlu_mpc_halted_only_ns;

   logic wr_mpmc_wb, set_mie_pmu_fw_halt;
   logic [1:1] mpmc_b_ns, mpmc, mpmc_b;


   logic [31:0] dec_timer_rddata_d;
   logic dec_timer_read_d, dec_timer_t0_pulse, dec_timer_t1_pulse;

   dec_timer_ctl int_timers(.*);


   assign clk_override = dec_tlu_dec_clk_override;


   logic nmi_int_sync, timer_int_sync, i_cpu_halt_req_sync, i_cpu_run_req_sync, mpc_debug_halt_req_sync, mpc_debug_run_req_sync;
   rvsyncss #(6) syncro_ff(.*,
                           .clk(free_clk),
                           .din ({nmi_int,      timer_int,      i_cpu_halt_req,      i_cpu_run_req,      mpc_debug_halt_req,      mpc_debug_run_req}),
                           .dout({nmi_int_sync, timer_int_sync, i_cpu_halt_req_sync, i_cpu_run_req_sync, mpc_debug_halt_req_sync, mpc_debug_run_req_sync}));


   logic csr_wr_clk;
   rvoclkhdr csrwr_wb_cgc ( .en(dec_csr_wen_wb_mod | clk_override), .l1clk(csr_wr_clk), .* );
   logic lsu_e3_e4_clk, lsu_e4_e5_clk;


   lsu_error_pkt_t lsu_error_pkt_dc4;

   rvoclkhdr lsu_e3_e4_cgc ( .en(lsu_error_pkt_dc3.exc_valid | lsu_error_pkt_dc4.exc_valid | lsu_error_pkt_dc3.single_ecc_error | lsu_error_pkt_dc4.single_ecc_error | clk_override), .l1clk(lsu_e3_e4_clk), .* );
   rvoclkhdr lsu_e4_e5_cgc ( .en(lsu_error_pkt_dc4.exc_valid | lsu_exc_valid_wb | clk_override), .l1clk(lsu_e4_e5_clk), .* );

   logic freeze_rfpc_e4, rfpc_postsync_in, rfpc_postsync;

   logic e4e5_clk, e4_valid, e5_valid, e4e5_valid, internal_dbg_halt_mode_f, internal_dbg_halt_mode_f2, internal_dbg_halt_mode_f3;
   assign e4_valid = dec_tlu_i0_valid_e4 | dec_tlu_i1_valid_e4;
   assign e4e5_valid = e4_valid | e5_valid | freeze_rfpc_e4;
   rvoclkhdr e4e5_cgc ( .en(e4e5_valid | clk_override), .l1clk(e4e5_clk), .* );
   rvoclkhdr e4e5_int_cgc ( .en(e4e5_valid | internal_dbg_halt_mode_f | i_cpu_run_req_d1 | interrupt_valid | interrupt_valid_wb | reset_delayed | pause_expired_e4 | pause_expired_wb | clk_override), .l1clk(e4e5_int_clk), .* );


   assign lsu_freeze_pulse_e3 = lsu_freeze_dc3 & ~lsu_freeze_e4;
   rvdff #(10)  freeff (.*,   .clk(free_clk),
                        .din({internal_dbg_halt_mode_f2,internal_dbg_halt_mode_f, lsu_freeze_dc3, lsu_freeze_pulse_e3,
                              e4_valid, lsu_block_interrupts_dc3, internal_dbg_halt_mode, tlu_flush_lower_e4, tlu_i0_kill_writeb_e4, tlu_i1_kill_writeb_e4 }),
                        .dout({internal_dbg_halt_mode_f3, internal_dbg_halt_mode_f2, lsu_freeze_e4, lsu_freeze_pulse_e4,
                               e5_valid, lsu_block_interrupts_e4, internal_dbg_halt_mode_f, tlu_flush_lower_wb, dec_tlu_i0_kill_writeb_wb, dec_tlu_i1_kill_writeb_wb}));


   rvdff #(2) reset_ff (.*, .clk(free_clk), .din({1'b1, reset_detect}), .dout({reset_detect, reset_detected}));
   assign reset_delayed = reset_detect ^ reset_detected;

   rvdff #(4) nmi_ff (.*, .clk(free_clk), .din({nmi_int_sync, nmi_int_detected, nmi_lsu_load_type, nmi_lsu_store_type}), .dout({nmi_int_delayed, nmi_int_detected_f, nmi_lsu_load_type_f, nmi_lsu_store_type_f}));


   assign nmi_lsu_detected = ~mdseac_locked_f & (lsu_imprecise_error_load_any | lsu_imprecise_error_store_any);

   assign nmi_int_detected = (nmi_int_sync & ~nmi_int_delayed) | nmi_lsu_detected | (nmi_int_detected_f & ~take_nmi_wb);

   assign nmi_lsu_load_type = (nmi_lsu_detected & lsu_imprecise_error_load_any & ~(nmi_int_detected_f & ~take_nmi_wb)) | (nmi_lsu_load_type_f & ~take_nmi_wb);
   assign nmi_lsu_store_type = (nmi_lsu_detected & lsu_imprecise_error_store_any & ~(nmi_int_detected_f & ~take_nmi_wb)) | (nmi_lsu_store_type_f & ~take_nmi_wb);

`define MSTATUS_MIE 0
`define MIP_MCEIP 5
`define MIP_MITIP0 4
`define MIP_MITIP1 3
`define MIP_MEIP 2
`define MIP_MTIP 1
`define MIP_MSIP 0

`define MIE_MCEIE 5
`define MIE_MITIE0 4
`define MIE_MITIE1 3
`define MIE_MEIE 2
`define MIE_MTIE 1
`define MIE_MSIE 0

`define DCSR_EBREAKM 15
`define DCSR_STEPIE 11
`define DCSR_STOPC 10

`define DCSR_STEP 2


    rvdff #(11)  mpvhalt_ff (.*, .clk(free_clk),
                                 .din({mpc_debug_halt_req_sync, mpc_debug_run_req_sync,
                                       mpc_halt_state_ns, mpc_run_state_ns, debug_brkpt_status_ns,
                                       mpc_debug_halt_ack_ns, mpc_debug_run_ack_ns,
                                       dbg_halt_state_ns, dbg_run_state_ns, dbg_halt_state_f,
                                       dec_tlu_mpc_halted_only_ns}),
                                .dout({mpc_debug_halt_req_sync_f, mpc_debug_run_req_sync_f,
                                       mpc_halt_state_f, mpc_run_state_f, debug_brkpt_status_f,
                                       mpc_debug_halt_ack_f, mpc_debug_run_ack_f,
                                       dbg_halt_state_f, dbg_run_state_f, dbg_halt_state_ff,
                                       dec_tlu_mpc_halted_only}));


   assign mpc_debug_halt_req_sync_pulse = mpc_debug_halt_req_sync & ~mpc_debug_halt_req_sync_f;
   assign mpc_debug_run_req_sync_pulse = mpc_debug_run_req_sync & ~mpc_debug_run_req_sync_f;


   assign mpc_halt_state_ns = (mpc_halt_state_f | mpc_debug_halt_req_sync_pulse | (reset_delayed & ~mpc_reset_run_req)) & ~mpc_debug_run_req_sync;
   assign mpc_run_state_ns = (mpc_run_state_f | (mpc_debug_run_req_sync_pulse & ~mpc_debug_run_ack_f)) & (internal_dbg_halt_mode_f & ~dcsr_single_step_running_f);


   assign dbg_halt_state_ns = (dbg_halt_state_f | (dbg_halt_req | dcsr_single_step_done_f | trigger_hit_dmode_wb | ebreak_to_debug_mode_wb)) & ~dbg_resume_req;
   assign dbg_run_state_ns = (dbg_run_state_f | dbg_resume_req) & (internal_dbg_halt_mode_f & ~dcsr_single_step_running_f);


   assign dec_tlu_mpc_halted_only_ns = ~dbg_halt_state_f & mpc_halt_state_f;


   assign debug_brkpt_valid = ebreak_to_debug_mode_wb | trigger_hit_dmode_wb;
   assign debug_brkpt_status_ns = (debug_brkpt_valid | debug_brkpt_status_f) & (internal_dbg_halt_mode & ~dcsr_single_step_running_f);


   assign mpc_debug_halt_ack_ns = mpc_halt_state_f & internal_dbg_halt_mode_f & mpc_debug_halt_req_sync & core_empty;
   assign mpc_debug_run_ack_ns = (mpc_debug_run_req_sync & ~internal_dbg_halt_mode & ~mpc_debug_halt_req_sync) | (mpc_debug_run_ack_f & mpc_debug_run_req_sync) ;


   assign mpc_debug_halt_ack = mpc_debug_halt_ack_f;
   assign mpc_debug_run_ack = mpc_debug_run_ack_f;
   assign debug_brkpt_status = debug_brkpt_status_f;


   assign debug_halt_req = (dbg_halt_req | mpc_debug_halt_req_sync | (reset_delayed & ~mpc_reset_run_req)) & ~internal_dbg_halt_mode_f;

   assign debug_resume_req = ~debug_resume_req_f &
                             ((mpc_run_state_ns & ~dbg_halt_state_ns) |
                              (dbg_run_state_ns & ~mpc_halt_state_ns));


   assign take_halt = (debug_halt_req_f | pmu_fw_halt_req_f) & ~lsu_block_interrupts_e4 & ~synchronous_flush_e4 & ~mret_e4 & ~halt_taken_f & ~dec_tlu_flush_noredir_wb & ~take_reset;


   assign halt_taken = (dec_tlu_flush_noredir_wb & ~dec_tlu_flush_pause_wb) | (halt_taken_f & ~dbg_tlu_halted_f & ~pmu_fw_tlu_halted_f & ~interrupt_valid_wb);


   assign core_empty = lsu_halt_idle_any_f & lsu_halt_idle_any_ff &
                       ifu_miss_state_idle_f & ifu_miss_state_idle_ff &
                       ~debug_halt_req & ~debug_halt_req_d1;


   assign enter_debug_halt_req = (~internal_dbg_halt_mode_f & debug_halt_req) | dcsr_single_step_done_f | trigger_hit_dmode_wb | ebreak_to_debug_mode_wb;


   assign internal_dbg_halt_mode = debug_halt_req_ns | (internal_dbg_halt_mode_f & ~(debug_resume_req_f & ~dcsr[`DCSR_STEP]));

   assign allow_dbg_halt_csr_write = internal_dbg_halt_mode_f & ~dcsr_single_step_running_f;


   assign debug_halt_req_ns = enter_debug_halt_req | (debug_halt_req_f & ~dbg_tlu_halted);

   assign dbg_tlu_halted = (debug_halt_req_f & core_empty & halt_taken) | (dbg_tlu_halted_f & ~debug_resume_req_f);

   assign resume_ack_ns = (debug_resume_req_f & dbg_tlu_halted_f & dbg_run_state_ns);

   assign dcsr_single_step_done = dec_tlu_i0_valid_e4 & ~dec_tlu_dbg_halted & dcsr[`DCSR_STEP] & ~rfpc_i0_e4;

   assign dcsr_single_step_running = (debug_resume_req_f & dcsr[`DCSR_STEP]) | (dcsr_single_step_running_f & ~dcsr_single_step_done_f);

   assign dbg_cmd_done_ns = dec_tlu_i0_valid_e4 & dec_tlu_dbg_halted;


   assign request_debug_mode_e4 = (trigger_hit_dmode_e4 | ebreak_to_debug_mode_e4) | (request_debug_mode_wb & ~dec_tlu_flush_lower_wb);

   assign request_debug_mode_done = (request_debug_mode_wb | request_debug_mode_done_f) & ~dbg_tlu_halted_f;

    rvdff #(22)  halt_ff (.*, .clk(free_clk), .din({halt_taken, take_halt, lsu_halt_idle_any, ifu_miss_state_idle, dbg_tlu_halted,
                                  resume_ack_ns, dbg_cmd_done_ns, debug_halt_req_ns, debug_resume_req, trigger_hit_dmode_e4,
                                  dcsr_single_step_done, debug_halt_req,  update_hit_bit_e4[3:0], dec_tlu_wr_pause_wb, dec_pause_state,
                                  request_debug_mode_e4, request_debug_mode_done, dcsr_single_step_running, dcsr_single_step_running_f}),
                           .dout({halt_taken_f, take_halt_f, lsu_halt_idle_any_f, ifu_miss_state_idle_f, dbg_tlu_halted_f,
                                  dec_tlu_resume_ack, dec_dbg_cmd_done, debug_halt_req_f, debug_resume_req_f_raw, trigger_hit_dmode_wb,
                                  dcsr_single_step_done_f, debug_halt_req_d1, update_hit_bit_wb[3:0], dec_tlu_wr_pause_wb_f, dec_pause_state_f,
                                  request_debug_mode_wb, request_debug_mode_done_f, dcsr_single_step_running_f, dcsr_single_step_running_ff}));

   rvdff #(2) halt_idle_ff (.*, .clk(free_clk),
                            .din({lsu_halt_idle_any_f, ifu_miss_state_idle_f}),
                            .dout({lsu_halt_idle_any_ff, ifu_miss_state_idle_ff}));


   assign debug_resume_req_f = debug_resume_req_f_raw & ~dbg_halt_req;

   assign dec_tlu_debug_stall = debug_halt_req_f;
   assign dec_tlu_dbg_halted = dbg_tlu_halted_f;
   assign dec_tlu_debug_mode = internal_dbg_halt_mode_f;
   assign dec_tlu_pmu_fw_halted = pmu_fw_tlu_halted_f;


   assign dec_tlu_flush_noredir_wb = take_halt_f | (fence_i_wb & internal_dbg_halt_mode_f) | dec_tlu_flush_pause_wb | (trigger_hit_wb & trigger_hit_dmode_wb);


   assign dec_tlu_flush_pause_wb = dec_tlu_wr_pause_wb_f & ~interrupt_valid_wb;


   assign pause_expired_e4 = ~dec_pause_state & dec_pause_state_f & ~(ext_int_ready | ce_int_ready | timer_int_ready | int_timer0_int_hold_f | int_timer1_int_hold_f | nmi_int_detected) & ~interrupt_valid_wb & ~debug_halt_req_f & ~pmu_fw_halt_req_f & ~halt_taken_f;

   assign dec_tlu_flush_leak_one_wb = dec_tlu_flush_lower_wb  & dcsr[`DCSR_STEP] & (dec_tlu_resume_ack | dcsr_single_step_running);
   assign dec_tlu_flush_err_wb = dec_tlu_flush_lower_wb & (ic_perr_wb | iccm_sbecc_wb);


   assign dec_dbg_cmd_fail = illegal_raw_wb & dec_dbg_cmd_done;


`define MTDATA1_DMODE 9
`define MTDATA1_SEL 7
`define MTDATA1_ACTION 6
`define MTDATA1_CHAIN 5
`define MTDATA1_MATCH 4
`define MTDATA1_M_ENABLED 3
`define MTDATA1_EXE 2
`define MTDATA1_ST 1
`define MTDATA1_LD 0


   assign trigger_execute[3:0] = {mtdata1_t3[`MTDATA1_EXE], mtdata1_t2[`MTDATA1_EXE], mtdata1_t1[`MTDATA1_EXE], mtdata1_t0[`MTDATA1_EXE]};
   assign trigger_data[3:0] = {mtdata1_t3[`MTDATA1_SEL], mtdata1_t2[`MTDATA1_SEL], mtdata1_t1[`MTDATA1_SEL], mtdata1_t0[`MTDATA1_SEL]};
   assign trigger_store[3:0] = {mtdata1_t3[`MTDATA1_ST], mtdata1_t2[`MTDATA1_ST], mtdata1_t1[`MTDATA1_ST], mtdata1_t0[`MTDATA1_ST]};


   assign trigger_enabled[3:0] = {(mtdata1_t3[`MTDATA1_ACTION] | mstatus[`MSTATUS_MIE]) & mtdata1_t3[`MTDATA1_M_ENABLED],
                                  (mtdata1_t2[`MTDATA1_ACTION] | mstatus[`MSTATUS_MIE]) & mtdata1_t2[`MTDATA1_M_ENABLED],
                                  (mtdata1_t1[`MTDATA1_ACTION] | mstatus[`MSTATUS_MIE]) & mtdata1_t1[`MTDATA1_M_ENABLED],
                                  (mtdata1_t0[`MTDATA1_ACTION] | mstatus[`MSTATUS_MIE]) & mtdata1_t0[`MTDATA1_M_ENABLED]};


   assign i0_iside_trigger_has_pri_e4[3:0] = ~( (trigger_execute[3:0] & trigger_data[3:0] & {4{inst_acc_e4_raw}}) |
                                                ({4{exu_i0_br_error_e4 | exu_i0_br_start_error_e4}}));

   assign i1_iside_trigger_has_pri_e4[3:0] = ~( ({4{exu_i1_br_error_e4 | exu_i1_br_start_error_e4}}) );


   assign i0_lsu_trigger_has_pri_e4[3:0] = ~(trigger_store[3:0] & trigger_data[3:0] & {4{lsu_i0_exc_dc4_raw}});
   assign i1_lsu_trigger_has_pri_e4[3:0] = ~(trigger_store[3:0] & trigger_data[3:0] & {4{lsu_i1_exc_dc4_raw}});


   assign i0_trigger_eval_e4 = dec_tlu_i0_valid_e4 | ( dec_i0_load_e4 & lsu_freeze_pulse_e4);
   assign i1_trigger_eval_e4 = dec_tlu_i1_valid_e4 | (~dec_i0_load_e4 & lsu_freeze_pulse_e4);

   assign i0_trigger_e4[3:0] = {4{i0_trigger_eval_e4}} & dec_tlu_packet_e4.i0trigger[3:0] & i0_iside_trigger_has_pri_e4[3:0] & i0_lsu_trigger_has_pri_e4[3:0] & trigger_enabled[3:0];
   assign i1_trigger_e4[3:0] = {4{i1_trigger_eval_e4}} & dec_tlu_packet_e4.i1trigger[3:0] & i1_iside_trigger_has_pri_e4[3:0] & i1_lsu_trigger_has_pri_e4[3:0] & trigger_enabled[3:0];

   assign trigger_chain[2:0] = {mtdata1_t2[`MTDATA1_CHAIN], mtdata1_t1[`MTDATA1_CHAIN], mtdata1_t0[`MTDATA1_CHAIN]};


   assign i0_trigger_chain_masked_e4[3:0] = {i0_trigger_e4[3] & (~trigger_chain[2] | i0_trigger_e4[2]),
                                             i0_trigger_e4[2] & (~trigger_chain[2] | i0_trigger_e4[3]),
                                             i0_trigger_e4[1] & (~trigger_chain[0] | i0_trigger_e4[0]),
                                             i0_trigger_e4[0] & (~trigger_chain[0] | i0_trigger_e4[1])};

   assign i1_trigger_chain_masked_e4[3:0] = {i1_trigger_e4[3] & (~trigger_chain[2] | i1_trigger_e4[2]),
                                             i1_trigger_e4[2] & (~trigger_chain[2] | i1_trigger_e4[3]),
                                             i1_trigger_e4[1] & (~trigger_chain[0] | i1_trigger_e4[0]),
                                             i1_trigger_e4[0] & (~trigger_chain[0] | i1_trigger_e4[1])};


   assign i0_trigger_hit_raw_e4 = |i0_trigger_chain_masked_e4[3:0];
   assign i1_trigger_hit_raw_e4 = |i1_trigger_chain_masked_e4[3:0];


   assign i0_trigger_hit_e4 = ~(dec_tlu_flush_lower_wb | dec_tlu_dbg_halted | lsu_freeze_pulse_e4) & i0_trigger_hit_raw_e4;
   assign i1_trigger_hit_e4 = ~(dec_tlu_flush_lower_wb | ~tlu_i0_commit_cmt | exu_i0_br_mp_e4 | dec_tlu_dbg_halted | lsu_freeze_pulse_e4 | lsu_i0_rfnpc_dc4) & i1_trigger_hit_raw_e4;

   assign dec_tlu_cancel_e4 = (i0_trigger_hit_raw_e4 | i1_trigger_hit_raw_e4) & lsu_freeze_pulse_e4;


   assign trigger_action[3:0] = {mtdata1_t3[`MTDATA1_ACTION] & mtdata1_t3[`MTDATA1_DMODE],
                                 mtdata1_t2[`MTDATA1_ACTION] & mtdata1_t2[`MTDATA1_DMODE] & ~mtdata1_t2[`MTDATA1_CHAIN],
                                 mtdata1_t1[`MTDATA1_ACTION] & mtdata1_t1[`MTDATA1_DMODE],
                                 mtdata1_t0[`MTDATA1_ACTION] & mtdata1_t0[`MTDATA1_DMODE] & ~mtdata1_t0[`MTDATA1_CHAIN]};


   assign i0_trigger_set_hit_e4 = |i0_trigger_e4[3:0] & ~(dec_tlu_flush_lower_wb | dec_tlu_dbg_halted | rfpc_i0_e4);
   assign i1_trigger_set_hit_e4 = |i1_trigger_e4[3:0] & ~(dec_tlu_flush_lower_wb | dec_tlu_dbg_halted |
                                                          ~tlu_i0_commit_cmt | exu_i0_br_mp_e4 | dec_tlu_dbg_halted |
                                                          lsu_freeze_pulse_e4 | lsu_i0_rfnpc_dc4 | rfpc_i1_e4);

   assign update_hit_bit_e4[3:0] = ({4{i0_trigger_set_hit_e4}} & {i0_trigger_chain_masked_e4[3], i0_trigger_e4[2], i0_trigger_chain_masked_e4[1], i0_trigger_e4[0]} ) |
                                   ({4{i1_trigger_set_hit_e4}} & {i1_trigger_chain_masked_e4[3], i1_trigger_e4[2], i1_trigger_chain_masked_e4[1], i1_trigger_e4[0]} );


   assign i0_trigger_action_e4 = |(i0_trigger_chain_masked_e4[3:0] & trigger_action[3:0]);
   assign i1_trigger_action_e4 = |(i1_trigger_chain_masked_e4[3:0] & trigger_action[3:0]);

   assign trigger_hit_e4 = i0_trigger_hit_e4 | i1_trigger_hit_e4;
   assign trigger_hit_dmode_e4 = (i0_trigger_hit_e4 & i0_trigger_action_e4) | (i1_trigger_hit_e4 & ~i0_trigger_hit_e4 & i1_trigger_action_e4);

   assign mepc_trigger_hit_sel_pc_e4 = trigger_hit_e4 & ~trigger_hit_dmode_e4;


   assign i_cpu_halt_req_sync_qual = i_cpu_halt_req_sync & ~dec_tlu_debug_mode;
   assign i_cpu_run_req_sync_qual = i_cpu_run_req_sync & ~dec_tlu_debug_mode & pmu_fw_tlu_halted_f;

   rvdff #(10) exthaltff (.*, .clk(free_clk), .din({i_cpu_halt_req_sync_qual, i_cpu_run_req_sync_qual,   cpu_halt_status,
                                                   cpu_halt_ack,   cpu_run_ack, internal_pmu_fw_halt_mode,
                                                   pmu_fw_halt_req_ns, pmu_fw_tlu_halted,
                                                   int_timer0_int_hold, int_timer1_int_hold}),
                                            .dout({i_cpu_halt_req_d1,        i_cpu_run_req_d1_raw,      o_cpu_halt_status,
                                                   o_cpu_halt_ack, o_cpu_run_ack, internal_pmu_fw_halt_mode_f,
                                                   pmu_fw_halt_req_f, pmu_fw_tlu_halted_f,
                                                   int_timer0_int_hold_f, int_timer1_int_hold_f}));


   assign ext_halt_pulse = i_cpu_halt_req_sync_qual & ~i_cpu_halt_req_d1;

   assign enter_pmu_fw_halt_req =  ext_halt_pulse | fw_halt_req;

   assign pmu_fw_halt_req_ns = (enter_pmu_fw_halt_req | (pmu_fw_halt_req_f & ~pmu_fw_tlu_halted)) & ~debug_halt_req_f;

   assign internal_pmu_fw_halt_mode = pmu_fw_halt_req_ns | (internal_pmu_fw_halt_mode_f & ~i_cpu_run_req_d1 & ~debug_halt_req_f);


   assign pmu_fw_tlu_halted = ((pmu_fw_halt_req_f & core_empty & halt_taken & ~enter_debug_halt_req) | (pmu_fw_tlu_halted_f & ~i_cpu_run_req_d1)) & ~debug_halt_req_f;

   assign cpu_halt_ack = i_cpu_halt_req_d1 & pmu_fw_tlu_halted_f;
   assign cpu_halt_status = (pmu_fw_tlu_halted_f & ~i_cpu_run_req_d1) | (o_cpu_halt_status & ~i_cpu_run_req_d1 & ~internal_dbg_halt_mode_f);
   assign cpu_run_ack = (o_cpu_halt_status & i_cpu_run_req_d1_raw) | (o_cpu_run_ack & i_cpu_run_req_sync);
   assign debug_mode_status = internal_dbg_halt_mode_f;
   assign o_debug_mode_status = debug_mode_status;


   assign i_cpu_run_req_d1 = i_cpu_run_req_d1_raw | ((nmi_int_detected | timer_int_ready | int_timer0_int_hold_f | int_timer1_int_hold_f | (mhwakeup & mhwakeup_ready)) & o_cpu_halt_status);


   rvdff #( $bits(lsu_error_pkt_t)+1 ) lsu_error_dc4ff (.*, .clk(lsu_e3_e4_clk), .din({lsu_error_pkt_dc3, lsu_load_ecc_stbuf_full_dc3}),  .dout({lsu_error_pkt_dc4, lsu_load_ecc_stbuf_full_dc4}));

   logic lsu_single_ecc_error_wb_ns;
   assign lsu_single_ecc_error_wb_ns = 1'b0;
   assign lsu_single_ecc_error_wb    = 1'b0;
   rvdff #(1) mdseac_locked_ff (.*, .clk(free_clk), .din(mdseac_locked_ns), .dout(mdseac_locked_f));

   logic [31:0] lsu_error_pkt_addr_dc4, lsu_error_pkt_addr_wb;
   assign lsu_error_pkt_addr_dc4[31:0] = lsu_error_pkt_dc4.addr[31:0];
   rvdff #(34) lsu_error_wbff (.*, .clk(lsu_e4_e5_clk), .din({lsu_error_pkt_addr_dc4[31:0], lsu_exc_valid_e4, lsu_i0_exc_dc4}),  .dout({lsu_error_pkt_addr_wb[31:0], lsu_exc_valid_wb, lsu_i0_exc_wb}));


   assign lsu_exc_valid_e4_raw = lsu_error_pkt_dc4.exc_valid & ~(lsu_error_pkt_dc4.inst_pipe & (rfpc_i0_e4 | i0_exception_valid_e4 | exu_i0_br_mp_e4)) & ~dec_tlu_flush_lower_wb;

   assign lsu_i0_exc_dc4_raw =  lsu_error_pkt_dc4.exc_valid & ~lsu_error_pkt_dc4.inst_pipe;
   assign lsu_i1_exc_dc4_raw = lsu_error_pkt_dc4.exc_valid &  lsu_error_pkt_dc4.inst_pipe;
   assign lsu_i0_exc_dc4 = lsu_i0_exc_dc4_raw & lsu_exc_valid_e4_raw & ~i0_trigger_hit_e4;
   assign lsu_i1_exc_dc4 = lsu_i1_exc_dc4_raw & lsu_exc_valid_e4_raw & ~trigger_hit_e4;
   assign lsu_exc_valid_e4 = lsu_i0_exc_dc4 | lsu_i1_exc_dc4;

   assign lsu_exc_ma_dc4 = (lsu_i0_exc_dc4 | lsu_i1_exc_dc4) & ~lsu_error_pkt_dc4.exc_type;
   assign lsu_exc_acc_dc4 = (lsu_i0_exc_dc4 | lsu_i1_exc_dc4) & lsu_error_pkt_dc4.exc_type;
   assign lsu_exc_st_dc4 = (lsu_i0_exc_dc4 | lsu_i1_exc_dc4) & lsu_error_pkt_dc4.inst_type;


   assign lsu_i0_rfnpc_dc4 = dec_tlu_i0_valid_e4 & ~lsu_error_pkt_dc4.inst_pipe & ~lsu_error_pkt_dc4.inst_type &
                             lsu_error_pkt_dc4.single_ecc_error & ~i0_trigger_hit_e4 & ~lsu_load_ecc_stbuf_full_dc4;
   assign lsu_i1_rfnpc_dc4 = dec_tlu_i1_valid_e4 &  lsu_error_pkt_dc4.inst_pipe & ~lsu_error_pkt_dc4.inst_type &
                             lsu_error_pkt_dc4.single_ecc_error & ~i0_trigger_hit_e4 & ~i1_trigger_hit_e4 & ~lsu_load_ecc_stbuf_full_dc4;

   assign lsu_i0_rfpc_dc4 = dec_tlu_i0_valid_e4 & ~lsu_error_pkt_dc4.inst_pipe & ~lsu_error_pkt_dc4.inst_type &
                            lsu_error_pkt_dc4.single_ecc_error & lsu_load_ecc_stbuf_full_dc4;
   assign lsu_i1_rfpc_dc4 = dec_tlu_i1_valid_e4 &  lsu_error_pkt_dc4.inst_pipe & ~lsu_error_pkt_dc4.inst_type &
                              lsu_error_pkt_dc4.single_ecc_error & lsu_load_ecc_stbuf_full_dc4;


   assign dec_tlu_br0_addr_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = exu_i0_br_index_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br0_bank_e4[1:0] = exu_i0_br_bank_e4[1:0];
   assign dec_tlu_br1_addr_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = exu_i1_br_index_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br1_bank_e4[1:0] = exu_i1_br_bank_e4[1:0];


   assign inst_misaligned_i0_e4 = exu_i0_inst_misaligned_e4 & dec_tlu_i0_valid_e4 &
                                  ~dec_tlu_flush_lower_wb & ~rfpc_i0_e4 & ~lsu_i0_exc_dc4_raw &
                                  ~inst_acc_e4 & ~i0_trigger_hit_e4 & ~dec_tlu_dbg_halted;

   assign inst_misaligned_i1_e4 = exu_i1_inst_misaligned_e4 & dec_tlu_i1_valid_e4 &
                                  ~dec_tlu_flush_lower_wb & ~rfpc_i0_e4 &
                                  ~exu_i0_br_mp_e4 & ~lsu_i0_exc_dc4_raw &
                                  ~(ebreak_e4 | ecall_e4 | illegal_e4 | inst_acc_e4) &
                                  ~i0_trigger_hit_e4 & ~i1_trigger_hit_e4 &
                                  ~inst_misaligned_i0_e4 & ~dec_tlu_dbg_halted;

   assign inst_misaligned_e4 = inst_misaligned_i0_e4 | inst_misaligned_i1_e4;
   assign inst_misaligned_addr_e4[31:1] = inst_misaligned_i0_e4 ?
                                                exu_i0_inst_misaligned_addr_e4[31:1] :
                                                exu_i1_inst_misaligned_addr_e4[31:1];

   assign tlu_i0_commit_cmt = dec_tlu_i0_valid_e4 &
                               ~rfpc_i0_e4 &
                               ~lsu_i0_exc_dc4 &
                               ~inst_acc_e4 &
                               ~inst_misaligned_i0_e4 &
                               ~dec_tlu_dbg_halted &
                              ~request_debug_mode_wb &
                              ~i0_trigger_hit_e4;

   assign tlu_i1_commit_cmt = dec_tlu_i1_valid_e4 &
                              ~rfpc_i0_e4 & ~rfpc_i1_e4 &
                              ~exu_i0_br_mp_e4 &
                              ~lsu_i0_exc_dc4 & ~lsu_i1_exc_dc4 &
                               ~lsu_i0_rfnpc_dc4 &
                               ~inst_acc_e4 &
                               ~inst_misaligned_e4 &
                               ~request_debug_mode_wb &
                              ~trigger_hit_e4;


   assign tlu_i0_kill_writeb_e4 = rfpc_i0_e4 | lsu_i0_exc_dc4 | inst_acc_e4 | inst_misaligned_i0_e4 | (illegal_e4 & dec_tlu_dbg_halted) | i0_trigger_hit_e4 ;
   assign tlu_i1_kill_writeb_e4 = rfpc_i0_e4 | rfpc_i1_e4 | lsu_exc_valid_e4 | exu_i0_br_mp_e4 | inst_acc_e4 | inst_misaligned_e4 | (illegal_e4 & dec_tlu_dbg_halted) | trigger_hit_e4 | lsu_i0_rfnpc_dc4;

   assign freeze_rfpc_e4 = lsu_block_interrupts_e4 & ~dec_tlu_flush_lower_wb & mfdc[13];
   assign rfpc_postsync_in = (freeze_rfpc_e4 | rfpc_postsync) & ~tlu_i0_commit_cmt;

   rvdff #(1) freezerfpc_ff (.*, .clk(free_clk), .din(rfpc_postsync_in), .dout(rfpc_postsync));


   assign rfpc_i0_e4 = freeze_rfpc_e4 | (
                       dec_tlu_i0_valid_e4 & ~tlu_flush_lower_wb & (exu_i0_br_error_e4 | exu_i0_br_start_error_e4 | ic_perr_e4 | iccm_sbecc_e4 | lsu_i0_rfpc_dc4) & ~i0_trigger_hit_e4);
    assign rfpc_i1_e4 = dec_tlu_i1_valid_e4 & ~tlu_flush_lower_wb & ~i0_exception_valid_e4 & ~exu_i0_br_mp_e4 & ~lsu_i0_exc_dc4 & ~lsu_i0_rfnpc_dc4 &
                       ~(exu_i0_br_error_e4 | exu_i0_br_start_error_e4 | ic_perr_e4 | iccm_sbecc_e4 | lsu_i0_rfpc_dc4) &
                       (exu_i1_br_error_e4 | exu_i1_br_start_error_e4 | lsu_i1_rfpc_dc4) &
                       ~trigger_hit_e4;


   assign dec_tlu_br0_error_e4 = exu_i0_br_error_e4 & dec_tlu_i0_valid_e4 & ~tlu_flush_lower_wb;
   assign dec_tlu_br0_start_error_e4 = exu_i0_br_start_error_e4 & dec_tlu_i0_valid_e4 & ~tlu_flush_lower_wb;
   assign dec_tlu_br0_v_e4 = exu_i0_br_valid_e4 & dec_tlu_i0_valid_e4 & ~tlu_flush_lower_wb & ~exu_i0_br_mp_e4;

   assign dec_tlu_br1_error_e4 = exu_i1_br_error_e4 & dec_tlu_i1_valid_e4 & ~tlu_flush_lower_wb & ~exu_i0_br_mp_e4;
   assign dec_tlu_br1_start_error_e4 = exu_i1_br_start_error_e4 & dec_tlu_i1_valid_e4 & ~tlu_flush_lower_wb & ~exu_i0_br_mp_e4;
   assign dec_tlu_br1_v_e4 = exu_i1_br_valid_e4 & ~tlu_flush_lower_wb & dec_tlu_i1_valid_e4 & ~exu_i0_br_mp_e4 & ~exu_i1_br_mp_e4;

   rvdff #(18)
   bp_wb_ff (.*, .clk(e4e5_clk),
                            .din({exu_i0_br_hist_e4[1:0],
                                  dec_tlu_br0_error_e4,
                                  dec_tlu_br0_start_error_e4,
                                  dec_tlu_br0_v_e4,
                                  exu_i1_br_hist_e4[1:0],
                                  dec_tlu_br1_error_e4,
                                  dec_tlu_br1_start_error_e4,
                                  dec_tlu_br1_v_e4,
                                  dec_tlu_br0_bank_e4[1:0],
                                  dec_tlu_br1_bank_e4[1:0],
                                  exu_i0_br_way_e4,
                                  exu_i1_br_way_e4,
                                  exu_i0_br_middle_e4,
                                  exu_i1_br_middle_e4
                                  }),
                           .dout({dec_tlu_br0_wb_pkt.hist[1:0],
                                  dec_tlu_br0_wb_pkt.br_error,
                                  dec_tlu_br0_wb_pkt.br_start_error,
                                  dec_tlu_br0_wb_pkt.valid,
                                  dec_tlu_br1_wb_pkt.hist[1:0],
                                  dec_tlu_br1_wb_pkt.br_error,
                                  dec_tlu_br1_wb_pkt.br_start_error,
                                  dec_tlu_br1_wb_pkt.valid,
                                  dec_tlu_br0_wb_pkt.bank[1:0],
                                  dec_tlu_br1_wb_pkt.bank[1:0],
                                  dec_tlu_br0_wb_pkt.way,
                                  dec_tlu_br1_wb_pkt.way,
                                  dec_tlu_br0_wb_pkt.middle,
                                  dec_tlu_br1_wb_pkt.middle
                                  }));

   rvdff #(`RV_BHT_GHR_SIZE*2)  bp_wb_ghrff (.*,  .clk(e4e5_clk),
                                               .din({exu_i0_br_fghr_e4[`RV_BHT_GHR_RANGE],
                                                     exu_i1_br_fghr_e4[`RV_BHT_GHR_RANGE]
                                                     }),
                                              .dout({dec_tlu_br0_wb_pkt.fghr[`RV_BHT_GHR_RANGE],
                                                     dec_tlu_br1_wb_pkt.fghr[`RV_BHT_GHR_RANGE]
                                                     }));

   rvdff #(2*$bits(dec_tlu_br0_addr_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]))
        bp_wb_index_ff (.*,  .clk(e4e5_clk),
                            .din({dec_tlu_br0_addr_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO],
                                  dec_tlu_br1_addr_e4[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]}),
                           .dout({dec_tlu_br0_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO],
                                  dec_tlu_br1_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]}));


   assign       ebreak_e4    =  (dec_tlu_packet_e4.pmu_i0_itype == EBREAK)  & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4 & ~dcsr[`DCSR_EBREAKM];
   assign       ecall_e4     =  (dec_tlu_packet_e4.pmu_i0_itype == ECALL)   & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4;
   assign       illegal_e4   =  ~dec_tlu_packet_e4.legal   & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4;
   assign       mret_e4      =  (dec_tlu_packet_e4.pmu_i0_itype == MRET)    & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4;

   assign       fence_i_e4   =  (dec_tlu_packet_e4.fence_i & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4);
   assign       ic_perr_e4    = 1'b0;
   assign       iccm_sbecc_e4 = 1'b0;
   assign       inst_acc_e4_raw  =  dec_tlu_packet_e4.icaf & dec_tlu_i0_valid_e4;
   assign       inst_acc_e4 = inst_acc_e4_raw & ~rfpc_i0_e4 & ~i0_trigger_hit_e4;
   assign       inst_acc_second_e4 = dec_tlu_packet_e4.icaf_second;

   assign       ebreak_to_debug_mode_e4 = (dec_tlu_packet_e4.pmu_i0_itype == EBREAK)  & dec_tlu_i0_valid_e4 & ~i0_trigger_hit_e4 & dcsr[`DCSR_EBREAKM];

   assign illegal_e4_qual = illegal_e4 & ~dec_tlu_dbg_halted;

   rvdff #(12)  exctype_wb_ff (.*, .clk(e4e5_clk),
                                 .din({ic_perr_e4, iccm_sbecc_e4, ebreak_e4, ebreak_to_debug_mode_e4, ecall_e4, illegal_e4,
                                       illegal_e4_qual, inst_misaligned_e4, inst_acc_e4, inst_acc_second_e4, fence_i_e4, mret_e4}),
                                .dout({ic_perr_wb, iccm_sbecc_wb, ebreak_wb, ebreak_to_debug_mode_wb, ecall_wb, illegal_raw_wb,
                                       illegal_wb, inst_misaligned_wb, inst_acc_wb, inst_acc_second_wb, fence_i_wb, mret_wb}));

   rvdff #(31) inst_misaligned_addr_wb_ff (.*, .clk(e4e5_clk),
                                            .din(inst_misaligned_addr_e4[31:1]),
                                            .dout(inst_misaligned_addr_wb[31:1]));

   assign dec_tlu_fence_i_wb = fence_i_wb;


   assign i0_exception_valid_e4 = (ebreak_e4 | ecall_e4 | illegal_e4 | inst_acc_e4 | inst_misaligned_e4) & ~rfpc_i0_e4 & ~dec_tlu_dbg_halted;


   assign exc_cause_e4[4:0] = ( ({5{take_ext_int}}        & 5'h0b) |
                                ({5{take_timer_int}}      & 5'h07) |
                                ({5{take_int_timer0_int}} & 5'h1d) |
                                 ({5{take_int_timer1_int}} & 5'h1c) |
                                 ({5{take_ce_int}}         & 5'h1e) |
                                 ({5{inst_misaligned_e4}}  & 5'h00) |
                                 ({5{illegal_e4}}          & 5'h02) |
                                ({5{ecall_e4}}            & 5'h0b) |
                                ({5{inst_acc_e4}}         & 5'h01) |
                                ({5{ebreak_e4 | trigger_hit_e4}}        & 5'h03) |
                                ({5{lsu_exc_ma_dc4 & ~lsu_exc_st_dc4}}  & 5'h04) |
                                ({5{lsu_exc_acc_dc4 & ~lsu_exc_st_dc4}} & 5'h05) |
                                ({5{lsu_exc_ma_dc4 & lsu_exc_st_dc4}}   & 5'h06) |
                                ({5{lsu_exc_acc_dc4 & lsu_exc_st_dc4}}  & 5'h07)
                                ) & ~{5{take_nmi}};


   assign mhwakeup_ready =  ~dec_csr_stall_int_ff & mstatus_mie_ns & mip[`MIP_MEIP]   & mie_ns[`MIE_MEIE];
   assign ext_int_ready   = ~dec_csr_stall_int_ff & mstatus_mie_ns & mip[`MIP_MEIP]   & mie_ns[`MIE_MEIE];
   assign ce_int_ready    = ~dec_csr_stall_int_ff & mstatus_mie_ns & mip[`MIP_MCEIP]  & mie_ns[`MIE_MCEIE];
   assign timer_int_ready = ~dec_csr_stall_int_ff & mstatus_mie_ns & mip[`MIP_MTIP]   & mie_ns[`MIE_MTIE];


   assign int_timer0_int_possible = mstatus_mie_ns & mie_ns[`MIE_MITIE0];
   assign int_timer0_int_ready = mip[`MIP_MITIP0] & int_timer0_int_possible;
   assign int_timer1_int_possible = mstatus_mie_ns & mie_ns[`MIE_MITIE1];
   assign int_timer1_int_ready = mip[`MIP_MITIP1] & int_timer1_int_possible;


   assign int_timer_stalled = dec_csr_stall_int_ff | synchronous_flush_e4 | exc_or_int_valid_wb | mret_wb | mret_e4;

   assign int_timer0_int_hold = (int_timer0_int_ready & (pmu_fw_tlu_halted_f | int_timer_stalled)) | (int_timer0_int_possible & int_timer0_int_hold_f & ~interrupt_valid & ~internal_dbg_halt_mode_f);
   assign int_timer1_int_hold = (int_timer1_int_ready & (pmu_fw_tlu_halted_f | int_timer_stalled)) | (int_timer1_int_possible & int_timer1_int_hold_f & ~interrupt_valid & ~internal_dbg_halt_mode_f);


   assign i0_mp_e4 = exu_i0_flush_lower_e4 & ~i0_trigger_hit_e4;
   assign i1_mp_e4 = exu_i1_flush_lower_e4 & ~trigger_hit_e4 & ~lsu_i0_rfnpc_dc4;

   assign internal_dbg_halt_timers = internal_dbg_halt_mode_f & ~dcsr_single_step_running;


   assign block_interrupts = ( (lsu_block_interrupts_e4 & ~dec_tlu_flush_lower_wb) |
                               (internal_dbg_halt_mode & (~dcsr_single_step_running | dec_tlu_i0_valid_e4)) |
                               internal_pmu_fw_halt_mode | i_cpu_halt_req_d1 |
                               take_nmi |
                               ebreak_to_debug_mode_e4 |
                               synchronous_flush_e4 |
                               exc_or_int_valid_wb |
                               mret_wb |
                               mret_e4
                               );

   assign take_ext_int = ext_int_ready & ~block_interrupts;
   assign take_ce_int  = ce_int_ready & ~ext_int_ready & ~block_interrupts;
   assign take_timer_int = timer_int_ready & ~ext_int_ready & ~ce_int_ready & ~block_interrupts;
   assign take_int_timer0_int = (int_timer0_int_ready | int_timer0_int_hold_f) & int_timer0_int_possible & ~dec_csr_stall_int_ff & ~timer_int_ready & ~ext_int_ready & ~ce_int_ready & ~block_interrupts;
   assign take_int_timer1_int = (int_timer1_int_ready | int_timer1_int_hold_f) & int_timer1_int_possible & ~dec_csr_stall_int_ff & ~(int_timer0_int_ready | int_timer0_int_hold_f) & ~timer_int_ready & ~ext_int_ready & ~ce_int_ready & ~block_interrupts;

   assign take_reset = reset_delayed & mpc_reset_run_req;
   assign take_nmi = nmi_int_detected & ~internal_pmu_fw_halt_mode & (~internal_dbg_halt_mode | (dcsr_single_step_running_f & dcsr[`DCSR_STEPIE] & ~dec_tlu_i0_valid_e4 & ~dcsr_single_step_done_f)) & ~synchronous_flush_e4 & ~mret_e4 & ~take_reset & ~ebreak_to_debug_mode_e4;

   assign interrupt_valid = take_ext_int | take_timer_int | take_nmi | take_ce_int | take_int_timer0_int | take_int_timer1_int;


   assign vectored_cause[5:0] = ({1'b0, exc_cause_e4[4:0]} << 1);
   assign {vpath_overflow_nc, vectored_path[31:1]} = {mtvec[30:1], 1'b0} + {25'b0, vectored_cause[5:0]};
   assign interrupt_path[31:1] = take_nmi ? nmi_vec[31:1] : ((mtvec[0] == 1'b1) ? vectored_path[31:1] : {mtvec[30:1], 1'b0});

   assign sel_npc_e4 = lsu_i0_rfnpc_dc4 | (lsu_i1_rfnpc_dc4 & tlu_i1_commit_cmt) | fence_i_e4 | (i_cpu_run_req_d1 & ~interrupt_valid);
   assign sel_npc_wb = (i_cpu_run_req_d1 & pmu_fw_tlu_halted_f) | pause_expired_e4;


   assign synchronous_flush_e4 = i0_exception_valid_e4 |
                                 i0_mp_e4 | i1_mp_e4 |
                                 rfpc_i0_e4 | rfpc_i1_e4 |
                                 lsu_exc_valid_e4 |
                                 fence_i_e4 |
                                 lsu_i0_rfnpc_dc4 | lsu_i1_rfnpc_dc4 |
                                 debug_resume_req_f |
                                 sel_npc_wb |
                                 dec_tlu_wr_pause_wb |
                                 trigger_hit_e4;

   assign tlu_flush_lower_e4 = interrupt_valid | mret_e4 | synchronous_flush_e4 | take_halt | take_reset;

   assign tlu_flush_path_e4[31:1] = take_reset ? rst_vec[31:1] :

                                     ( ({31{~take_nmi & i0_mp_e4}} & exu_i0_flush_path_e4[31:1]) |
                                      ({31{~take_nmi & ~i0_mp_e4 & i1_mp_e4 & ~rfpc_i0_e4 & ~lsu_i0_exc_dc4}} & exu_i1_flush_path_e4[31:1]) |
                                      ({31{~take_nmi & sel_npc_e4}} & npc_e4[31:1]) |
                                      ({31{~take_nmi & rfpc_i0_e4}} & dec_tlu_i0_pc_e4[31:1]) |
                                      ({31{~take_nmi & rfpc_i1_e4}} & dec_tlu_i1_pc_e4[31:1]) |
                                      ({31{interrupt_valid}} & interrupt_path[31:1]) |
                                      ({31{(i0_exception_valid_e4 | lsu_exc_valid_e4 | (trigger_hit_e4 & ~trigger_hit_dmode_e4)) & ~interrupt_valid}} & {mtvec[30:1],1'b0}) |
                                      ({31{~take_nmi & mret_e4 & ~wr_mepc_wb}} & mepc[31:1]) |
                                      ({31{~take_nmi & debug_resume_req_f}} & dpc[31:1]) |
                                      ({31{~take_nmi & sel_npc_wb}} & npc_wb[31:1]) |
                                      ({31{~take_nmi & mret_e4 & wr_mepc_wb}} & dec_csr_wrdata_wb[31:1]) );

   rvdff #(31)  flush_lower_ff (.*, .clk(e4e5_int_clk),
                                  .din({tlu_flush_path_e4[31:1]}),
                                 .dout({tlu_flush_path_wb[31:1]}));

   assign dec_tlu_flush_lower_wb = tlu_flush_lower_wb;
   assign dec_tlu_flush_path_wb[31:1] = tlu_flush_path_wb[31:1];


   assign exc_or_int_valid = lsu_exc_valid_e4 | i0_exception_valid_e4 | interrupt_valid | (trigger_hit_e4 & ~trigger_hit_dmode_e4);

   assign lsu_block_interrupts_dc3 = lsu_freeze_external_ints_dc3 & ~dec_tlu_flush_lower_wb;

   rvdff #(15)  excinfo_wb_ff (.*, .clk(e4e5_int_clk),
                                .din({interrupt_valid, i0_exception_valid_e4, exc_or_int_valid,
                                      exc_cause_e4[4:0], tlu_i0_commit_cmt & ~illegal_e4, tlu_i1_commit_cmt,
                                       mepc_trigger_hit_sel_pc_e4, trigger_hit_e4, i0_trigger_hit_e4,
                                      take_nmi, pause_expired_e4 }),
                               .dout({interrupt_valid_wb, i0_exception_valid_wb, exc_or_int_valid_wb,
                                      exc_cause_wb[4:0], i0_valid_wb, i1_valid_wb,
                                       mepc_trigger_hit_sel_pc_wb, trigger_hit_wb, i0_trigger_hit_wb,
                                      take_nmi_wb, pause_expired_wb}));


   `define MISA 12'h301


   `define MVENDORID 12'hf11
   `define MARCHID 12'hf12
   `define MIMPID 12'hf13
   `define MHARTID 12'hf14


   `define MSTATUS 12'h300


   assign dec_csr_wen_wb_mod = dec_csr_wen_wb & ~trigger_hit_wb;
   assign wr_mstatus_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MSTATUS);


   assign set_mie_pmu_fw_halt = ~mpmc_b_ns[1] & wr_mpmc_wb & dec_csr_wrdata_wb[0] & ~internal_dbg_halt_mode_f3;

   assign mstatus_ns[1:0] = ( ({2{~wr_mstatus_wb & exc_or_int_valid_wb}} & {(mstatus[`MSTATUS_MIE] | set_mie_pmu_fw_halt), 1'b0}) |
                              ({2{ wr_mstatus_wb & exc_or_int_valid_wb}} & {dec_csr_wrdata_wb[3], 1'b0}) |
                              ({2{mret_wb & ~exc_or_int_valid_wb}} & {1'b1, mstatus[1]}) |
                              ({2{set_mie_pmu_fw_halt & ~exc_or_int_valid_wb}} & {mstatus[1], 1'b1}) |
                              ({2{wr_mstatus_wb & ~exc_or_int_valid_wb}} & {dec_csr_wrdata_wb[7], dec_csr_wrdata_wb[3]}) |
                              ({2{~wr_mstatus_wb & ~exc_or_int_valid_wb & ~mret_wb & ~set_mie_pmu_fw_halt}} & mstatus[1:0]) );


   assign mstatus_mie_ns = mstatus_ns[`MSTATUS_MIE] & (~dcsr_single_step_running_f | dcsr[`DCSR_STEPIE]);
   rvdff #(2)  mstatus_ff (.*, .clk(free_clk), .din(mstatus_ns[1:0]), .dout(mstatus[1:0]));


   assign wr_fflags_wb = dec_csr_wen_wb_mod && (dec_csr_wraddr_wb == 12'h001);
   assign wr_frm_wb    = dec_csr_wen_wb_mod && (dec_csr_wraddr_wb == 12'h002);
   assign wr_fcsr_wb   = dec_csr_wen_wb_mod && (dec_csr_wraddr_wb == 12'h003);

   assign mstatus_fs_ns = wr_mstatus_wb ? dec_csr_wrdata_wb[14:13] :
                            (dec_fpu_dirty || wr_fflags_wb || wr_frm_wb || wr_fcsr_wb) ? 2'b11 :
                            mstatus_fs;
   assign fflags_ns = (wr_fcsr_wb ? dec_csr_wrdata_wb[4:0] :
                       wr_fflags_wb ? dec_csr_wrdata_wb[4:0] : fflags) |
                      ({5{dec_fpu_fflags_valid}} & dec_fpu_fflags);
   assign frm_ns = wr_fcsr_wb ? dec_csr_wrdata_wb[7:5] :
                   wr_frm_wb ? dec_csr_wrdata_wb[2:0] : frm;

   rvdff #(2) mstatus_fs_ff (.*, .clk(free_clk), .din(mstatus_fs_ns), .dout(mstatus_fs));
   rvdff #(5) fflags_ff (.*, .clk(free_clk), .din(fflags_ns), .dout(fflags));
   rvdff #(3) frm_ff (.*, .clk(free_clk), .din(frm_ns), .dout(frm));

   assign dec_tlu_frm = frm;
   assign dec_tlu_fp_enabled = |mstatus_fs;


   `define MTVEC 12'h305

   assign wr_mtvec_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTVEC);
   assign mtvec_ns[30:0] = {dec_csr_wrdata_wb[31:2], dec_csr_wrdata_wb[0]} ;
   rvdffe #(31)  mtvec_ff (.*, .en(wr_mtvec_wb), .din(mtvec_ns[30:0]), .dout(mtvec[30:0]));


   `define MIP 12'h344

   assign ce_int = (mdccme_ce_req | miccme_ce_req | mice_ce_req);

   assign mip_ns[5:0] = {ce_int, dec_timer_t0_pulse, dec_timer_t1_pulse, mexintpend, timer_int_sync, mip[0]};
   rvdff #(6)  mip_ff (.*, .clk(free_clk), .din(mip_ns[5:0]), .dout(mip[5:0]));


   `define MIE 12'h304

   assign wr_mie_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MIE);
   assign mie_ns[5:0] = wr_mie_wb ? {dec_csr_wrdata_wb[30:28], dec_csr_wrdata_wb[11], dec_csr_wrdata_wb[7], dec_csr_wrdata_wb[3]} : mie[5:0];
   rvdff #(6)  mie_ff (.*, .clk(csr_wr_clk), .din(mie_ns[5:0]), .dout(mie[5:0]));


   `define MCYCLEL 12'hb00


   assign wr_mcyclel_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MCYCLEL);

   logic mcyclel_cout_in;

   assign kill_ebreak_count_wb = ebreak_to_debug_mode_wb & dcsr[`DCSR_STOPC];

   assign mcyclel_cout_in = ~(kill_ebreak_count_wb | (dec_tlu_dbg_halted & dcsr[`DCSR_STOPC]) | dec_tlu_pmu_fw_halted);

   assign {mcyclel_cout, mcyclel_inc[31:0]} = mcyclel[31:0] + {31'b0, mcyclel_cout_in};
   assign mcyclel_ns[31:0] = wr_mcyclel_wb ? dec_csr_wrdata_wb[31:0] : mcyclel_inc[31:0];

   rvdffe #(32) mcyclel_ff      (.*, .en(wr_mcyclel_wb | mcyclel_cout_in), .din(mcyclel_ns[31:0]), .dout(mcyclel[31:0]));
   rvdff   #(1) mcyclef_cout_ff (.*, .clk(free_clk), .din(mcyclel_cout & ~wr_mcycleh_wb), .dout(mcyclel_cout_f));


   `define MCYCLEH 12'hb80

   assign wr_mcycleh_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MCYCLEH);

   assign {mcycleh_cout_nc, mcycleh_inc[31:0]} = mcycleh[31:0] + {31'b0, mcyclel_cout_f};
   assign mcycleh_ns[31:0] = wr_mcycleh_wb ? dec_csr_wrdata_wb[31:0] : mcycleh_inc[31:0];

   rvdffe #(32)  mcycleh_ff (.*, .en(wr_mcycleh_wb | mcyclel_cout_f), .din(mcycleh_ns[31:0]), .dout(mcycleh[31:0]));


   `define MINSTRETL 12'hb02
   logic i0_valid_no_ebreak_ecall_wb;
   assign i0_valid_no_ebreak_ecall_wb = i0_valid_wb & ~(ebreak_wb | ecall_wb | ebreak_to_debug_mode_wb);

   assign wr_minstretl_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MINSTRETL);

   assign {minstretl_cout, minstretl_inc[31:0]} = minstretl[31:0] + {31'b0,i0_valid_no_ebreak_ecall_wb} + {31'b0,i1_valid_wb};

   assign minstret_enable = i0_valid_no_ebreak_ecall_wb | i1_valid_wb;

   assign minstretl_ns[31:0] = wr_minstretl_wb ? dec_csr_wrdata_wb[31:0] : minstretl_inc[31:0];
   rvdffe #(32)  minstretl_ff (.*, .en(minstret_enable | wr_minstretl_wb), .din(minstretl_ns[31:0]), .dout(minstretl[31:0]));
   logic minstret_enable_f;
   rvdff #(2) minstretf_cout_ff (.*, .clk(free_clk), .din({minstret_enable, minstretl_cout & ~wr_minstreth_wb}), .dout({minstret_enable_f, minstretl_cout_f}));

   assign minstretl_read[31:0] = minstretl[31:0];


   `define MINSTRETH 12'hb82

   assign wr_minstreth_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MINSTRETH);

   assign {minstreth_cout_nc, minstreth_inc[31:0]} = minstreth[31:0] + {31'b0, minstretl_cout_f};
   assign minstreth_ns[31:0] = wr_minstreth_wb ? dec_csr_wrdata_wb[31:0] : minstreth_inc[31:0];
   rvdffe #(32)  minstreth_ff (.*, .en(minstret_enable_f | wr_minstreth_wb), .din(minstreth_ns[31:0]), .dout(minstreth[31:0]));

   assign minstreth_read[31:0] = minstreth_inc[31:0];


   `define MSCRATCH 12'h340

   assign wr_mscratch_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MSCRATCH);

   rvdffe #(32)  mscratch_ff (.*, .en(wr_mscratch_wb), .din(dec_csr_wrdata_wb[31:0]), .dout(mscratch[31:0]));


   `define MEPC 12'h341


   logic sel_exu_npc_e4, sel_flush_npc_e4, sel_i0_npc_e4, sel_hold_npc_e4;


   assign sel_exu_npc_e4 = ~dec_tlu_dbg_halted & ~tlu_flush_lower_wb & (dec_tlu_i0_valid_e4 | dec_tlu_i1_valid_e4) & ~(dec_tlu_i1_valid_e4 & lsu_i0_rfnpc_dc4);

   assign sel_i0_npc_e4 = ~dec_tlu_dbg_halted & ~tlu_flush_lower_wb & dec_tlu_i0_valid_e4 & lsu_i0_rfnpc_dc4 & dec_tlu_i1_valid_e4;

   assign sel_flush_npc_e4 = ~dec_tlu_dbg_halted & tlu_flush_lower_wb & ~dec_tlu_flush_noredir_wb;

   assign sel_hold_npc_e4 = ~sel_exu_npc_e4 & ~sel_flush_npc_e4 & ~sel_i0_npc_e4;

   assign npc_e4[31:1] = ( ({31{sel_exu_npc_e4}} & exu_npc_e4[31:1]) |
                           ({31{sel_i0_npc_e4}} & dec_tlu_i1_pc_e4[31:1]) |
                           ({31{~mpc_reset_run_req & reset_delayed}} & rst_vec[31:1]) |
                           ({31{(sel_flush_npc_e4)}} & tlu_flush_path_wb[31:1]) |
                           ({31{(sel_hold_npc_e4)}} & npc_wb[31:1]) );

   rvdffe #(31)  npwbc_ff (.*, .en(sel_i0_npc_e4 | sel_exu_npc_e4 | sel_flush_npc_e4 | reset_delayed), .din(npc_e4[31:1]), .dout(npc_wb[31:1]));


   logic pc0_valid_e4, pc1_valid_e4;
   assign pc0_valid_e4 = ~dec_tlu_dbg_halted & dec_tlu_i0_valid_e4;
   assign pc1_valid_e4 = ~dec_tlu_dbg_halted & dec_tlu_i0_valid_e4 & dec_tlu_i1_valid_e4 & ~lsu_i0_exc_dc4 & ~rfpc_i0_e4 & ~inst_acc_e4 & ~inst_misaligned_i0_e4 & ~i0_trigger_hit_e4;

   assign pc_e4[31:1] = ( ({31{ pc0_valid_e4 & ~pc1_valid_e4}} & dec_tlu_i0_pc_e4[31:1]) |
                          ({31{ pc1_valid_e4}} & dec_tlu_i1_pc_e4[31:1]) |
                          ({31{~pc0_valid_e4 & ~pc1_valid_e4}} & pc_wb[31:1])
                          );

   rvdffe #(31)  pwbc_ff (.*, .en(pc0_valid_e4 | pc1_valid_e4), .din(pc_e4[31:1]), .dout(pc_wb[31:1]));

   assign wr_mepc_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MEPC);

   assign mepc_ns[31:1] = ( ({31{i0_exception_valid_wb | lsu_exc_valid_wb | mepc_trigger_hit_sel_pc_wb}} & pc_wb[31:1]) |
                            ({31{interrupt_valid_wb}} & npc_wb[31:1]) |
                            ({31{wr_mepc_wb & ~exc_or_int_valid_wb}} & dec_csr_wrdata_wb[31:1]) |
                            ({31{~wr_mepc_wb & ~exc_or_int_valid_wb}} & mepc[31:1]) );


   rvdff #(31)  mepc_ff (.*, .clk(e4e5_int_clk), .din(mepc_ns[31:1]), .dout(mepc[31:1]));


   `define MCAUSE 12'h342

   assign wr_mcause_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MCAUSE);

   assign mcause_ns[31:0] = ( ({32{exc_or_int_valid_wb & take_nmi_wb & nmi_lsu_store_type_f}} & {32'hf000_0000}) |
                              ({32{exc_or_int_valid_wb & take_nmi_wb & nmi_lsu_load_type_f}} & {32'hf000_0001}) |
                              ({32{exc_or_int_valid_wb & ~take_nmi_wb}} & {interrupt_valid_wb, 26'b0, exc_cause_wb[4:0]}) |
                              ({32{wr_mcause_wb & ~exc_or_int_valid_wb}} & dec_csr_wrdata_wb[31:0]) |
                              ({32{~wr_mcause_wb & ~exc_or_int_valid_wb}} & mcause[31:0]) );

   rvdff #(32)  mcause_ff (.*, .clk(e4e5_int_clk), .din(mcause_ns[31:0]), .dout(mcause[31:0]));


   `define MTVAL 12'h343

   assign wr_mtval_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTVAL);
   assign mtval_capture_pc_wb = exc_or_int_valid_wb & (ebreak_wb | (inst_acc_wb & ~inst_acc_second_wb) | mepc_trigger_hit_sel_pc_wb) & ~take_nmi_wb;
   assign mtval_capture_pc_plus2_wb = exc_or_int_valid_wb & (inst_acc_wb & inst_acc_second_wb) & ~take_nmi_wb;
   assign mtval_capture_inst_wb = exc_or_int_valid_wb & illegal_wb & ~take_nmi_wb;
   assign mtval_capture_lsu_wb = exc_or_int_valid_wb & lsu_exc_valid_wb & ~take_nmi_wb;
   assign mtval_capture_target_wb = exc_or_int_valid_wb & inst_misaligned_wb & ~take_nmi_wb;
   assign mtval_clear_wb = exc_or_int_valid_wb & ~mtval_capture_pc_wb & ~mtval_capture_inst_wb & ~mtval_capture_lsu_wb & ~mtval_capture_target_wb & ~mepc_trigger_hit_sel_pc_wb;


   assign mtval_ns[31:0] = (({32{mtval_capture_pc_wb}} & {pc_wb[31:1], 1'b0}) |
                             ({32{mtval_capture_pc_plus2_wb}} & {pc_wb[31:1] + 31'b1, 1'b0}) |
                             ({32{mtval_capture_inst_wb}} & dec_illegal_inst[31:0]) |
                             ({32{mtval_capture_lsu_wb}} & lsu_error_pkt_addr_wb[31:0]) |
                             ({32{mtval_capture_target_wb}} & {inst_misaligned_addr_wb[31:1], 1'b0}) |
                             ({32{wr_mtval_wb & ~interrupt_valid_wb & ~mtval_capture_target_wb}} & dec_csr_wrdata_wb[31:0]) |
                             ({32{~take_nmi_wb & ~wr_mtval_wb & ~mtval_capture_pc_wb & ~mtval_capture_inst_wb & ~mtval_clear_wb & ~mtval_capture_lsu_wb & ~mtval_capture_target_wb}} & mtval[31:0]) );


   rvdff #(32)  mtval_ff (.*, .clk(e4e5_int_clk), .din(mtval_ns[31:0]), .dout(mtval[31:0]));


   `define MCGC 12'h7f8
   assign wr_mcgc_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MCGC);

   rvdffe #(9)  mcgc_ff (.*, .en(wr_mcgc_wb), .din(dec_csr_wrdata_wb[8:0]), .dout(mcgc[8:0]));

   assign dec_tlu_misc_clk_override = mcgc[8];
   assign dec_tlu_dec_clk_override  = mcgc[7];
   assign dec_tlu_exu_clk_override  = mcgc[6];
   assign dec_tlu_ifu_clk_override  = mcgc[5];
   assign dec_tlu_lsu_clk_override  = mcgc[4];
   assign dec_tlu_bus_clk_override  = mcgc[3];
   assign dec_tlu_dccm_clk_override = mcgc[1];
   assign dec_tlu_icm_clk_override  = mcgc[0];


   `define MFDC 12'h7f9

   assign wr_mfdc_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MFDC);

   rvdffe #(15)  mfdc_ff (.*, .en(wr_mfdc_wb), .din(mfdc_ns[14:0]), .dout(mfdc_int[14:0]));

   assign mfdc_ns[14:0] = {~dec_csr_wrdata_wb[18:16],dec_csr_wrdata_wb[13],dec_csr_wrdata_wb[10:0]};
   assign mfdc[18:0] = {~mfdc_int[14:12], 2'b0, mfdc_int[11], 2'b0, mfdc_int[10:0]};

   assign dec_tlu_dual_issue_disable = mfdc[10];
   assign dec_tlu_core_ecc_disable = 1'b1;
   assign dec_tlu_sec_alu_disable = mfdc[7];
   assign dec_tlu_sideeffect_posted_disable = mfdc[6];
   assign dec_tlu_non_blocking_disable = mfdc[5];
   assign dec_tlu_fast_div_disable = mfdc[4];
   assign dec_tlu_bpred_disable = mfdc[3];
   assign dec_tlu_wb_coalescing_disable = mfdc[2];
   assign dec_tlu_ld_miss_byp_wb_disable = mfdc[1];
   assign dec_tlu_pipelining_disable = mfdc[0];


   `define MCPC 12'h7c2
   assign dec_tlu_wr_pause_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MCPC) & ~interrupt_valid_wb;


   `define MRAC 12'h7c0

   assign wr_mrac_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MRAC);


   logic [31:0] mrac_in;
   assign mrac_in[31:0] = {dec_csr_wrdata_wb[31], dec_csr_wrdata_wb[30] & ~dec_csr_wrdata_wb[31],
                           dec_csr_wrdata_wb[29], dec_csr_wrdata_wb[28] & ~dec_csr_wrdata_wb[29],
                           dec_csr_wrdata_wb[27], dec_csr_wrdata_wb[26] & ~dec_csr_wrdata_wb[27],
                           dec_csr_wrdata_wb[25], dec_csr_wrdata_wb[24] & ~dec_csr_wrdata_wb[25],
                           dec_csr_wrdata_wb[23], dec_csr_wrdata_wb[22] & ~dec_csr_wrdata_wb[23],
                           dec_csr_wrdata_wb[21], dec_csr_wrdata_wb[20] & ~dec_csr_wrdata_wb[21],
                           dec_csr_wrdata_wb[19], dec_csr_wrdata_wb[18] & ~dec_csr_wrdata_wb[19],
                           dec_csr_wrdata_wb[17], dec_csr_wrdata_wb[16] & ~dec_csr_wrdata_wb[17],
                           dec_csr_wrdata_wb[15], dec_csr_wrdata_wb[14] & ~dec_csr_wrdata_wb[15],
                           dec_csr_wrdata_wb[13], dec_csr_wrdata_wb[12] & ~dec_csr_wrdata_wb[13],
                           dec_csr_wrdata_wb[11], dec_csr_wrdata_wb[10] & ~dec_csr_wrdata_wb[11],
                           dec_csr_wrdata_wb[9], dec_csr_wrdata_wb[8] & ~dec_csr_wrdata_wb[9],
                           dec_csr_wrdata_wb[7], dec_csr_wrdata_wb[6] & ~dec_csr_wrdata_wb[7],
                           dec_csr_wrdata_wb[5], dec_csr_wrdata_wb[4] & ~dec_csr_wrdata_wb[5],
                           dec_csr_wrdata_wb[3], dec_csr_wrdata_wb[2] & ~dec_csr_wrdata_wb[3],
                           dec_csr_wrdata_wb[1], dec_csr_wrdata_wb[0] & ~dec_csr_wrdata_wb[1]};

   rvdffe #(32)  mrac_ff (.*, .en(wr_mrac_wb), .din(mrac_in[31:0]), .dout(mrac[31:0]));


   assign dec_tlu_mrac_ff[31:0] = mrac[31:0];


   `define MDEAU 12'hbc0

   assign wr_mdeau_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MDEAU);


   `define MDSEAC 12'hfc0


   assign mdseac_locked_ns = mdseac_en | (mdseac_locked_f & ~wr_mdeau_wb);

   assign mdseac_en = (lsu_imprecise_error_store_any | lsu_imprecise_error_load_any) & ~nmi_int_detected_f & ~mdseac_locked_f;

   rvdffe #(32)  mdseac_ff (.*, .en(mdseac_en), .din(lsu_imprecise_error_addr_any[31:0]), .dout(mdseac[31:0]));


   `define MPMC 12'h7c6

   assign wr_mpmc_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MPMC);


   assign fw_halt_req = wr_mpmc_wb & dec_csr_wrdata_wb[0] & ~internal_dbg_halt_mode_f3 & ~interrupt_valid_wb;

   assign mpmc_b_ns[1] = wr_mpmc_wb ? ~dec_csr_wrdata_wb[1] : ~mpmc[1];
   rvdff #(1)  mpmc_ff (.*, .clk(csr_wr_clk), .din(mpmc_b_ns[1]), .dout(mpmc_b[1]));
   assign mpmc[1] = ~mpmc_b[1];


   `define MICECT 12'h7f0

   assign wr_micect_wb   = 1'b0;
   assign wr_miccmect_wb = 1'b0;
   assign wr_mdccmect_wb = 1'b0;
   assign micect         = '0;
   assign miccmect       = '0;
   assign mdccmect       = '0;
   assign micect_ns      = '0;
   assign miccmect_ns    = '0;
   assign mdccmect_ns    = '0;
   assign micect_inc     = '0;
   assign miccmect_inc   = '0;
   assign mdccmect_inc   = '0;
   assign micect_cout_nc = 1'b0;
   assign miccmect_cout_nc = 1'b0;
   assign mdccmect_cout_nc = 1'b0;
   assign mice_ce_req    = 1'b0;
   assign miccme_ce_req  = 1'b0;
   assign mdccme_ce_req  = 1'b0;


   `define DCSR 12'h7b0
   logic [8:6] dcsr_cause;


   assign trigger_hit_for_dscr_cause_wb = trigger_hit_dmode_wb | (trigger_hit_wb & dcsr_single_step_done_f);

   assign dcsr_cause[8:6] = ( ({3{dcsr_single_step_done_f & ~ebreak_to_debug_mode_wb & ~trigger_hit_for_dscr_cause_wb & ~debug_halt_req}} & 3'b100) |
                              ({3{debug_halt_req & ~ebreak_to_debug_mode_wb & ~trigger_hit_for_dscr_cause_wb}} &  3'b011) |
                              ({3{ebreak_to_debug_mode_wb & ~trigger_hit_for_dscr_cause_wb}} &  3'b001) |
                              ({3{trigger_hit_for_dscr_cause_wb}} & 3'b010));

   assign wr_dcsr_wb = allow_dbg_halt_csr_write & dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `DCSR);


   logic enter_debug_halt_req_le, dcsr_cause_upgradeable;
   assign dcsr_cause_upgradeable = internal_dbg_halt_mode_f & (dcsr[8:6] == 3'b011);
   assign enter_debug_halt_req_le = enter_debug_halt_req & (~dbg_tlu_halted | dcsr_cause_upgradeable);

   assign nmi_in_debug_mode = nmi_int_detected_f & internal_dbg_halt_mode_f;
   assign dcsr_ns[15:2] = enter_debug_halt_req_le ? {dcsr[15:9], dcsr_cause[8:6], dcsr[5:2]} :
                          (wr_dcsr_wb ? {dec_csr_wrdata_wb[15], 3'b0, dec_csr_wrdata_wb[11:10], 1'b0, dcsr[8:6], 2'b00, nmi_in_debug_mode | dcsr[3], dec_csr_wrdata_wb[2]} :
                           {dcsr[15:4], nmi_in_debug_mode, dcsr[2]});

   rvdffe #(14)  dcsr_ff (.*, .en(enter_debug_halt_req_le | wr_dcsr_wb | internal_dbg_halt_mode | take_nmi_wb), .din(dcsr_ns[15:2]), .dout(dcsr[15:2]));


   `define DPC 12'h7b1

   assign wr_dpc_wb = allow_dbg_halt_csr_write & dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `DPC);
   assign dpc_capture_npc = dbg_tlu_halted & ~dbg_tlu_halted_f & ~request_debug_mode_done_f;
   assign dpc_capture_pc = request_debug_mode_wb;

   assign dpc_ns[31:1] = ( ({31{~dpc_capture_pc & ~dpc_capture_npc & wr_dpc_wb}} & dec_csr_wrdata_wb[31:1]) |
                           ({31{dpc_capture_pc}} & pc_wb[31:1]) |
                           ({31{~dpc_capture_pc & dpc_capture_npc}} & npc_wb[31:1]) );

   rvdffe #(31)  dpc_ff (.*, .en(wr_dpc_wb | dpc_capture_pc | dpc_capture_npc), .din(dpc_ns[31:1]), .dout(dpc[31:1]));


   `define MTSEL 12'h7a0

   assign wr_mtsel_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTSEL);
   assign mtsel_ns[1:0] = wr_mtsel_wb ? {dec_csr_wrdata_wb[1:0]} : mtsel[1:0];

   rvdff #(2)  mtsel_ff (.*, .clk(csr_wr_clk), .din(mtsel_ns[1:0]), .dout(mtsel[1:0]));


   `define MTDATA1 12'h7a1


   assign tdata_load = dec_csr_wrdata_wb[0] & ~dec_csr_wrdata_wb[19];

   assign tdata_opcode = dec_csr_wrdata_wb[2] & ~dec_csr_wrdata_wb[19];

   assign tdata_action = (dec_csr_wrdata_wb[27] & dbg_tlu_halted_f) & dec_csr_wrdata_wb[12];


   assign tdata_chain = mtsel[0] ? 1'b0 :
                        mtsel[1] ?  dec_csr_wrdata_wb[11] & ~(mtdata1_t3[`MTDATA1_DMODE] & ~dec_csr_wrdata_wb[27]) :
                                    dec_csr_wrdata_wb[11] & ~(mtdata1_t1[`MTDATA1_DMODE] & ~dec_csr_wrdata_wb[27]);


   assign tdata_kill_write = mtsel[1] ? dec_csr_wrdata_wb[27] & (~mtdata1_t2[`MTDATA1_DMODE] & mtdata1_t2[`MTDATA1_CHAIN]) :
                                        dec_csr_wrdata_wb[27] & (~mtdata1_t0[`MTDATA1_DMODE] & mtdata1_t0[`MTDATA1_CHAIN]) ;

   assign tdata_wrdata_wb[9:0]  = {dec_csr_wrdata_wb[27] & dbg_tlu_halted_f,
                                   dec_csr_wrdata_wb[20:19],
                                   tdata_action,
                                   tdata_chain,
                                   dec_csr_wrdata_wb[7:6],
                                   tdata_opcode,
                                   dec_csr_wrdata_wb[1],
                                   tdata_load};


   assign wr_mtdata1_t0_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA1) & (mtsel[1:0] == 2'b0) & (~mtdata1_t0[`MTDATA1_DMODE] | dbg_tlu_halted_f);
   assign mtdata1_t0_ns[9:0] = wr_mtdata1_t0_wb ? tdata_wrdata_wb[9:0] :
                                {mtdata1_t0[9], update_hit_bit_wb[0] | mtdata1_t0[8], mtdata1_t0[7:0]};

   assign wr_mtdata1_t1_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA1) & (mtsel[1:0] == 2'b01) & (~mtdata1_t1[`MTDATA1_DMODE] | dbg_tlu_halted_f) & ~tdata_kill_write;
   assign mtdata1_t1_ns[9:0] = wr_mtdata1_t1_wb ? tdata_wrdata_wb[9:0] :
                                {mtdata1_t1[9], update_hit_bit_wb[1] | mtdata1_t1[8], mtdata1_t1[7:0]};

   assign wr_mtdata1_t2_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA1) & (mtsel[1:0] == 2'b10) & (~mtdata1_t2[`MTDATA1_DMODE] | dbg_tlu_halted_f);
   assign mtdata1_t2_ns[9:0] = wr_mtdata1_t2_wb ? tdata_wrdata_wb[9:0] :
                                {mtdata1_t2[9], update_hit_bit_wb[2] | mtdata1_t2[8], mtdata1_t2[7:0]};

   assign wr_mtdata1_t3_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA1) & (mtsel[1:0] == 2'b11) & (~mtdata1_t3[`MTDATA1_DMODE] | dbg_tlu_halted_f) & ~tdata_kill_write;
   assign mtdata1_t3_ns[9:0] = wr_mtdata1_t3_wb ? tdata_wrdata_wb[9:0] :
                                {mtdata1_t3[9], update_hit_bit_wb[3] | mtdata1_t3[8], mtdata1_t3[7:0]};


   rvdff #(10)  mtdata1_t0_ff (.*, .clk(active_clk), .din(mtdata1_t0_ns[9:0]), .dout(mtdata1_t0[9:0]));
   rvdff #(10)  mtdata1_t1_ff (.*, .clk(active_clk), .din(mtdata1_t1_ns[9:0]), .dout(mtdata1_t1[9:0]));
   rvdff #(10)  mtdata1_t2_ff (.*, .clk(active_clk), .din(mtdata1_t2_ns[9:0]), .dout(mtdata1_t2[9:0]));
   rvdff #(10)  mtdata1_t3_ff (.*, .clk(active_clk), .din(mtdata1_t3_ns[9:0]), .dout(mtdata1_t3[9:0]));

   assign mtdata1_tsel_out[31:0] = ( ({32{(mtsel[1:0] == 2'b00)}} & {4'h2, mtdata1_t0[9], 6'b011111, mtdata1_t0[8:7], 6'b0, mtdata1_t0[6:5], 3'b0, mtdata1_t0[4:3], 3'b0, mtdata1_t0[2:0]}) |
                                     ({32{(mtsel[1:0] == 2'b01)}} & {4'h2, mtdata1_t1[9], 6'b011111, mtdata1_t1[8:7], 6'b0, mtdata1_t1[6:5], 3'b0, mtdata1_t1[4:3], 3'b0, mtdata1_t1[2:0]}) |
                                     ({32{(mtsel[1:0] == 2'b10)}} & {4'h2, mtdata1_t2[9], 6'b011111, mtdata1_t2[8:7], 6'b0, mtdata1_t2[6:5], 3'b0, mtdata1_t2[4:3], 3'b0, mtdata1_t2[2:0]}) |
                                     ({32{(mtsel[1:0] == 2'b11)}} & {4'h2, mtdata1_t3[9], 6'b011111, mtdata1_t3[8:7], 6'b0, mtdata1_t3[6:5], 3'b0, mtdata1_t3[4:3], 3'b0, mtdata1_t3[2:0]}));

   assign trigger_pkt_any[0].select = mtdata1_t0[`MTDATA1_SEL];
   assign trigger_pkt_any[0].match = mtdata1_t0[`MTDATA1_MATCH];
   assign trigger_pkt_any[0].store = mtdata1_t0[`MTDATA1_ST];
   assign trigger_pkt_any[0].load = mtdata1_t0[`MTDATA1_LD];
   assign trigger_pkt_any[0].execute = mtdata1_t0[`MTDATA1_EXE];
   assign trigger_pkt_any[0].m = mtdata1_t0[`MTDATA1_M_ENABLED];

   assign trigger_pkt_any[1].select = mtdata1_t1[`MTDATA1_SEL];
   assign trigger_pkt_any[1].match = mtdata1_t1[`MTDATA1_MATCH];
   assign trigger_pkt_any[1].store = mtdata1_t1[`MTDATA1_ST];
   assign trigger_pkt_any[1].load = mtdata1_t1[`MTDATA1_LD];
   assign trigger_pkt_any[1].execute = mtdata1_t1[`MTDATA1_EXE];
   assign trigger_pkt_any[1].m = mtdata1_t1[`MTDATA1_M_ENABLED];

   assign trigger_pkt_any[2].select = mtdata1_t2[`MTDATA1_SEL];
   assign trigger_pkt_any[2].match = mtdata1_t2[`MTDATA1_MATCH];
   assign trigger_pkt_any[2].store = mtdata1_t2[`MTDATA1_ST];
   assign trigger_pkt_any[2].load = mtdata1_t2[`MTDATA1_LD];
   assign trigger_pkt_any[2].execute = mtdata1_t2[`MTDATA1_EXE];
   assign trigger_pkt_any[2].m = mtdata1_t2[`MTDATA1_M_ENABLED];

   assign trigger_pkt_any[3].select = mtdata1_t3[`MTDATA1_SEL];
   assign trigger_pkt_any[3].match = mtdata1_t3[`MTDATA1_MATCH];
   assign trigger_pkt_any[3].store = mtdata1_t3[`MTDATA1_ST];
   assign trigger_pkt_any[3].load = mtdata1_t3[`MTDATA1_LD];
   assign trigger_pkt_any[3].execute = mtdata1_t3[`MTDATA1_EXE];
   assign trigger_pkt_any[3].m = mtdata1_t3[`MTDATA1_M_ENABLED];


   `define MTDATA2 12'h7a2


   assign wr_mtdata2_t0_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA2) & (mtsel[1:0] == 2'b0)  & (~mtdata1_t0[`MTDATA1_DMODE] | dbg_tlu_halted_f);
   assign wr_mtdata2_t1_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA2) & (mtsel[1:0] == 2'b01) & (~mtdata1_t1[`MTDATA1_DMODE] | dbg_tlu_halted_f);
   assign wr_mtdata2_t2_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA2) & (mtsel[1:0] == 2'b10) & (~mtdata1_t2[`MTDATA1_DMODE] | dbg_tlu_halted_f);
   assign wr_mtdata2_t3_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MTDATA2) & (mtsel[1:0] == 2'b11) & (~mtdata1_t3[`MTDATA1_DMODE] | dbg_tlu_halted_f);

   rvdffe #(32)  mtdata2_t0_ff (.*, .en(wr_mtdata2_t0_wb), .din(dec_csr_wrdata_wb[31:0]), .dout(mtdata2_t0[31:0]));
   rvdffe #(32)  mtdata2_t1_ff (.*, .en(wr_mtdata2_t1_wb), .din(dec_csr_wrdata_wb[31:0]), .dout(mtdata2_t1[31:0]));
   rvdffe #(32)  mtdata2_t2_ff (.*, .en(wr_mtdata2_t2_wb), .din(dec_csr_wrdata_wb[31:0]), .dout(mtdata2_t2[31:0]));
   rvdffe #(32)  mtdata2_t3_ff (.*, .en(wr_mtdata2_t3_wb), .din(dec_csr_wrdata_wb[31:0]), .dout(mtdata2_t3[31:0]));

   assign mtdata2_tsel_out[31:0] = ( ({32{(mtsel[1:0] == 2'b00)}} & mtdata2_t0[31:0]) |
                                     ({32{(mtsel[1:0] == 2'b01)}} & mtdata2_t1[31:0]) |
                                     ({32{(mtsel[1:0] == 2'b10)}} & mtdata2_t2[31:0]) |
                                     ({32{(mtsel[1:0] == 2'b11)}} & mtdata2_t3[31:0]));

   assign trigger_pkt_any[0].tdata2[31:0] = mtdata2_t0[31:0];
   assign trigger_pkt_any[1].tdata2[31:0] = mtdata2_t1[31:0];
   assign trigger_pkt_any[2].tdata2[31:0] = mtdata2_t2[31:0];
   assign trigger_pkt_any[3].tdata2[31:0] = mtdata2_t3[31:0];


   `define MHPME_NOEVENT         6'd0
   `define MHPME_CLK_ACTIVE      6'd1
   `define MHPME_FETCH_HIT       6'd2
   `define MHPME_FETCH_MISS      6'd3
   `define MHPME_INST_COMMIT     6'd4
   `define MHPME_INST_COMMIT_16B 6'd5
   `define MHPME_INST_COMMIT_32B 6'd6
   `define MHPME_INST_ALIGNED    6'd7
   `define MHPME_INST_DECODED    6'd8
   `define MHPME_INST_MUL        6'd9
   `define MHPME_INST_DIV        6'd10
   `define MHPME_INST_LOAD       6'd11
   `define MHPME_INST_STORE      6'd12
   `define MHPME_INST_MALOAD     6'd13
   `define MHPME_INST_MASTORE    6'd14
   `define MHPME_INST_ALU        6'd15
   `define MHPME_INST_CSRREAD    6'd16
   `define MHPME_INST_CSRRW      6'd17
   `define MHPME_INST_CSRWRITE   6'd18
   `define MHPME_INST_EBREAK     6'd19
   `define MHPME_INST_ECALL      6'd20
   `define MHPME_INST_FENCE      6'd21
   `define MHPME_INST_FENCEI     6'd22
   `define MHPME_INST_MRET       6'd23
   `define MHPME_INST_BRANCH     6'd24
   `define MHPME_BRANCH_MP       6'd25
   `define MHPME_BRANCH_TAKEN    6'd26
   `define MHPME_BRANCH_NOTP     6'd27
   `define MHPME_FETCH_STALL     6'd28
   `define MHPME_ALGNR_STALL     6'd29
   `define MHPME_DECODE_STALL    6'd30
   `define MHPME_POSTSYNC_STALL  6'd31
   `define MHPME_PRESYNC_STALL   6'd32
   `define MHPME_LSU_FREEZE      6'd33
   `define MHPME_LSU_SB_WB_STALL 6'd34
   `define MHPME_EXC_TAKEN       6'd37
   `define MHPME_TIMER_INT_TAKEN 6'd38
   `define MHPME_EXT_INT_TAKEN   6'd39
   `define MHPME_FLUSH_LOWER     6'd40
   `define MHPME_BR_ERROR        6'd41
   `define MHPME_IBUS_TRANS      6'd42
   `define MHPME_DBUS_TRANS      6'd43
   `define MHPME_DBUS_MA_TRANS   6'd44
   `define MHPME_IBUS_ERROR      6'd45
   `define MHPME_DBUS_ERROR      6'd46
   `define MHPME_IBUS_STALL      6'd47
   `define MHPME_DBUS_STALL      6'd48
   `define MHPME_INT_DISABLED    6'd49
   `define MHPME_INT_STALLED     6'd50


   logic [3:0][1:0] mhpmc_inc_e4, mhpmc_inc_wb;
   logic [3:0][5:0] mhpme_vec;
   logic            mhpmc3_wr_en0, mhpmc3_wr_en1, mhpmc3_wr_en;
   logic            mhpmc4_wr_en0, mhpmc4_wr_en1, mhpmc4_wr_en;
   logic            mhpmc5_wr_en0, mhpmc5_wr_en1, mhpmc5_wr_en;
   logic            mhpmc6_wr_en0, mhpmc6_wr_en1, mhpmc6_wr_en;
   logic            mhpmc3h_wr_en0, mhpmc3h_wr_en;
   logic            mhpmc4h_wr_en0, mhpmc4h_wr_en;
   logic            mhpmc5h_wr_en0, mhpmc5h_wr_en;
   logic            mhpmc6h_wr_en0, mhpmc6h_wr_en;
   logic [63:0]     mhpmc3_incr, mhpmc4_incr, mhpmc5_incr, mhpmc6_incr;


   assign mhpme_vec[0][5:0] = mhpme3[5:0];
   assign mhpme_vec[1][5:0] = mhpme4[5:0];
   assign mhpme_vec[2][5:0] = mhpme5[5:0];
   assign mhpme_vec[3][5:0] = mhpme6[5:0];


   logic [3:0] pmu_i0_itype_qual, pmu_i1_itype_qual;
   assign pmu_i0_itype_qual[3:0] = dec_tlu_packet_e4.pmu_i0_itype[3:0] & {4{tlu_i0_commit_cmt}};
   assign pmu_i1_itype_qual[3:0] = dec_tlu_packet_e4.pmu_i1_itype[3:0] & {4{tlu_i1_commit_cmt}};


   for (genvar i=0 ; i < 4; i++) begin
      assign mhpmc_inc_e4[i][1:0] =  {2{mgpmc}} &
           (
             ({2{(mhpme_vec[i][5:0] == `MHPME_CLK_ACTIVE      )}} & 2'b01) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_FETCH_HIT       )}} & {1'b0, ifu_pmu_fetch_hit}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_FETCH_MISS      )}} & {1'b0, ifu_pmu_fetch_miss}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_COMMIT     )}} & {tlu_i1_commit_cmt, tlu_i0_commit_cmt & ~illegal_e4}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_COMMIT_16B )}} & {tlu_i1_commit_cmt & ~exu_pmu_i1_pc4, tlu_i0_commit_cmt & ~exu_pmu_i0_pc4 & ~illegal_e4}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_COMMIT_32B )}} & {tlu_i1_commit_cmt &  exu_pmu_i1_pc4, tlu_i0_commit_cmt &  exu_pmu_i0_pc4 & ~illegal_e4}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_ALIGNED    )}} & ifu_pmu_instr_aligned[1:0])  |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_DECODED    )}} & dec_pmu_instr_decoded[1:0])  |
             ({2{(mhpme_vec[i][5:0] == `MHPME_ALGNR_STALL     )}} & {1'b0,ifu_pmu_align_stall})  |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DECODE_STALL    )}} & {1'b0,dec_pmu_decode_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_MUL        )}} & {(pmu_i1_itype_qual[3:0] == MUL),     (pmu_i0_itype_qual[3:0] == MUL)})     |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_DIV        )}} & {1'b0, dec_tlu_packet_e4.pmu_divide & tlu_i0_commit_cmt})     |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_LOAD       )}} & {(pmu_i1_itype_qual[3:0] == LOAD),    (pmu_i0_itype_qual[3:0] == LOAD)})    |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_STORE      )}} & {(pmu_i1_itype_qual[3:0] == STORE),   (pmu_i0_itype_qual[3:0] == STORE)})   |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_MALOAD     )}} & {(pmu_i1_itype_qual[3:0] == LOAD),    (pmu_i0_itype_qual[3:0] == LOAD)} &
                                                                      {2{dec_tlu_packet_e4.pmu_lsu_misaligned}})    |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_MASTORE    )}} & {(pmu_i1_itype_qual[3:0] == STORE),   (pmu_i0_itype_qual[3:0] == STORE)} &
                                                                      {2{dec_tlu_packet_e4.pmu_lsu_misaligned}})    |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_ALU        )}} & {(pmu_i1_itype_qual[3:0] == ALU),     (pmu_i0_itype_qual[3:0] == ALU)})     |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_CSRREAD    )}} & {1'b0, (pmu_i0_itype_qual[3:0] == CSRREAD)}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_CSRWRITE   )}} & {1'b0, (pmu_i0_itype_qual[3:0] == CSRWRITE)})|
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_CSRRW      )}} & {1'b0, (pmu_i0_itype_qual[3:0] == CSRRW)})   |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_EBREAK     )}} & {1'b0, (pmu_i0_itype_qual[3:0] == EBREAK)})  |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_ECALL      )}} & {1'b0, (pmu_i0_itype_qual[3:0] == ECALL)})   |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_FENCE      )}} & {1'b0, (pmu_i0_itype_qual[3:0] == FENCE)})   |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_FENCEI     )}} & {1'b0, (pmu_i0_itype_qual[3:0] == FENCEI)})  |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_MRET       )}} & {1'b0, (pmu_i0_itype_qual[3:0] == MRET)})    |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INST_BRANCH     )}} & {((pmu_i1_itype_qual[3:0] == CONDBR) | (pmu_i1_itype_qual[3:0] == JAL)),
                                                                     ((pmu_i0_itype_qual[3:0] == CONDBR) | (pmu_i0_itype_qual[3:0] == JAL))})   |
             ({2{(mhpme_vec[i][5:0] == `MHPME_BRANCH_MP       )}} & {exu_pmu_i1_br_misp & tlu_i1_commit_cmt, exu_pmu_i0_br_misp & tlu_i0_commit_cmt}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_BRANCH_TAKEN    )}} & {exu_pmu_i1_br_ataken & tlu_i1_commit_cmt, exu_pmu_i0_br_ataken & tlu_i0_commit_cmt}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_BRANCH_NOTP     )}} & {dec_tlu_packet_e4.pmu_i1_br_unpred & tlu_i1_commit_cmt, dec_tlu_packet_e4.pmu_i0_br_unpred & tlu_i0_commit_cmt}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_FETCH_STALL     )}} & {1'b0, ifu_pmu_fetch_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_ALGNR_STALL     )}} & {1'b0, ifu_pmu_align_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DECODE_STALL    )}} & {1'b0, dec_pmu_decode_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_POSTSYNC_STALL  )}} & {1'b0,dec_pmu_postsync_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_PRESYNC_STALL   )}} & {1'b0,dec_pmu_presync_stall}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_LSU_FREEZE      )}} & {1'b0, lsu_freeze_dc3}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_LSU_SB_WB_STALL )}} & {1'b0, lsu_store_stall_any}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_EXC_TAKEN       )}} & {1'b0, (i0_exception_valid_e4 | trigger_hit_e4 | lsu_exc_valid_e4)}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_TIMER_INT_TAKEN )}} & {1'b0, take_timer_int | take_int_timer0_int | take_int_timer1_int}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_EXT_INT_TAKEN   )}} & {1'b0, take_ext_int}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_FLUSH_LOWER     )}} & {1'b0, tlu_flush_lower_e4}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_BR_ERROR        )}} & {(dec_tlu_br1_error_e4 | dec_tlu_br1_start_error_e4) & rfpc_i1_e4, (dec_tlu_br0_error_e4 | dec_tlu_br0_start_error_e4) & rfpc_i0_e4}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_IBUS_TRANS      )}} & {1'b0, ifu_pmu_bus_trxn}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DBUS_TRANS      )}} & {1'b0, lsu_pmu_bus_trxn}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DBUS_MA_TRANS   )}} & {1'b0, lsu_pmu_bus_misaligned}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_IBUS_ERROR      )}} & {1'b0, ifu_pmu_bus_error}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DBUS_ERROR      )}} & {1'b0, lsu_pmu_bus_error}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_IBUS_STALL      )}} & {1'b0, ifu_pmu_bus_busy}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_DBUS_STALL      )}} & {1'b0, lsu_pmu_bus_busy}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INT_DISABLED    )}} & {1'b0, ~mstatus[`MSTATUS_MIE]}) |
             ({2{(mhpme_vec[i][5:0] == `MHPME_INT_STALLED     )}} & {1'b0, ~mstatus[`MSTATUS_MIE] & |(mip[5:0] & mie[5:0])})
             );
   end

   rvdff #(2) pmu0inc_ff (.*, .clk(free_clk), .din(mhpmc_inc_e4[0][1:0]), .dout(mhpmc_inc_wb[0][1:0]));
   rvdff #(2) pmu1inc_ff (.*, .clk(free_clk), .din(mhpmc_inc_e4[1][1:0]), .dout(mhpmc_inc_wb[1][1:0]));
   rvdff #(2) pmu2inc_ff (.*, .clk(free_clk), .din(mhpmc_inc_e4[2][1:0]), .dout(mhpmc_inc_wb[2][1:0]));
   rvdff #(2) pmu3inc_ff (.*, .clk(free_clk), .din(mhpmc_inc_e4[3][1:0]), .dout(mhpmc_inc_wb[3][1:0]));

   assign perfcnt_halted = ((dec_tlu_dbg_halted & dcsr[`DCSR_STOPC]) | dec_tlu_pmu_fw_halted);

   assign dec_tlu_perfcnt0[1:0] = mhpmc_inc_wb[0][1:0] & ~{2{perfcnt_halted}};
   assign dec_tlu_perfcnt1[1:0] = mhpmc_inc_wb[1][1:0] & ~{2{perfcnt_halted}};
   assign dec_tlu_perfcnt2[1:0] = mhpmc_inc_wb[2][1:0] & ~{2{perfcnt_halted}};
   assign dec_tlu_perfcnt3[1:0] = mhpmc_inc_wb[3][1:0] & ~{2{perfcnt_halted}};


   `define MHPMC3 12'hB03
   `define MHPMC3H 12'hB83

   assign mhpmc3_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC3);
   assign mhpmc3_wr_en1 = ~perfcnt_halted & (|(mhpmc_inc_wb[0][1:0]));
   assign mhpmc3_wr_en  = mhpmc3_wr_en0 | mhpmc3_wr_en1;
   assign mhpmc3_incr[63:0] = {mhpmc3h[31:0],mhpmc3[31:0]} + {63'b0,mhpmc_inc_wb[0][1]} + {63'b0,mhpmc_inc_wb[0][0]};
   assign mhpmc3_ns[31:0] = mhpmc3_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc3_incr[31:0];
   rvdffe #(32)  mhpmc3_ff (.*, .en(mhpmc3_wr_en), .din(mhpmc3_ns[31:0]), .dout(mhpmc3[31:0]));

   assign mhpmc3h_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC3H);
   assign mhpmc3h_wr_en  = mhpmc3h_wr_en0 | mhpmc3_wr_en1;
   assign mhpmc3h_ns[31:0] = mhpmc3h_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc3_incr[63:32];
   rvdffe #(32)  mhpmc3h_ff (.*, .en(mhpmc3h_wr_en), .din(mhpmc3h_ns[31:0]), .dout(mhpmc3h[31:0]));


   `define MHPMC4 12'hB04
   `define MHPMC4H 12'hB84

   assign mhpmc4_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC4);
   assign mhpmc4_wr_en1 = ~perfcnt_halted & (|(mhpmc_inc_wb[1][1:0]));
   assign mhpmc4_wr_en  = mhpmc4_wr_en0 | mhpmc4_wr_en1;
   assign mhpmc4_incr[63:0] = {mhpmc4h[31:0],mhpmc4[31:0]} + {63'b0,mhpmc_inc_wb[1][1]} + {63'b0,mhpmc_inc_wb[1][0]};
   assign mhpmc4_ns[31:0] = mhpmc4_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc4_incr[31:0];
   rvdffe #(32)  mhpmc4_ff (.*, .en(mhpmc4_wr_en), .din(mhpmc4_ns[31:0]), .dout(mhpmc4[31:0]));

   assign mhpmc4h_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC4H);
   assign mhpmc4h_wr_en  = mhpmc4h_wr_en0 | mhpmc4_wr_en1;
   assign mhpmc4h_ns[31:0] = mhpmc4h_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc4_incr[63:32];
   rvdffe #(32)  mhpmc4h_ff (.*, .en(mhpmc4h_wr_en), .din(mhpmc4h_ns[31:0]), .dout(mhpmc4h[31:0]));


   `define MHPMC5 12'hB05
   `define MHPMC5H 12'hB85

   assign mhpmc5_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC5);
   assign mhpmc5_wr_en1 = ~perfcnt_halted & (|(mhpmc_inc_wb[2][1:0]));
   assign mhpmc5_wr_en  = mhpmc5_wr_en0 | mhpmc5_wr_en1;
   assign mhpmc5_incr[63:0] = {mhpmc5h[31:0],mhpmc5[31:0]} + {63'b0,mhpmc_inc_wb[2][1]} + {63'b0,mhpmc_inc_wb[2][0]};
   assign mhpmc5_ns[31:0] = mhpmc5_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc5_incr[31:0];
   rvdffe #(32)  mhpmc5_ff (.*, .en(mhpmc5_wr_en), .din(mhpmc5_ns[31:0]), .dout(mhpmc5[31:0]));

   assign mhpmc5h_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC5H);
   assign mhpmc5h_wr_en  = mhpmc5h_wr_en0 | mhpmc5_wr_en1;
   assign mhpmc5h_ns[31:0] = mhpmc5h_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc5_incr[63:32];
   rvdffe #(32)  mhpmc5h_ff (.*, .en(mhpmc5h_wr_en), .din(mhpmc5h_ns[31:0]), .dout(mhpmc5h[31:0]));


   `define MHPMC6 12'hB06
   `define MHPMC6H 12'hB86

   assign mhpmc6_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC6);
   assign mhpmc6_wr_en1 = ~perfcnt_halted & (|(mhpmc_inc_wb[3][1:0]));
   assign mhpmc6_wr_en  = mhpmc6_wr_en0 | mhpmc6_wr_en1;
   assign mhpmc6_incr[63:0] = {mhpmc6h[31:0],mhpmc6[31:0]} + {63'b0,mhpmc_inc_wb[3][1]} + {63'b0,mhpmc_inc_wb[3][0]};
   assign mhpmc6_ns[31:0] = mhpmc6_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc6_incr[31:0];
   rvdffe #(32)  mhpmc6_ff (.*, .en(mhpmc6_wr_en), .din(mhpmc6_ns[31:0]), .dout(mhpmc6[31:0]));

   assign mhpmc6h_wr_en0 = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPMC6H);
   assign mhpmc6h_wr_en  = mhpmc6h_wr_en0 | mhpmc6_wr_en1;
   assign mhpmc6h_ns[31:0] = mhpmc6h_wr_en0 ? dec_csr_wrdata_wb[31:0] : mhpmc6_incr[63:32];
   rvdffe #(32)  mhpmc6h_ff (.*, .en(mhpmc6h_wr_en), .din(mhpmc6h_ns[31:0]), .dout(mhpmc6h[31:0]));


   `define MHPME3 12'h323


   logic [5:0] event_saturate_wb;
   assign event_saturate_wb[5:0] = ((dec_csr_wrdata_wb[5:0] > 6'd50) | (|dec_csr_wrdata_wb[31:6])) ? 6'd50 : dec_csr_wrdata_wb[5:0];

   assign wr_mhpme3_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPME3);
   rvdffs #(6)  mhpme3_ff (.*, .clk(active_clk), .en(wr_mhpme3_wb), .din(event_saturate_wb[5:0]), .dout(mhpme3[5:0]));


   `define MHPME4 12'h324

   assign wr_mhpme4_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPME4);
   rvdffs #(6)  mhpme4_ff (.*, .clk(active_clk), .en(wr_mhpme4_wb), .din(event_saturate_wb[5:0]), .dout(mhpme4[5:0]));


   `define MHPME5 12'h325

   assign wr_mhpme5_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPME5);
   rvdffs #(6)  mhpme5_ff (.*, .clk(active_clk), .en(wr_mhpme5_wb), .din(event_saturate_wb[5:0]), .dout(mhpme5[5:0]));


   `define MHPME6 12'h326

   assign wr_mhpme6_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MHPME6);
   rvdffs #(6)  mhpme6_ff (.*, .clk(active_clk), .en(wr_mhpme6_wb), .din(event_saturate_wb[5:0]), .dout(mhpme6[5:0]));


   `define MGPMC 12'h7d0

   assign wr_mgpmc_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MGPMC);
   rvdffs #(1)  mgpmc_ff (.*, .clk(active_clk), .en(wr_mgpmc_wb), .din(~dec_csr_wrdata_wb[0]), .dout(mgpmc_b));
   assign mgpmc = ~mgpmc_b;


   logic usoc_tclk;

   rvoclkhdr usoctrace_cgc ( .en(i0_valid_wb | exc_or_int_valid_wb | interrupt_valid_wb | dec_tlu_i0_valid_wb1 |
                                dec_tlu_i0_exc_valid_wb1 | dec_tlu_i1_exc_valid_wb1 | dec_tlu_int_valid_wb1 | clk_override), .l1clk(usoc_tclk), .* );
   rvdff #(10)  traceff (.*,   .clk(usoc_tclk),
                        .din ({i0_valid_wb, i1_valid_wb,
                               i0_exception_valid_wb | lsu_i0_exc_wb | (i0_trigger_hit_wb & ~trigger_hit_dmode_wb),
                               ~(i0_exception_valid_wb | lsu_i0_exc_wb | i0_trigger_hit_wb) & exc_or_int_valid_wb & ~interrupt_valid_wb,
                               exc_cause_wb[4:0],
                               interrupt_valid_wb}),
                        .dout({dec_tlu_i0_valid_wb1, dec_tlu_i1_valid_wb1,
                               dec_tlu_i0_exc_valid_wb1, dec_tlu_i1_exc_valid_wb1,
                               dec_tlu_exc_cause_wb1[4:0],
                               dec_tlu_int_valid_wb1}));

   assign dec_tlu_mtval_wb1  = mtval[31:0];


logic csr_misa;
logic csr_mvendorid;
logic csr_marchid;
logic csr_mimpid;
logic csr_mhartid;
logic csr_mstatus;
logic csr_fflags;
logic csr_frm;
logic csr_fcsr;
logic csr_mtvec;
logic csr_mip;
logic csr_mie;
logic csr_mcyclel;
logic csr_mcycleh;
logic csr_minstretl;
logic csr_minstreth;
logic csr_mscratch;
logic csr_mepc;
logic csr_mcause;
logic csr_mtval;
logic csr_mrac;
logic csr_dmst;
logic csr_mdseac;
logic csr_dcsr;
logic csr_mpmc;
logic csr_mcgc;
logic csr_mcpc;
logic csr_mfdc;
logic csr_dpc;
logic csr_mtsel;
logic csr_mtdata1;
logic csr_mtdata2;
logic csr_mhpmc3;
logic csr_mhpmc4;
logic csr_mhpmc5;
logic csr_mhpmc6;
logic csr_mhpmc3h;
logic csr_mhpmc4h;
logic csr_mhpmc5h;
logic csr_mhpmc6h;
logic csr_mhpme3;
logic csr_mhpme4;
logic csr_mhpme5;
logic csr_mhpme6;
logic csr_mgpmc;
logic csr_micect;
logic csr_miccmect;
logic csr_mdccmect;
logic csr_dicago;
logic presync;
logic postsync;

assign csr_misa = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_mvendorid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_marchid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mimpid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_mhartid = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[2]);

assign csr_fflags = (dec_csr_rdaddr_d == 12'h001);
assign csr_frm    = (dec_csr_rdaddr_d == 12'h002);
assign csr_fcsr   = (dec_csr_rdaddr_d == 12'h003);

assign csr_mstatus = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]);

assign csr_mtvec = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_mip = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[2]);

assign csr_mie = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]);

assign csr_mcyclel = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]);

assign csr_mcycleh = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]);

assign csr_minstretl = (!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_minstreth = (!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mscratch = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mepc = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mcause = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mtval = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mrac = (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]);

assign csr_dmst = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]);

assign csr_mdseac = (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]);

assign csr_dcsr = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[0]);

assign csr_mpmc = (dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]);

assign csr_mcgc = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[0]);

assign csr_mcpc = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]);

assign csr_mfdc = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[0]);

assign csr_dpc = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[0]);

assign csr_mtsel = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mtdata1 = (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[0]);

assign csr_mtdata2 = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[1]);

assign csr_mhpmc3 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc4 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc5 = (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc6 = (!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc3h = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc4h = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpmc5h = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpmc6h = (dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mhpme3 = (!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]);

assign csr_mhpme4 = (dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]);

assign csr_mhpme5 = (dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]);

assign csr_mhpme6 = (dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]);

assign csr_mgpmc = (dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]);

assign csr_micect   = 1'b0;
assign csr_miccmect = 1'b0;
assign csr_mdccmect = 1'b0;

assign csr_dicago = 1'b0;

assign presync = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]) | (
    !dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]) | (
    dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]);

assign postsync = (dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[7]
    &dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]) | (
    dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[10]&!dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&dec_csr_rdaddr_d[1]);

logic legal_csr;
logic legal_csr_base;
assign legal_csr_base = (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]) | (dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[1]
    &dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[5]&!dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[3]
    &!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]) | (
    !dec_csr_rdaddr_d[11]&dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]
    &dec_csr_rdaddr_d[1]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[2]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[0]) | (dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]
    &!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[1]) | (!dec_csr_rdaddr_d[11]
    &dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]
    &!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]
    &!dec_csr_rdaddr_d[7]&dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[2]) | (
    !dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]&!dec_csr_rdaddr_d[5]
    &!dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[3]&!dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[3]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[3]) | (!dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]
    &dec_csr_rdaddr_d[9]&dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[7]
    &!dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]) | (
    dec_csr_rdaddr_d[11]&!dec_csr_rdaddr_d[10]&dec_csr_rdaddr_d[9]
    &dec_csr_rdaddr_d[8]&!dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]);


assign legal_csr = legal_csr_base |
                   ((csr_fflags | csr_frm | csr_fcsr) & dec_tlu_fp_enabled);

assign dec_tlu_presync_d = presync & dec_csr_any_unq_d & ~dec_csr_wen_unq_d;
assign dec_tlu_postsync_d = (postsync & dec_csr_any_unq_d) | rfpc_postsync;
assign valid_csr = (legal_csr & (~(csr_dcsr | csr_dpc | csr_dmst | csr_dicago) | dbg_tlu_halted_f));

assign dec_csr_legal_d = ( dec_csr_any_unq_d &
                           valid_csr &
                           ~(dec_csr_wen_unq_d & (csr_mvendorid | csr_marchid | csr_mimpid | csr_mhartid | csr_mdseac))
                           );


  assign dec_csr_rddata_d[31:0] = csr_fflags ? {27'b0, fflags} :
                                  csr_frm    ? {29'b0, frm} :
                                  csr_fcsr   ? {24'b0, frm, fflags} :
                                  ( ({32{csr_misa}}      & 32'h40001120) |
                                  ({32{csr_mvendorid}} & 32'h00000045) |
                                  ({32{csr_marchid}}   & 32'h0000000b) |
                                  ({32{csr_mimpid}}    & 32'h6) |
                                  ({32{csr_mstatus}}   & {(&mstatus_fs), 16'b0, mstatus_fs, 2'b11, 3'b0,
                                                          mstatus[1], 3'b0, mstatus[0], 3'b0}) |
                                  ({32{csr_fflags}}    & {27'b0, fflags}) |
                                  ({32{csr_frm}}       & {29'b0, frm}) |
                                  ({32{csr_fcsr}}      & {24'b0, frm, fflags}) |
                                  ({32{csr_mtvec}}     & {mtvec[30:1], 1'b0, mtvec[0]}) |
                                  ({32{csr_mip}}       & {1'b0, mip[5:3], 16'b0, mip[2], 3'b0, mip[1], 3'b0, mip[0], 3'b0}) |
                                  ({32{csr_mie}}       & {1'b0, mie[5:3], 16'b0, mie[2], 3'b0, mie[1], 3'b0, mie[0], 3'b0}) |
                                  ({32{csr_mcyclel}}   & mcyclel[31:0]) |
                                  ({32{csr_mcycleh}}   & mcycleh_inc[31:0]) |
                                  ({32{csr_minstretl}} & minstretl_read[31:0]) |
                                  ({32{csr_minstreth}} & minstreth_read[31:0]) |
                                  ({32{csr_mscratch}}  & mscratch[31:0]) |
                                  ({32{csr_mepc}}      & {mepc[31:1], 1'b0}) |
                                  ({32{csr_mcause}}    & mcause[31:0]) |
                                  ({32{csr_mtval}}     & mtval[31:0]) |
                                  ({32{csr_mrac}}      & mrac[31:0]) |
                                  ({32{csr_mdseac}}    & mdseac[31:0]) |
                                  ({32{csr_mcgc}}      & {23'b0, mcgc[8:0]}) |
                                  ({32{csr_mfdc}}      & {13'b0, mfdc[18:0]}) |
                                  ({32{csr_dcsr}}      & {16'h4000, dcsr[15:2], 2'b11}) |
                                  ({32{csr_dpc}}       & {dpc[31:1], 1'b0}) |
                                  ({32{csr_mtsel}}     & {30'b0, mtsel[1:0]}) |
                                  ({32{csr_mtdata1}}   & {mtdata1_tsel_out[31:0]}) |
                                  ({32{csr_mtdata2}}   & {mtdata2_tsel_out[31:0]}) |
                                  ({32{csr_micect}}    & {micect[31:0]}) |
                                  ({32{csr_miccmect}}  & {miccmect[31:0]}) |
                                  ({32{csr_mdccmect}}  & {mdccmect[31:0]}) |
                                  ({32{csr_mhpmc3}}    & mhpmc3[31:0]) |
                                  ({32{csr_mhpmc4}}    & mhpmc4[31:0]) |
                                  ({32{csr_mhpmc5}}    & mhpmc5[31:0]) |
                                  ({32{csr_mhpmc6}}    & mhpmc6[31:0]) |
                                  ({32{csr_mhpmc3h}}   & mhpmc3h[31:0]) |
                                  ({32{csr_mhpmc4h}}   & mhpmc4h[31:0]) |
                                  ({32{csr_mhpmc5h}}   & mhpmc5h[31:0]) |
                                  ({32{csr_mhpmc6h}}   & mhpmc6h[31:0]) |
                                  ({32{csr_mhpme3}}    & {26'b0,mhpme3[5:0]}) |
                                  ({32{csr_mhpme4}}    & {26'b0,mhpme4[5:0]}) |
                                  ({32{csr_mhpme5}}    & {26'b0,mhpme5[5:0]}) |
                                  ({32{csr_mhpme6}}    & {26'b0,mhpme6[5:0]}) |
                                  ({32{csr_mpmc}}      & {30'b0, mpmc[1], 1'b0}) |
                                  ({32{csr_mgpmc}}     & {31'b0, mgpmc}) |
                                  ({32{dec_timer_read_d}} & dec_timer_rddata_d[31:0])
                                  );


`undef MSTATUS_MIE
`undef MISA
`undef MVENDORID
`undef MARCHID
`undef MIMPID
`undef MHARTID
`undef MSTATUS
`undef MTVEC
`undef MIP
`undef MIP_MEIP
`undef MIP_MTIP
`undef MIP_MSIP
`undef MIE
`undef MIE_MEIE
`undef MIE_MTIE
`undef MCYCLEL
`undef MCYCLEH
`undef MINSTRETL
`undef MINSTRETH
`undef MSCRATCH
`undef MEPC
`undef MCAUSE
`undef MTVAL
`undef MRAC
`undef MDSEAC
`undef MEIHAP
`undef MEIPT
`undef MEICURPL


endmodule

module dec_timer_ctl
  (
   input logic clk,
   input logic free_clk,
   input logic rst_l,
   input logic        dec_csr_wen_wb_mod,
   input logic [11:0] dec_csr_rdaddr_d,
   input logic [11:0] dec_csr_wraddr_wb,
   input logic [31:0] dec_csr_wrdata_wb,

   input logic dec_pause_state,
   input logic dec_tlu_pmu_fw_halted,
   input logic internal_dbg_halt_timers,

   output logic [31:0] dec_timer_rddata_d,
   output logic        dec_timer_read_d,
   output logic        dec_timer_t0_pulse,
   output logic        dec_timer_t1_pulse,

   input  logic        scan_mode
   );
   `define MITCTL_ENABLE 0
   `define MITCTL_ENABLE_HALTED 1
   `define MITCTL_ENABLE_PAUSED 2

   logic [31:0] mitcnt0_ns, mitcnt0, mitcnt1_ns, mitcnt1, mitb0, mitb1, mitb0_b, mitb1_b, mitcnt0_inc, mitcnt1_inc;
   logic [2:0] mitctl0_ns, mitctl0, mitctl1_ns, mitctl1;
   logic wr_mitcnt0_wb, wr_mitcnt1_wb, wr_mitb0_wb, wr_mitb1_wb, wr_mitctl0_wb, wr_mitctl1_wb;
   logic mitcnt0_inc_ok, mitcnt1_inc_ok, mitcnt0_cout_nc, mitcnt1_cout_nc;

 logic mit0_match_ns;
 logic mit1_match_ns;
 logic mitctl0_0_b_ns;
 logic mitctl0_0_b;
 logic mitctl1_0_b_ns;
 logic mitctl1_0_b;

   assign mit0_match_ns = (mitcnt0[31:0] >= mitb0[31:0]);
   assign mit1_match_ns = (mitcnt1[31:0] >= mitb1[31:0]);

   assign dec_timer_t0_pulse = mit0_match_ns;
   assign dec_timer_t1_pulse = mit1_match_ns;


   `define MITCNT0 12'h7d2

   assign wr_mitcnt0_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITCNT0);

   assign mitcnt0_inc_ok = mitctl0[`MITCTL_ENABLE] & (~dec_pause_state | mitctl0[`MITCTL_ENABLE_PAUSED]) & (~dec_tlu_pmu_fw_halted | mitctl0[`MITCTL_ENABLE_HALTED]) & ~internal_dbg_halt_timers;

   assign {mitcnt0_cout_nc, mitcnt0_inc[31:0]} = mitcnt0[31:0] + {31'b0, 1'b1};
   assign mitcnt0_ns[31:0] = mit0_match_ns ? 'b0 : wr_mitcnt0_wb ? dec_csr_wrdata_wb[31:0] : mitcnt0_inc[31:0];

   rvdffe #(32) mitcnt0_ff      (.*, .en(wr_mitcnt0_wb | mitcnt0_inc_ok | mit0_match_ns), .din(mitcnt0_ns[31:0]), .dout(mitcnt0[31:0]));


   `define MITCNT1 12'h7d5

   assign wr_mitcnt1_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITCNT1);

   assign mitcnt1_inc_ok = mitctl1[`MITCTL_ENABLE] & (~dec_pause_state | mitctl1[`MITCTL_ENABLE_PAUSED]) & (~dec_tlu_pmu_fw_halted | mitctl1[`MITCTL_ENABLE_HALTED]) & ~internal_dbg_halt_timers;

   assign {mitcnt1_cout_nc, mitcnt1_inc[31:0]} = mitcnt1[31:0] + {31'b0, 1'b1};
   assign mitcnt1_ns[31:0] = mit1_match_ns ? 'b0 :  wr_mitcnt1_wb ? dec_csr_wrdata_wb[31:0] : mitcnt1_inc[31:0];

   rvdffe #(32) mitcnt1_ff      (.*, .en(wr_mitcnt1_wb | mitcnt1_inc_ok | mit1_match_ns), .din(mitcnt1_ns[31:0]), .dout(mitcnt1[31:0]));


   `define MITB0 12'h7d3

   assign wr_mitb0_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITB0);

   rvdffe #(32) mitb0_ff      (.*, .en(wr_mitb0_wb), .din(~dec_csr_wrdata_wb[31:0]), .dout(mitb0_b[31:0]));
   assign mitb0[31:0] = ~mitb0_b[31:0];


   `define MITB1 12'h7d6

   assign wr_mitb1_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITB1);

   rvdffe #(32) mitb1_ff      (.*, .en(wr_mitb1_wb), .din(~dec_csr_wrdata_wb[31:0]), .dout(mitb1_b[31:0]));
   assign mitb1[31:0] = ~mitb1_b[31:0];


   `define MITCTL0 12'h7d4

   assign wr_mitctl0_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITCTL0);
   assign mitctl0_ns[2:0] = wr_mitctl0_wb ? {dec_csr_wrdata_wb[2:0]} : {mitctl0[2:0]};

   assign mitctl0_0_b_ns = ~mitctl0_ns[0];
   rvdff #(3) mitctl0_ff      (.*, .clk(free_clk), .din({mitctl0_ns[2:1], mitctl0_0_b_ns}), .dout({mitctl0[2:1], mitctl0_0_b}));
   assign mitctl0[0] = ~mitctl0_0_b;


   `define MITCTL1 12'h7d7

   assign wr_mitctl1_wb = dec_csr_wen_wb_mod & (dec_csr_wraddr_wb[11:0] == `MITCTL1);
   assign mitctl1_ns[2:0] = wr_mitctl1_wb ? {dec_csr_wrdata_wb[2:0]} : {mitctl1[2:0]};

   assign mitctl1_0_b_ns = ~mitctl1_ns[0];
   rvdff #(3) mitctl1_ff      (.*, .clk(free_clk), .din({mitctl1_ns[2:1], mitctl1_0_b_ns}), .dout({mitctl1[2:1], mitctl1_0_b}));
   assign mitctl1[0] = ~mitctl1_0_b;


logic csr_mitctl0;
logic csr_mitctl1;
logic csr_mitb0;
logic csr_mitb1;
logic csr_mitcnt0;
logic csr_mitcnt1;
assign csr_mitctl0 = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[4]
    &dec_csr_rdaddr_d[2]&!dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mitctl1 = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);

assign csr_mitb0 = (dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]&dec_csr_rdaddr_d[4]
    &!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[0]);

assign csr_mitb1 = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[4]&dec_csr_rdaddr_d[2]
    &dec_csr_rdaddr_d[1]&!dec_csr_rdaddr_d[0]);

assign csr_mitcnt0 = (dec_csr_rdaddr_d[6]&!dec_csr_rdaddr_d[5]
    &dec_csr_rdaddr_d[4]&!dec_csr_rdaddr_d[2]&dec_csr_rdaddr_d[1]
    &!dec_csr_rdaddr_d[0]);

assign csr_mitcnt1 = (dec_csr_rdaddr_d[6]&dec_csr_rdaddr_d[2]
    &!dec_csr_rdaddr_d[1]&dec_csr_rdaddr_d[0]);


   assign dec_timer_read_d = csr_mitcnt1 | csr_mitcnt0 | csr_mitb1 | csr_mitb0 | csr_mitctl0 | csr_mitctl1;
   assign dec_timer_rddata_d[31:0] = ( ({32{csr_mitcnt0}}      & mitcnt0[31:0]) |
                                       ({32{csr_mitcnt1}}      & mitcnt1[31:0]) |
                                       ({32{csr_mitb0}}        & mitb0[31:0]) |
                                       ({32{csr_mitb1}}        & mitb1[31:0]) |
                                       ({32{csr_mitctl0}}      & {29'b0, mitctl0[2:0]}) |
                                       ({32{csr_mitctl1}}      & {29'b0, mitctl1[2:0]})
                                       );


endmodule
