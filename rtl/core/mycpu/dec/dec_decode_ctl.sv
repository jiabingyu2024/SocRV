

module dec_decode_ctl
   import mycpu_types::*;
(
   input logic [15:0] dec_i0_cinst_d,
   input logic [15:0] dec_i1_cinst_d,

   output logic [31:0] dec_i0_inst_wb1,
   output logic [31:0] dec_i1_inst_wb1,

   output logic [31:1] dec_i0_pc_wb1,
   output logic [31:1] dec_i1_pc_wb1,


   input logic                                lsu_nonblock_load_valid_dc3,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_dc3,
   input logic                                lsu_nonblock_load_inv_dc5,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_dc5,
   input logic                                lsu_nonblock_load_data_valid,
   input logic                                lsu_nonblock_load_data_error,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,

   input logic [3:0] dec_i0_trigger_match_d,
   input logic [3:0] dec_i1_trigger_match_d,

   input logic dec_tlu_wr_pause_wb,
   input logic dec_tlu_pipelining_disable,
   input logic dec_tlu_dual_issue_disable,

   input logic dec_tlu_sec_alu_disable,

   input logic [3:0]  lsu_trigger_match_dc3,

   input logic lsu_pmu_misaligned_dc3,
   input logic dec_tlu_debug_stall,
   input logic dec_tlu_flush_leak_one_wb,

   input logic dec_debug_fence_d,

   input logic [1:0] dbg_cmd_wrdata,

   input logic dec_i0_icaf_d,
   input logic dec_i1_icaf_d,
   input logic dec_i0_icaf_second_d,
   input logic dec_i0_perr_d,
   input logic dec_i1_perr_d,
   input logic dec_i0_sbecc_d,
   input logic dec_i1_sbecc_d,
   input logic dec_i0_dbecc_d,
   input logic dec_i1_dbecc_d,

   input br_pkt_t dec_i0_brp,
   input br_pkt_t dec_i1_brp,

   input logic [15:0] ifu_illegal_inst,

   input logic [31:1] dec_i0_pc_d,

   input logic lsu_freeze_dc3,
   input logic lsu_halt_idle_any,

   input logic lsu_load_stall_any,
   input logic lsu_store_stall_any,

   input logic exu_div_finish,
   input logic exu_div_stall,
   input logic [31:0] exu_div_result,

   input logic dec_tlu_i0_kill_writeb_wb,
   input logic dec_tlu_i1_kill_writeb_wb,

   input logic dec_tlu_flush_lower_wb,
   input logic dec_tlu_flush_pause_wb,
   input logic dec_tlu_presync_d,
   input logic dec_tlu_postsync_d,

   input logic [31:0] exu_mul_result_e3,

   input logic dec_i0_pc4_d,
   input logic dec_i1_pc4_d,

   input logic [31:0] dec_csr_rddata_d,
   input logic dec_csr_legal_d,

   input logic [31:0] exu_csr_rs1_e1,

   input logic [31:0] lsu_result_dc3,
   input logic [31:0] lsu_result_corr_dc4,

   input logic exu_i0_flush_final,
   input logic exu_i1_flush_final,

   input logic [31:1] exu_i0_pc_e1,
   input logic [31:1] exu_i1_pc_e1,

   input logic [31:0] dec_i0_instr_d,
   input logic [31:0] dec_i1_instr_d,
   input logic [31:0] gpr_i0_rs1_d,
   input logic [2:0]  dec_tlu_frm,
   input logic        dec_tlu_fp_enabled,

   input logic  dec_ib0_valid_d,
   input logic  dec_ib1_valid_d,

   input logic [31:0] exu_i0_result_e1,
   input logic [31:0] exu_i1_result_e1,

   input logic [31:0] exu_i0_result_e4,
   input logic [31:0] exu_i1_result_e4,

   input logic  clk,
   input logic  active_clk,
   input logic  free_clk,

   input logic  clk_override,
   input logic  rst_l,


   output logic         dec_i0_rs1_en_d,
   output logic         dec_i0_rs2_en_d,

   output logic [4:0] dec_i0_rs1_d,
   output logic [4:0] dec_i0_rs2_d,


   output logic [31:0] dec_i0_immed_d,

   output logic          dec_i1_rs1_en_d,
   output logic          dec_i1_rs2_en_d,

   output logic [4:0]  dec_i1_rs1_d,
   output logic [4:0]  dec_i1_rs2_d,


   output logic [31:0] dec_i1_immed_d,

   output logic [12:1] dec_i0_br_immed_d,
   output logic [12:1] dec_i1_br_immed_d,

   output alu_pkt_t i0_ap,
   output alu_pkt_t i1_ap,

   output logic          dec_i0_decode_d,
   output logic          dec_i1_decode_d,

   output logic          dec_ib0_valid_eff_d,
   output logic          dec_ib1_valid_eff_d,

   output logic          dec_i0_alu_decode_d,
   output logic          dec_i1_alu_decode_d,


   output logic [31:0] i0_rs1_bypass_data_d,
   output logic [31:0] i0_rs2_bypass_data_d,
   output logic [31:0] i1_rs1_bypass_data_d,
   output logic [31:0] i1_rs2_bypass_data_d,


   output logic [4:0]  dec_i0_waddr_wb,
   output logic          dec_i0_wen_wb,
   output logic [31:0] dec_i0_wdata_wb,

   output logic [4:0]  dec_i1_waddr_wb,
   output logic          dec_i1_wen_wb,
   output logic [31:0] dec_i1_wdata_wb,

   output logic          dec_i0_select_pc_d,
   output logic          dec_i1_select_pc_d,

   output logic dec_i0_rs1_bypass_en_d,
   output logic dec_i0_rs2_bypass_en_d,
   output logic dec_i1_rs1_bypass_en_d,
   output logic dec_i1_rs2_bypass_en_d,

   output lsu_pkt_t    lsu_p,

   output mul_pkt_t    mul_p,

   output div_pkt_t    div_p,

   output logic [11:0] dec_lsu_offset_d,
   output logic        dec_i0_lsu_d,
   output logic        dec_i1_lsu_d,
   output logic        dec_i0_mul_d,
   output logic        dec_i1_mul_d,
   output logic        dec_i0_div_d,
   output logic        dec_i1_div_d,


   output logic        flush_final_e3,
   output logic        i0_flush_final_e3,

   output logic        dec_csr_ren_d,
   output logic        dec_csr_wen_unq_d,
   output logic        dec_csr_any_unq_d,
   output logic        dec_csr_wen_wb,
   output logic [11:0] dec_csr_rdaddr_d,
   output logic [11:0] dec_csr_wraddr_wb,
   output logic [31:0] dec_csr_wrdata_wb,
   output logic        dec_csr_stall_int_ff,

   output              dec_tlu_i0_valid_e4,
   output              dec_tlu_i1_valid_e4,

   output              trap_pkt_t dec_tlu_packet_e4,

   output logic [31:1] dec_tlu_i0_pc_e4,
   output logic [31:1] dec_tlu_i1_pc_e4,

   output logic [31:0] dec_illegal_inst,
   output logic        dec_i1_valid_e1,
   output logic        dec_div_decode_e4,
   output logic [31:1] pred_correct_npc_e2,
   output logic        dec_i0_rs1_bypass_en_e3,
   output logic        dec_i0_rs2_bypass_en_e3,
   output logic        dec_i1_rs1_bypass_en_e3,
   output logic        dec_i1_rs2_bypass_en_e3,
   output logic [31:0] i0_rs1_bypass_data_e3,
   output logic [31:0] i0_rs2_bypass_data_e3,
   output logic [31:0] i1_rs1_bypass_data_e3,
   output logic [31:0] i1_rs2_bypass_data_e3,
   output logic        dec_i0_sec_decode_e3,
   output logic        dec_i1_sec_decode_e3,
   output logic [31:1] dec_i0_pc_e3,
   output logic [31:1] dec_i1_pc_e3,

   output logic        dec_i0_rs1_bypass_en_e2,
   output logic        dec_i0_rs2_bypass_en_e2,
   output logic        dec_i1_rs1_bypass_en_e2,
   output logic        dec_i1_rs2_bypass_en_e2,
   output logic [31:0] i0_rs1_bypass_data_e2,
   output logic [31:0] i0_rs2_bypass_data_e2,
   output logic [31:0] i1_rs1_bypass_data_e2,
   output logic [31:0] i1_rs2_bypass_data_e2,

   output predict_pkt_t  i0_predict_p_d,
   output predict_pkt_t  i1_predict_p_d,

   output logic          dec_i0_lsu_decode_d,

   output logic [31:0] i0_result_e4_eff,
   output logic [31:0] i1_result_e4_eff,
   output logic [31:0] i0_result_e2,

   output logic [4:2] dec_i0_data_en,
   output logic [4:1] dec_i0_ctl_en,
   output logic [4:2] dec_i1_data_en,
   output logic [4:1] dec_i1_ctl_en,

   output logic [1:0] dec_pmu_instr_decoded,
   output logic       dec_pmu_decode_stall,
   output logic       dec_pmu_presync_stall,
   output logic       dec_pmu_postsync_stall,

   output logic       dec_nonblock_load_wen,
   output logic [4:0] dec_nonblock_load_waddr,
   output logic       dec_nonblock_load_freeze_dc2,
   output logic       dec_pause_state,
   output logic       dec_pause_state_cg,

   output logic       dec_i0_load_e4,

   output logic       dec_i0_fstore_d,
   output logic [31:0] dec_fpr_rs2_d,
   output logic       dec_fpu_fflags_valid,
   output logic [4:0] dec_fpu_fflags,
   output logic       dec_fpu_dirty,

   input  logic        scan_mode
   );


   dec_pkt_t i0_dp_raw, i0_dp;
   dec_pkt_t i1_dp_raw, i1_dp;

   logic i0_fp_op, i0_fpload, i0_fpstore, i0_fp_any;
   logic i1_fp_any;
   logic i0_cmx, i1_cmx;
   logic i0_cmx_mul, i1_cmx_mul;
   logic i0_cmx_isdigit, i1_cmx_isdigit;
   logic [1:0] i0_cmx_op, i1_cmx_op;
   logic i0_fp_encoding_legal;
   logic i0_rm_legal;
   logic i0_fp_writes_gpr;
   logic i0_fp_reads_gpr;
   logic fpr_hazard_stall;
   logic i0_fpu_decode_d;
   logic fpu_req_ready, fpu_resp_valid, fpu_busy, fpu_stall, fpu_stall_ff;
   logic [31:0] fpu_result, fpu_result_hold;
   logic [4:0] fpu_flags, fpu_rd, fpu_rd_hold;
   logic fpu_writes_gpr, fpu_writes_fpr;
   logic fpu_writes_fpr_hold;
   logic fpu_wen_wb;
   logic [31:0] fpr_rs1_d, fpr_rs2_d, fpr_rs3_d;
   logic [31:0] fpu_int_rs1_d;
   logic fpr_wen;
   logic [4:0] fpr_waddr;
   logic [31:0] fpr_wdata;
   logic fpload_wen_wb;
   logic [4:0] fpload_waddr_wb;
   logic [31:1] fpu_pc;
   logic [31:0] fpu_inst;
   logic [3:0] fpu_trigger;
   logic fload_e1, fload_e2, fload_e3, fload_e4, fload_wb;
   logic [4:0] fload_rd_e1, fload_rd_e2, fload_rd_e3, fload_rd_e4, fload_rd_wb;


   logic [31:0]        i0, i1;
   logic               i0_valid_d, i1_valid_d;

   logic [31:0]        i0_result_e1, i1_result_e1;
   logic [31:0]                      i1_result_e2;
   logic [31:0]        i0_result_e3, i1_result_e3;
   logic [31:0]        i0_result_e4, i1_result_e4;
   logic [31:0]        i0_result_wb, i1_result_wb;

   logic [31:1]        i0_pc_e1, i1_pc_e1;
   logic [31:1]        i0_pc_e2, i1_pc_e2;
   logic [31:1]        i0_pc_e3, i1_pc_e3;
   logic [31:1]        i0_pc_e4, i1_pc_e4;

   logic [9:0]         i0_rs1bypass, i0_rs2bypass;
   logic [9:0]         i1_rs1bypass, i1_rs2bypass;

   logic               i0_jalimm20, i1_jalimm20;
   logic               i0_uiimm20, i1_uiimm20;


   logic               lsu_decode_d;
   logic [31:0]        i0_immed_d;
   logic               i0_presync;
   logic               i0_postsync;

   logic               postsync_stall;
   logic               ps_stall;

   logic               prior_inflight, prior_inflight_e1e4, prior_inflight_wb;

   logic               csr_clr_d, csr_set_d, csr_write_d;


   logic        csr_clr_e1,csr_set_e1,csr_write_e1,csr_imm_e1;
   logic [31:0] csr_mask_e1;
   logic [31:0] write_csr_data_e1;
   logic [31:0] write_csr_data_in;
   logic [31:0] write_csr_data;
   logic               csr_data_wen;

   logic [4:0]         csrimm_e1;

   logic [31:0]        csr_rddata_e1;

   logic               flush_lower_wb;

   logic               i1_load_block_d;
   logic               i1_mul_block_d;
   logic               i1_load2_block_d;
   logic               i1_mul2_block_d;
   logic               mul_decode_d;
   logic               div_decode_d;
   logic [31:1]        div_pc;
   logic               div_stall, div_stall_ff;
   logic [3:0]         div_trigger;

   logic               i0_legal;
   logic               shift_illegal;
   logic               illegal_inst_en;
   logic [31:0]        illegal_inst;
   logic               illegal_lockout_in, illegal_lockout;
   logic               i0_legal_decode_d;

   logic               i1_flush_final_e3;

   logic [31:0]        i0_result_e3_final, i1_result_e3_final;
   logic [31:0]        i0_result_wb_raw,   i1_result_wb_raw;
   logic [12:1] last_br_immed_d;
   logic        i1_depend_i0_d;
   logic        i0_rs1_depend_i0_e1, i0_rs1_depend_i0_e2, i0_rs1_depend_i0_e3, i0_rs1_depend_i0_e4, i0_rs1_depend_i0_wb;
   logic        i0_rs1_depend_i1_e1, i0_rs1_depend_i1_e2, i0_rs1_depend_i1_e3, i0_rs1_depend_i1_e4, i0_rs1_depend_i1_wb;
   logic        i0_rs2_depend_i0_e1, i0_rs2_depend_i0_e2, i0_rs2_depend_i0_e3, i0_rs2_depend_i0_e4, i0_rs2_depend_i0_wb;
   logic        i0_rs2_depend_i1_e1, i0_rs2_depend_i1_e2, i0_rs2_depend_i1_e3, i0_rs2_depend_i1_e4, i0_rs2_depend_i1_wb;
   logic        i1_rs1_depend_i0_e1, i1_rs1_depend_i0_e2, i1_rs1_depend_i0_e3, i1_rs1_depend_i0_e4, i1_rs1_depend_i0_wb;
   logic        i1_rs1_depend_i1_e1, i1_rs1_depend_i1_e2, i1_rs1_depend_i1_e3, i1_rs1_depend_i1_e4, i1_rs1_depend_i1_wb;
   logic        i1_rs2_depend_i0_e1, i1_rs2_depend_i0_e2, i1_rs2_depend_i0_e3, i1_rs2_depend_i0_e4, i1_rs2_depend_i0_wb;
   logic        i1_rs2_depend_i1_e1, i1_rs2_depend_i1_e2, i1_rs2_depend_i1_e3, i1_rs2_depend_i1_e4, i1_rs2_depend_i1_wb;
   logic        i1_rs1_depend_i0_d, i1_rs2_depend_i0_d;

   logic        i0_secondary_d, i1_secondary_d;
   logic        i0_secondary_block_d, i1_secondary_block_d;
   logic        non_block_case_d;
   logic        i0_div_decode_d;
   logic [31:0] i0_result_e4_final, i1_result_e4_final;
   logic        i0_load_block_d;
   logic        i0_mul_block_d;
   logic [3:0]  i0_rs1_depth_d, i0_rs2_depth_d;
   logic [3:0]  i1_rs1_depth_d, i1_rs2_depth_d;

   logic        i0_rs1_match_e1_e2, i0_rs1_match_e1_e3;
   logic        i0_rs2_match_e1_e2, i0_rs2_match_e1_e3;
   logic        i1_rs1_match_e1_e2, i1_rs1_match_e1_e3;
   logic        i1_rs2_match_e1_e2, i1_rs2_match_e1_e3;

   logic        i0_load_stall_d,  i1_load_stall_d;
   logic        i0_store_stall_d, i1_store_stall_d;

   logic        i0_predict_nt, i0_predict_t;
   logic        i1_predict_nt, i1_predict_t;

   logic        i0_notbr_error, i0_br_toffset_error;
   logic        i1_notbr_error, i1_br_toffset_error;
   logic        i0_ret_error,   i1_ret_error;
   logic        i0_br_error, i1_br_error;
   logic        i0_br_error_all, i1_br_error_all;
   logic [11:0] i0_br_offset, i1_br_offset;

   logic        freeze;

   logic [20:1] i0_pcall_imm, i1_pcall_imm;
   logic        i0_pcall_12b_offset, i1_pcall_12b_offset;
   logic        i0_pcall_raw,   i1_pcall_raw;
   logic        i0_pcall_case,  i1_pcall_case;
   logic        i0_pcall,  i1_pcall;

   logic        i0_pja_raw,   i1_pja_raw;
   logic        i0_pja_case,  i1_pja_case;
   logic        i0_pja,  i1_pja;

   logic        i0_pret_case, i1_pret_case;
   logic        i0_pret_raw, i0_pret;
   logic        i1_pret_raw, i1_pret;

   logic        i0_jal, i1_jal;


   logic        i0_predict_br, i1_predict_br;

   logic        freeze_prior1, freeze_prior2;

   logic [31:0] i0_result_e4_freeze, i1_result_e4_freeze;
   logic [31:0] i0_result_wb_freeze, i1_result_wb_freeze;
   logic [31:0] i1_result_wb_eff, i0_result_wb_eff;
   logic [2:0]  i1rs1_intra, i1rs2_intra;
   logic        i1_rs1_intra_bypass, i1_rs2_intra_bypass;
   logic        store_data_bypass_c1, store_data_bypass_c2;
   logic [1:0]  store_data_bypass_e4_c1, store_data_bypass_e4_c2, store_data_bypass_e4_c3;
   logic        store_data_bypass_i0_e2_c2;

   class_pkt_t i0_rs1_class_d, i0_rs2_class_d;
   class_pkt_t i1_rs1_class_d, i1_rs2_class_d;

   class_pkt_t i0_dc, i0_e1c, i0_e2c, i0_e3c, i0_e4c, i0_wbc;
   class_pkt_t i1_dc, i1_e1c, i1_e2c, i1_e3c, i1_e4c, i1_wbc;


   logic i0_rs1_match_e1, i0_rs1_match_e2, i0_rs1_match_e3;
   logic i1_rs1_match_e1, i1_rs1_match_e2, i1_rs1_match_e3;
   logic i0_rs2_match_e1, i0_rs2_match_e2, i0_rs2_match_e3;
   logic i1_rs2_match_e1, i1_rs2_match_e2, i1_rs2_match_e3;

   logic       i0_secondary_stall_d;

   logic       i0_ap_pc2, i0_ap_pc4;
   logic       i1_ap_pc2, i1_ap_pc4;

   logic        div_wen_wb;
   logic        i0_rd_en_d;
   logic        i1_rd_en_d;
   logic [4:0]  i1_rd_d;
   logic [4:0]  i0_rd_d;

   logic        load_ldst_bypass_c1;
   logic        load_mul_rs1_bypass_e1;
   logic        load_mul_rs2_bypass_e1;

   logic        leak1_i0_stall_in, leak1_i0_stall;
   logic        leak1_i1_stall_in, leak1_i1_stall;
   logic        leak1_mode;

   logic        i0_csr_write_only_d;

   logic        prior_inflight_e1e3, prior_inflight_eff;
   logic        any_csr_d;

   logic        prior_csr_write;

   logic [5:0] i0_pipe_en;
   logic       i0_e1_ctl_en, i0_e2_ctl_en, i0_e3_ctl_en, i0_e4_ctl_en, i0_wb_ctl_en;
   logic       i0_e1_data_en, i0_e2_data_en, i0_e3_data_en, i0_e4_data_en, i0_wb_data_en, i0_wb1_data_en;

   logic [5:0] i1_pipe_en;
   logic       i1_e1_ctl_en, i1_e2_ctl_en, i1_e3_ctl_en, i1_e4_ctl_en, i1_wb_ctl_en;
   logic       i1_e1_data_en, i1_e2_data_en, i1_e3_data_en, i1_e4_data_en, i1_wb_data_en, i1_wb1_data_en;

   logic debug_fence_i;
   logic debug_fence;

   logic i0_csr_write;
   logic presync_stall;

   logic i0_instr_error;
   logic i0_icaf_d;
   logic i1_icaf_d;

   logic i0_not_alu_eff, i1_not_alu_eff;

   logic disable_secondary;

   logic clear_pause;
   logic pause_state_in, pause_state;
   logic pause_stall;

   logic [31:1] i1_pc_wb;

   logic        i0_brp_valid;
   logic        nonblock_load_cancel;
   logic        lsu_idle;
   logic        csr_read_e1;
   logic        i0_block_d;
   logic        i1_block_d;
   logic        ps_stall_in;

   logic        freeze_after_unfreeze1;
   logic        freeze_after_unfreeze2;
   logic        unfreeze_cycle1;
   logic        unfreeze_cycle2;

   logic        tlu_wr_pause_wb1, tlu_wr_pause_wb2;

   localparam NBLOAD_SIZE     = `RV_LSU_NUM_NBLOAD;
   localparam NBLOAD_SIZE_MSB = `RV_LSU_NUM_NBLOAD-1;
   localparam NBLOAD_TAG_MSB  = `RV_LSU_NUM_NBLOAD_WIDTH-1;


   logic                     cam_write, cam_inv_reset, cam_data_reset;
   logic [NBLOAD_TAG_MSB:0]  cam_write_tag, cam_inv_reset_tag, cam_data_reset_tag;
   logic [NBLOAD_SIZE_MSB:0] cam_wen;

   logic [NBLOAD_TAG_MSB:0]  load_data_tag;
   logic [NBLOAD_SIZE_MSB:0] nonblock_load_write;

   load_cam_pkt_t [NBLOAD_SIZE_MSB:0] cam;
   load_cam_pkt_t [NBLOAD_SIZE_MSB:0] cam_in;

   logic [4:0] nonblock_load_rd;
   logic i1_nonblock_load_stall,     i0_nonblock_load_stall;
   logic i1_nonblock_boundary_stall, i0_nonblock_boundary_stall;
   logic i0_depend_load_e1_d, i0_depend_load_e2_d;
   logic i1_depend_load_e1_d, i1_depend_load_e2_d;
   logic    depend_load_e1_d,  depend_load_e2_d,  depend_load_same_cycle_d;
   logic    depend_load_e2_e1,                    depend_load_same_cycle_e1;
   logic                                          depend_load_same_cycle_e2;

   logic nonblock_load_valid_dc4, nonblock_load_valid_wb;
   logic i0_load_kill_wen, i1_load_kill_wen;

   logic found;

   logic cam_reset_same_dest_wb;
   logic [NBLOAD_SIZE_MSB:0] cam_inv_reset_val, cam_data_reset_val;
   logic       i1_wen_wb, i0_wen_wb;

   inst_t i0_itype, i1_itype;

   logic csr_read, csr_write;
   logic i0_br_unpred, i1_br_unpred;

   logic debug_fence_raw;

   logic freeze_before;
   logic freeze_e3, freeze_e4;
   logic [3:0] e4t_i0trigger;
   logic [3:0] e4t_i1trigger;
   logic       e4d_i0load;

   logic [4:0] div_waddr_wb;
   logic [12:1] last_br_immed_e1, last_br_immed_e2;
   logic [31:0]        i0_inst_d, i1_inst_d;
   logic [31:0]        i0_inst_e1, i1_inst_e1;
   logic [31:0]        i0_inst_e2, i1_inst_e2;
   logic [31:0]        i0_inst_e3, i1_inst_e3;
   logic [31:0]        i0_inst_e4, i1_inst_e4;
   logic [31:0]        i0_inst_wb, i1_inst_wb;
   logic [31:0]        i0_inst_wb1,i1_inst_wb1;

   logic [31:0]        div_inst;
   logic [31:1] i0_pc_wb, i0_pc_wb1;
   logic [31:1]           i1_pc_wb1;
   logic [31:1] last_pc_e2;

   reg_pkt_t i0r, i1r;

   trap_pkt_t   dt, e1t_in, e1t, e2t_in, e2t, e3t_in, e3t, e4t;

   class_pkt_t i0_e4c_in, i1_e4c_in;

   dest_pkt_t  dd, e1d, e2d, e3d, e4d, wbd;
   dest_pkt_t e1d_in, e2d_in, e3d_in, e4d_in;


   assign freeze = lsu_freeze_dc3;

   assign disable_secondary        = dec_tlu_sec_alu_disable;


   assign i0_brp_valid = dec_i0_brp.valid & ~leak1_mode;

   assign      i0_predict_p_d.misp    =  '0;
   assign      i0_predict_p_d.ataken  =  '0;
   assign      i0_predict_p_d.boffset =  '0;

   assign      i0_predict_p_d.pcall  =  i0_pcall;
   assign      i0_predict_p_d.pja    =  i0_pja;
   assign      i0_predict_p_d.pret   =  i0_pret;
   assign      i0_predict_p_d.prett[31:1] = dec_i0_brp.prett[31:1];
   assign      i0_predict_p_d.pc4 = dec_i0_pc4_d;
   assign      i0_predict_p_d.hist[1:0] = dec_i0_brp.hist[1:0];
   assign      i0_predict_p_d.valid = i0_brp_valid & i0_legal_decode_d;
   assign      i0_notbr_error = i0_brp_valid & ~(i0_dp_raw.condbr | i0_pcall_raw | i0_pja_raw | i0_pret_raw);


   assign      i0_br_toffset_error = i0_brp_valid & dec_i0_brp.hist[1] & (dec_i0_brp.toffset[11:0] != i0_br_offset[11:0]) & !i0_pret_raw;
   assign      i0_ret_error = i0_brp_valid & dec_i0_brp.ret & ~i0_pret_raw;
   assign      i0_br_error =  dec_i0_brp.br_error | i0_notbr_error | i0_br_toffset_error | i0_ret_error;
   assign      i0_predict_p_d.br_error = i0_br_error & i0_legal_decode_d & ~leak1_mode;
   assign      i0_predict_p_d.br_start_error = dec_i0_brp.br_start_error & i0_legal_decode_d & ~leak1_mode;
   assign      i0_predict_p_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_i0_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign      i0_predict_p_d.bank[1:0] = dec_i0_brp.bank[1:0];
   assign      i0_predict_p_d.btag[`RV_BTB_BTAG_SIZE-1:0] = dec_i0_brp.btag[`RV_BTB_BTAG_SIZE-1:0];
   assign      i0_br_error_all = (i0_br_error | dec_i0_brp.br_start_error) & ~leak1_mode;
   assign      i0_predict_p_d.toffset[11:0] = i0_br_offset[11:0];
   assign      i0_predict_p_d.fghr[`RV_BHT_GHR_RANGE] = dec_i0_brp.fghr[`RV_BHT_GHR_RANGE];
   assign      i0_predict_p_d.way = dec_i0_brp.way;


   assign      i1_predict_p_d.misp    =  '0;
   assign      i1_predict_p_d.ataken  =  '0;
   assign      i1_predict_p_d.boffset =  '0;

   assign      i1_predict_p_d.pcall  =  i1_pcall;
   assign      i1_predict_p_d.pja    =  i1_pja;
   assign      i1_predict_p_d.pret   =  i1_pret;
   assign      i1_predict_p_d.prett[31:1] = dec_i1_brp.prett[31:1];
   assign      i1_predict_p_d.pc4 = dec_i1_pc4_d;
   assign      i1_predict_p_d.hist[1:0] = dec_i1_brp.hist[1:0];
   assign      i1_predict_p_d.valid = dec_i1_brp.valid & dec_i1_decode_d;
   assign      i1_notbr_error = dec_i1_brp.valid & ~(i1_dp_raw.condbr | i1_pcall_raw | i1_pja_raw | i1_pret_raw);


   assign      i1_br_toffset_error = dec_i1_brp.valid & dec_i1_brp.hist[1] & (dec_i1_brp.toffset[11:0] != i1_br_offset[11:0]) & !i1_pret_raw;
   assign      i1_ret_error = dec_i1_brp.valid & dec_i1_brp.ret & ~i1_pret_raw;
   assign      i1_br_error = dec_i1_brp.br_error | i1_notbr_error | i1_br_toffset_error | i1_ret_error;
   assign      i1_predict_p_d.br_error = i1_br_error & dec_i1_decode_d;
   assign      i1_predict_p_d.br_start_error = dec_i1_brp.br_start_error & dec_i1_decode_d;
   assign      i1_predict_p_d.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_i1_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign      i1_predict_p_d.bank[1:0] = dec_i1_brp.bank[1:0];
   assign      i1_predict_p_d.btag[`RV_BTB_BTAG_SIZE-1:0] = dec_i1_brp.btag[`RV_BTB_BTAG_SIZE-1:0];
   assign      i1_br_error_all = (i1_br_error | dec_i1_brp.br_start_error);
   assign      i1_predict_p_d.toffset[11:0] = i1_br_offset[11:0];
   assign      i1_predict_p_d.fghr[`RV_BHT_GHR_RANGE] = dec_i1_brp.fghr[`RV_BHT_GHR_RANGE];
   assign      i1_predict_p_d.way = dec_i1_brp.way;


   assign i0_icaf_d = dec_i0_icaf_d | dec_i0_dbecc_d;
   assign i1_icaf_d = dec_i1_icaf_d | dec_i1_dbecc_d;

   assign i0_instr_error = i0_icaf_d | dec_i0_perr_d | dec_i0_sbecc_d;

   assign i0_fp_op = (i0[6:0] == 7'b1010011) ||
                     (i0[6:0] == 7'b1000011) ||
                     (i0[6:0] == 7'b1000111) ||
                     (i0[6:0] == 7'b1001011) ||
                     (i0[6:0] == 7'b1001111);
   assign i0_fpload  = (i0[6:0] == 7'b0000111) && (i0[14:12] == 3'b010);
   assign i0_fpstore = (i0[6:0] == 7'b0100111) && (i0[14:12] == 3'b010);
   assign i0_fp_any = i0_fp_op || i0_fpload || i0_fpstore;
   assign i1_fp_any = (i1[6:0] == 7'b1010011) ||
                      (i1[6:0] == 7'b1000011) ||
                      (i1[6:0] == 7'b1000111) ||
                      (i1[6:0] == 7'b1001011) ||
                      (i1[6:0] == 7'b1001111) ||
                      ((i1[6:0] == 7'b0000111) && (i1[14:12] == 3'b010)) ||
                      ((i1[6:0] == 7'b0100111) && (i1[14:12] == 3'b010));

   assign i0_cmx = (i0[6:0] == 7'b0001011) && (i0[31:25] == 7'b0000000) &&
                   (i0[14:12] <= 3'b010);
   assign i1_cmx = (i1[6:0] == 7'b0001011) && (i1[31:25] == 7'b0000000) &&
                   (i1[14:12] <= 3'b010);
   assign i0_cmx_mul = i0_cmx && (i0[14:12] <= 3'b001);
   assign i1_cmx_mul = i1_cmx && (i1[14:12] <= 3'b001);
   assign i0_cmx_isdigit = i0_cmx && (i0[14:12] == 3'b010);
   assign i1_cmx_isdigit = i1_cmx && (i1[14:12] == 3'b010);
   assign i0_cmx_op = i0_cmx_mul ? ((i0[14:12] == 3'b000) ? 2'd1 : 2'd2) : 2'd0;
   assign i1_cmx_op = i1_cmx_mul ? ((i1[14:12] == 3'b000) ? 2'd1 : 2'd2) : 2'd0;
   assign i0_rm_legal = (i0[14:12] <= 3'b100) ||
                        ((i0[14:12] == 3'b111) && (dec_tlu_frm <= 3'b100));

   always_comb begin
      i0_fp_encoding_legal = 1'b0;
      i0_fp_writes_gpr = 1'b0;
      i0_fp_reads_gpr = 1'b0;
      if (i0[6:0] inside {7'b1000011,7'b1000111,7'b1001011,7'b1001111}) begin
         i0_fp_encoding_legal = (i0[26:25] == 2'b00) &&
                                i0_rm_legal;
      end else if (i0[6:0] == 7'b1010011) begin
         unique case (i0[31:25])
            7'b0000000, 7'b0000100, 7'b0001000, 7'b0001100:
               i0_fp_encoding_legal = i0_rm_legal;
            7'b0101100:
               i0_fp_encoding_legal = (i0[24:20] == 5'b0) &&
                                      i0_rm_legal;
            7'b0010000:
               i0_fp_encoding_legal = (i0[14:12] <= 3'b010);
            7'b0010100:
               i0_fp_encoding_legal = (i0[14:12] <= 3'b001);
            7'b1010000: begin
               i0_fp_encoding_legal = (i0[14:12] <= 3'b010);
               i0_fp_writes_gpr = 1'b1;
            end
            7'b1100000: begin
               i0_fp_encoding_legal = (i0[24:21] == 4'b0) &&
                                      i0_rm_legal;
               i0_fp_writes_gpr = 1'b1;
            end
            7'b1101000: begin
               i0_fp_encoding_legal = (i0[24:21] == 4'b0) &&
                                      i0_rm_legal;
               i0_fp_reads_gpr = 1'b1;
            end
            7'b1110000: begin
               i0_fp_encoding_legal = (i0[24:20] == 5'b0) &&
                                      ((i0[14:12] == 3'b000) || (i0[14:12] == 3'b001));
               i0_fp_writes_gpr = 1'b1;
            end
            7'b1111000: begin
               i0_fp_encoding_legal = (i0[24:20] == 5'b0) && (i0[14:12] == 3'b000);
               i0_fp_reads_gpr = 1'b1;
            end
            default: ;
         endcase
      end
   end

   always_comb begin
      i0_dp = i0_dp_raw;
      if (i0_cmx) begin
         i0_dp = '0;
         i0_dp.rs1 = 1'b1;
         i0_dp.rd = 1'b1;
         if (i0_cmx_mul) begin
            i0_dp.rs2 = 1'b1;
            i0_dp.mul = 1'b1;
            i0_dp.low = 1'b1;
         end else begin
            i0_dp.alu = 1'b1;
         end
         i0_dp.legal = 1'b1;
      end
      if (i0_fp_any) begin
         i0_dp = '0;
         i0_dp.legal = dec_tlu_fp_enabled;
         if (i0_fp_op) begin
            i0_dp.legal = dec_tlu_fp_enabled && i0_fp_encoding_legal;
            i0_dp.fpu = 1'b1;
            i0_dp.rd = i0_fp_writes_gpr;
            i0_dp.rs1 = i0_fp_reads_gpr;
            i0_dp.presync = 1'b1;
            i0_dp.postsync = 1'b1;
         end else if (i0_fpload) begin
            i0_dp.fpload = 1'b1;
            i0_dp.load = 1'b1;
            i0_dp.lsu = 1'b1;
            i0_dp.add = 1'b1;
            i0_dp.rs1 = 1'b1;
            i0_dp.imm12 = 1'b1;
            i0_dp.word = 1'b1;
         end else begin
            i0_dp.fpstore = 1'b1;
            i0_dp.store = 1'b1;
            i0_dp.lsu = 1'b1;
            i0_dp.add = 1'b1;
            i0_dp.rs1 = 1'b1;
            i0_dp.imm12 = 1'b1;
            i0_dp.word = 1'b1;
         end
      end
      if (i0_br_error_all | i0_instr_error) begin
         i0_dp = '0;
         i0_dp.alu = 1'b1;
         i0_dp.rs1 = 1'b1;
         i0_dp.rs2 = 1'b1;
         i0_dp.lor = 1'b1;
         i0_dp.legal = 1'b1;
         i0_dp.postsync = 1'b1;
      end

      i1_dp = i1_dp_raw;
      if (i1_cmx) begin
         i1_dp = '0;
         i1_dp.rs1 = 1'b1;
         i1_dp.rd = 1'b1;
         if (i1_cmx_mul) begin
            i1_dp.rs2 = 1'b1;
            i1_dp.mul = 1'b1;
            i1_dp.low = 1'b1;
         end else begin
            i1_dp.alu = 1'b1;
         end
         i1_dp.legal = 1'b1;
      end
      if (i1_br_error_all) begin
         i1_dp = '0;
         i1_dp.alu = 1'b1;
         i1_dp.rs1 = 1'b1;
         i1_dp.rs2 = 1'b1;
         i1_dp.lor = 1'b1;
         i1_dp.legal = 1'b1;
         i1_dp.postsync = 1'b1;
      end

   end

   assign flush_lower_wb = dec_tlu_flush_lower_wb;

   assign i0[31:0] = dec_i0_instr_d[31:0];

   assign i1[31:0] = dec_i1_instr_d[31:0];

   assign dec_i0_select_pc_d = i0_dp.pc;
   assign dec_i1_select_pc_d = i1_dp.pc;


   assign i0_predict_br =  i0_dp.condbr | i0_pcall | i0_pja | i0_pret;
   assign i1_predict_br =  i1_dp.condbr | i1_pcall | i1_pja | i1_pret;

   assign i0_predict_nt = ~(dec_i0_brp.hist[1] & i0_brp_valid) & i0_predict_br;
   assign i0_predict_t  =  (dec_i0_brp.hist[1] & i0_brp_valid) & i0_predict_br;

   assign i0_ap.valid =  (i0_dc.sec | i0_dc.alu | i0_dp.alu );
   assign i0_ap.add =    i0_dp.add;
   assign i0_ap.sub =    i0_dp.sub;
   assign i0_ap.land =   i0_dp.land;
   assign i0_ap.lor =    i0_dp.lor;
   assign i0_ap.lxor =   i0_dp.lxor;
   assign i0_ap.sll =    i0_dp.sll;
   assign i0_ap.srl =    i0_dp.srl;
   assign i0_ap.sra =    i0_dp.sra;
   assign i0_ap.slt =    i0_dp.slt;
   assign i0_ap.unsign = i0_dp.unsign;
   assign i0_ap.beq =    i0_dp.beq;
   assign i0_ap.bne =    i0_dp.bne;
   assign i0_ap.blt =    i0_dp.blt;
   assign i0_ap.bge =    i0_dp.bge;


   assign i0_ap.csr_write = i0_csr_write_only_d;
   assign i0_ap.csr_imm = i0_dp.csr_imm;
   assign i0_ap.cm_isdigit = i0_cmx_isdigit;


   assign i0_ap.jal    =  i0_jal;


   assign i0_ap_pc2 = ~dec_i0_pc4_d;
   assign i0_ap_pc4 =  dec_i0_pc4_d;

   assign i0_ap.predict_nt = i0_predict_nt;
   assign i0_ap.predict_t  = i0_predict_t;

   assign i1_predict_nt = ~(dec_i1_brp.hist[1] & dec_i1_brp.valid) & i1_predict_br;
   assign i1_predict_t  =  (dec_i1_brp.hist[1] & dec_i1_brp.valid) & i1_predict_br;

   assign i1_ap.valid =  (i1_dc.sec | i1_dc.alu | i1_dp.alu);
   assign i1_ap.add =    i1_dp.add;
   assign i1_ap.sub =    i1_dp.sub;
   assign i1_ap.land =   i1_dp.land;
   assign i1_ap.lor =    i1_dp.lor;
   assign i1_ap.lxor =   i1_dp.lxor;
   assign i1_ap.sll =    i1_dp.sll;
   assign i1_ap.srl =    i1_dp.srl;
   assign i1_ap.sra =    i1_dp.sra;
   assign i1_ap.slt =    i1_dp.slt;
   assign i1_ap.unsign = i1_dp.unsign;
   assign i1_ap.beq =    i1_dp.beq;
   assign i1_ap.bne =    i1_dp.bne;
   assign i1_ap.blt =    i1_dp.blt;
   assign i1_ap.bge =    i1_dp.bge;

   assign i1_ap.csr_write = 1'b0;
   assign i1_ap.csr_imm   = 1'b0;
   assign i1_ap.cm_isdigit = i1_cmx_isdigit;

   assign i1_ap.jal    =    i1_jal;

   assign i1_ap_pc2 = ~dec_i1_pc4_d;
   assign i1_ap_pc4 =  dec_i1_pc4_d;

   assign i1_ap.predict_nt = i1_predict_nt;
   assign i1_ap.predict_t  = i1_predict_t;

   always_comb begin
      found = 0;
      cam_wen[NBLOAD_SIZE_MSB:0] = '0;
      for (int i=0; i<NBLOAD_SIZE; i++) begin
         if (~found) begin
            if (~cam[i].valid) begin
               cam_wen[i] = cam_write;
               found = 1'b1;
            end
         end
      end
   end


   assign cam_reset_same_dest_wb = wbd.i0v & wbd.i1v & (wbd.i0rd[4:0] == wbd.i1rd[4:0]) &
                                   wbd.i0load & nonblock_load_valid_wb & ~dec_tlu_i0_kill_writeb_wb & ~dec_tlu_i1_kill_writeb_wb;


   assign cam_write          = lsu_nonblock_load_valid_dc3;
   assign cam_write_tag[NBLOAD_TAG_MSB:0] = lsu_nonblock_load_tag_dc3[NBLOAD_TAG_MSB:0];

   assign cam_inv_reset          = lsu_nonblock_load_inv_dc5 | cam_reset_same_dest_wb;
   assign cam_inv_reset_tag[NBLOAD_TAG_MSB:0] = lsu_nonblock_load_inv_tag_dc5[NBLOAD_TAG_MSB:0];

   assign cam_data_reset          = lsu_nonblock_load_data_valid | lsu_nonblock_load_data_error;
   assign cam_data_reset_tag[NBLOAD_TAG_MSB:0] = lsu_nonblock_load_data_tag[NBLOAD_TAG_MSB:0];

   assign nonblock_load_rd[4:0] = (e3d.i0load) ? e3d.i0rd[4:0] : e3d.i1rd[4:0];


   for (genvar i=0; i<NBLOAD_SIZE; i++) begin : cam_array

      assign cam_inv_reset_val[i] = cam_inv_reset   & (cam_inv_reset_tag[NBLOAD_TAG_MSB:0]  == cam[i].tag[NBLOAD_TAG_MSB:0]) & cam[i].valid;

      assign cam_data_reset_val[i] = cam_data_reset & (cam_data_reset_tag[NBLOAD_TAG_MSB:0] == cam[i].tag[NBLOAD_TAG_MSB:0]) & cam[i].valid;


      always_comb begin
         cam_in[i] = '0;

         if (cam_wen[i]) begin
            cam_in[i].valid    = 1'b1;
            cam_in[i].wb       = 1'b0;
            cam_in[i].tag[NBLOAD_TAG_MSB:0] = cam_write_tag[NBLOAD_TAG_MSB:0];
            cam_in[i].rd[4:0]  = nonblock_load_rd[4:0];
         end
         else if ( (cam_inv_reset_val[i]) |
                   (cam_data_reset_val[i]) |
                   (i0_wen_wb & (wbd.i0rd[4:0] == cam[i].rd[4:0]) & cam[i].wb) |
                   (i1_wen_wb & (wbd.i1rd[4:0] == cam[i].rd[4:0]) & cam[i].wb) )
           cam_in[i].valid = 1'b0;
         else
           cam_in[i] = cam[i];


         if (nonblock_load_valid_wb & (lsu_nonblock_load_inv_tag_dc5[NBLOAD_TAG_MSB:0]==cam[i].tag[NBLOAD_TAG_MSB:0]) & cam[i].valid)
           cam_in[i].wb = 1'b1;
      end

   rvdff #( $bits(load_cam_pkt_t) ) cam_ff (.*, .clk(free_clk), .din(cam_in[i]), .dout(cam[i]));


   assign nonblock_load_write[i] = (load_data_tag[NBLOAD_TAG_MSB:0] == cam[i].tag[NBLOAD_TAG_MSB:0]) & cam[i].valid;


end : cam_array


   assign load_data_tag[NBLOAD_TAG_MSB:0] = lsu_nonblock_load_data_tag[NBLOAD_TAG_MSB:0];


   assign nonblock_load_cancel = ((wbd.i0rd[4:0] == dec_nonblock_load_waddr[4:0]) & i0_wen_wb) |
                                 ((wbd.i1rd[4:0] == dec_nonblock_load_waddr[4:0]) & i1_wen_wb);


   assign dec_nonblock_load_wen = lsu_nonblock_load_data_valid & |nonblock_load_write[NBLOAD_SIZE_MSB:0] & ~nonblock_load_cancel;

   always_comb begin
      dec_nonblock_load_waddr[4:0] = '0;
      i0_nonblock_load_stall = i0_nonblock_boundary_stall;
      i1_nonblock_load_stall = i1_nonblock_boundary_stall;

      for (int i=0; i<NBLOAD_SIZE; i++) begin
         dec_nonblock_load_waddr[4:0] |= ({5{nonblock_load_write[i]}} & cam[i].rd[4:0]);

         i0_nonblock_load_stall |= dec_i0_rs1_en_d & cam[i].valid & (cam[i].rd[4:0] == i0r.rs1[4:0]);
         i0_nonblock_load_stall |= dec_i0_rs2_en_d & cam[i].valid & (cam[i].rd[4:0] == i0r.rs2[4:0]);

         i1_nonblock_load_stall |= dec_i1_rs1_en_d & cam[i].valid & (cam[i].rd[4:0] == i1r.rs1[4:0]);
         i1_nonblock_load_stall |= dec_i1_rs2_en_d & cam[i].valid & (cam[i].rd[4:0] == i1r.rs2[4:0]);

      end
   end

   assign i0_nonblock_boundary_stall = ((nonblock_load_rd[4:0]==i0r.rs1[4:0]) & lsu_nonblock_load_valid_dc3 & dec_i0_rs1_en_d) |
                                       ((nonblock_load_rd[4:0]==i0r.rs2[4:0]) & lsu_nonblock_load_valid_dc3 & dec_i0_rs2_en_d);

   assign i1_nonblock_boundary_stall = ((nonblock_load_rd[4:0]==i1r.rs1[4:0]) & lsu_nonblock_load_valid_dc3 & dec_i1_rs1_en_d) |
                                       ((nonblock_load_rd[4:0]==i1r.rs2[4:0]) & lsu_nonblock_load_valid_dc3 & dec_i1_rs2_en_d);

   assign i0_depend_load_e1_d = ((i0_rs1_class_d.load & (i0_rs1_depth_d[3:0]==4'd1 | i0_rs1_depth_d[3:0]==4'd2)) |
                                 (i0_rs2_class_d.load & (i0_rs2_depth_d[3:0]==4'd1 | i0_rs2_depth_d[3:0]==4'd2))) & dec_i0_decode_d;

   assign i0_depend_load_e2_d = ((i0_rs1_class_d.load & (i0_rs1_depth_d[3:0]==4'd3 | i0_rs1_depth_d[3:0]==4'd4)) |
                                 (i0_rs2_class_d.load & (i0_rs2_depth_d[3:0]==4'd3 | i0_rs2_depth_d[3:0]==4'd4))) & dec_i0_decode_d;

   assign i1_depend_load_e1_d = ((i1_rs1_class_d.load & (i1_rs1_depth_d[3:0]==4'd1 | i1_rs1_depth_d[3:0]==4'd2)) |
                                 (i1_rs2_class_d.load & (i1_rs2_depth_d[3:0]==4'd1 | i1_rs2_depth_d[3:0]==4'd2))) & dec_i1_decode_d;

   assign i1_depend_load_e2_d = ((i1_rs1_class_d.load & (i1_rs1_depth_d[3:0]==4'd3 | i1_rs1_depth_d[3:0]==4'd4)) |
                                 (i1_rs2_class_d.load & (i1_rs2_depth_d[3:0]==4'd3 | i1_rs2_depth_d[3:0]==4'd4))) & dec_i1_decode_d;


   assign depend_load_e1_d = i0_depend_load_e1_d | i1_depend_load_e1_d;

   assign depend_load_e2_d = i0_depend_load_e2_d | i1_depend_load_e2_d;

   assign depend_load_same_cycle_d = i1_depend_i0_d & i0_dp.load & dec_i1_decode_d;


   rvdffs #(2) e1loadff (.*,
                         .clk(active_clk),
                         .en(i0_e1_ctl_en),
                         .din( {depend_load_e1_d,  depend_load_same_cycle_d}),
                         .dout({depend_load_e2_e1, depend_load_same_cycle_e1})
                         );

   rvdffs #(1) e2loadff (.*,
                         .clk(active_clk),
                         .en(i0_e2_ctl_en),
                         .din( depend_load_same_cycle_e1),
                         .dout(depend_load_same_cycle_e2)
                         );

   assign dec_nonblock_load_freeze_dc2 = depend_load_e2_d | depend_load_e2_e1 | depend_load_same_cycle_e2;


   rvdffs #(1) e4nbloadff (.*, .clk(active_clk), .en(i0_e4_ctl_en), .din(lsu_nonblock_load_valid_dc3),  .dout(nonblock_load_valid_dc4) );
   rvdffs #(1) wbnbloadff (.*, .clk(active_clk), .en(i0_wb_ctl_en), .din(    nonblock_load_valid_dc4),  .dout(nonblock_load_valid_wb) );


   assign i0_load_kill_wen = nonblock_load_valid_wb &  wbd.i0load;
   assign i1_load_kill_wen = nonblock_load_valid_wb &  wbd.i1load;


   assign csr_read = dec_csr_ren_d;
   assign csr_write = dec_csr_wen_unq_d;

   assign i0_br_unpred = (i0_dp.condbr | i0_dp.jal) & ~i0_predict_br;
   assign i1_br_unpred = (i1_dp.condbr | i1_dp.jal) & ~i1_predict_br;


   always_comb begin
      i0_itype = NULL;
      i1_itype = NULL;

      if (i0_legal_decode_d) begin
         if (i0_dp.mul)                  i0_itype = MUL;
         if (i0_dp.load)                 i0_itype = LOAD;
         if (i0_dp.store)                i0_itype = STORE;
         if (i0_dp.pm_alu)               i0_itype = ALU;
         if ( csr_read & ~csr_write)     i0_itype = CSRREAD;
         if (~csr_read &  csr_write)     i0_itype = CSRWRITE;
         if ( csr_read &  csr_write)     i0_itype = CSRRW;
         if (i0_dp.ebreak)               i0_itype = EBREAK;
         if (i0_dp.ecall)                i0_itype = ECALL;
         if (i0_dp.fence)                i0_itype = FENCE;
         if (i0_dp.fence_i)              i0_itype = FENCEI;
         if (i0_dp.mret)                 i0_itype = MRET;
         if (i0_dp.condbr)               i0_itype = CONDBR;
         if (i0_dp.jal)                  i0_itype = JAL;
      end

      if (dec_i1_decode_d) begin
         if (i1_dp.mul)                  i1_itype = MUL;
         if (i1_dp.load)                 i1_itype = LOAD;
         if (i1_dp.store)                i1_itype = STORE;
         if (i1_dp.pm_alu)               i1_itype = ALU;
         if (i1_dp.condbr)               i1_itype = CONDBR;
         if (i1_dp.jal)                  i1_itype = JAL;
      end


   end


   dec_dec_ctl i0_dec (.inst(i0[31:0]),.out(i0_dp_raw));

   dec_dec_ctl i1_dec (.inst(i1[31:0]),.out(i1_dp_raw));

   rvdff #(1) lsu_idle_ff (.*, .clk(active_clk), .din(lsu_halt_idle_any), .dout(lsu_idle));


   assign leak1_i1_stall_in = (dec_tlu_flush_leak_one_wb | (leak1_i1_stall & ~dec_tlu_flush_lower_wb));

   rvdff #(1) leak1_i1_stall_ff (.*, .clk(free_clk), .din(leak1_i1_stall_in), .dout(leak1_i1_stall));

   assign leak1_mode = leak1_i1_stall;

   assign leak1_i0_stall_in = ((dec_i0_decode_d & leak1_i1_stall) | (leak1_i0_stall & ~dec_tlu_flush_lower_wb));

   rvdff #(1) leak1_i0_stall_ff (.*, .clk(free_clk), .din(leak1_i0_stall_in), .dout(leak1_i0_stall));


   assign i0_pcall_imm[20:1] = {i0[31],i0[19:12],i0[20],i0[30:21]};

   assign i0_pcall_12b_offset = (i0_pcall_imm[12]) ? (i0_pcall_imm[20:13] == 8'hff) : (i0_pcall_imm[20:13] == 8'h0);

   assign i0_pcall_case  = i0_pcall_12b_offset & i0_dp_raw.imm20 & i0r.rd[4:0]!=5'b0;
   assign i0_pja_case    = i0_pcall_12b_offset & i0_dp_raw.imm20 & i0r.rd[4:0]==5'b0;

   assign i1_pcall_imm[20:1] = {i1[31],i1[19:12],i1[20],i1[30:21]};

   assign i1_pcall_12b_offset = (i1_pcall_imm[12]) ? (i1_pcall_imm[20:13] == 8'hff) : (i1_pcall_imm[20:13] == 8'h0);

   assign i1_pcall_case  = i1_pcall_12b_offset & i1_dp_raw.imm20 & i1r.rd[4:0]!=5'b0;
   assign i1_pja_case    = i1_pcall_12b_offset & i1_dp_raw.imm20 & i1r.rd[4:0]==5'b0;


   assign i0_pcall_raw = i0_dp_raw.jal &   i0_pcall_case;
   assign i0_pcall     = i0_dp.jal     &   i0_pcall_case;

   assign i1_pcall_raw = i1_dp_raw.jal &   i1_pcall_case;
   assign i1_pcall     = i1_dp.jal     &   i1_pcall_case;

   assign i0_pja_raw = i0_dp_raw.jal &   i0_pja_case;
   assign i0_pja     = i0_dp.jal     &   i0_pja_case;

   assign i1_pja_raw = i1_dp_raw.jal &   i1_pja_case;
   assign i1_pja     = i1_dp.jal     &   i1_pja_case;


   assign i0_br_offset[11:0] = (i0_pcall_raw | i0_pja_raw) ? i0_pcall_imm[12:1] : {i0[31],i0[7],i0[30:25],i0[11:8]};

   assign i1_br_offset[11:0] = (i1_pcall_raw | i1_pja_raw) ? i1_pcall_imm[12:1] : {i1[31],i1[7],i1[30:25],i1[11:8]};


   assign i0_pret_case = (i0_dp_raw.jal & i0_dp_raw.imm12 & i0r.rd[4:0]==5'b0 & i0r.rs1[4:0]==5'b1);
   assign i1_pret_case = (i1_dp_raw.jal & i1_dp_raw.imm12 & i1r.rd[4:0]==5'b0 & i1r.rs1[4:0]==5'b1);

   assign i0_pret_raw = i0_dp_raw.jal &   i0_pret_case;
   assign i0_pret    = i0_dp.jal     &   i0_pret_case;

   assign i1_pret_raw = i1_dp_raw.jal &   i1_pret_case;
   assign i1_pret     = i1_dp.jal     &   i1_pret_case;

   assign i0_jal    = i0_dp.jal  &  ~i0_pcall_case & ~i0_pja_case & ~i0_pret_case;
   assign i1_jal    = i1_dp.jal  &  ~i1_pcall_case & ~i1_pja_case & ~i1_pret_case;


   assign dec_lsu_offset_d[11:0] =
                                   ({12{ i0_dp.lsu & i0_dp.load}} &               i0[31:20]) |
                                   ({12{~i0_dp.lsu & i1_dp.lsu & i1_dp.load}} &   i1[31:20]) |
                                   ({12{ i0_dp.lsu & i0_dp.store}} &             {i0[31:25],i0[11:7]}) |
                                   ({12{~i0_dp.lsu & i1_dp.lsu & i1_dp.store}} & {i1[31:25],i1[11:7]});


   assign dec_i0_lsu_d = i0_dp.lsu;
   assign dec_i1_lsu_d = i1_dp.lsu;

   assign dec_i0_mul_d = i0_dp.mul;
   assign dec_i1_mul_d = i1_dp.mul;

   assign dec_i0_div_d = i0_dp.div;
   assign dec_i1_div_d = i1_dp.div;


   assign div_p.valid = div_decode_d;

   assign div_p.unsign = (i0_dp.div) ? i0_dp.unsign :   i1_dp.unsign;
   assign div_p.rem  =   (i0_dp.div) ? i0_dp.rem    :   i1_dp.rem;


   assign mul_p.valid = mul_decode_d;

   assign mul_p.rs1_sign =   (i0_dp.mul) ? i0_dp.rs1_sign :   i1_dp.rs1_sign;
   assign mul_p.rs2_sign =   (i0_dp.mul) ? i0_dp.rs2_sign :   i1_dp.rs2_sign;
   assign mul_p.low      =   (i0_dp.mul) ? i0_dp.low      :   i1_dp.low;
   assign mul_p.cm_op    =   (i0_dp.mul) ? i0_cmx_op      :   i1_cmx_op;

   assign mul_p.load_mul_rs1_bypass_e1 = load_mul_rs1_bypass_e1;
   assign mul_p.load_mul_rs2_bypass_e1 = load_mul_rs2_bypass_e1;


   assign lsu_p.valid = lsu_decode_d;

   assign lsu_p.load =   (i0_dp.lsu) ? i0_dp.load :   i1_dp.load;
   assign lsu_p.store =  (i0_dp.lsu) ? i0_dp.store :  i1_dp.store;
   assign lsu_p.by =     (i0_dp.lsu) ? i0_dp.by :     i1_dp.by;
   assign lsu_p.half =   (i0_dp.lsu) ? i0_dp.half :   i1_dp.half;
   assign lsu_p.word =   (i0_dp.lsu) ? i0_dp.word :   i1_dp.word;
   assign lsu_p.store_data_bypass_i0_e2_c2   = store_data_bypass_i0_e2_c2;
   assign lsu_p.load_ldst_bypass_c1 = load_ldst_bypass_c1;
   assign lsu_p.store_data_bypass_c1 = store_data_bypass_c1 & ~store_data_bypass_i0_e2_c2;
   assign lsu_p.store_data_bypass_c2 = store_data_bypass_c2 & ~store_data_bypass_i0_e2_c2;
   assign lsu_p.store_data_bypass_e4_c1[1:0] = store_data_bypass_e4_c1[1:0] & ~{2{store_data_bypass_i0_e2_c2}};
   assign lsu_p.store_data_bypass_e4_c2[1:0] = store_data_bypass_e4_c2[1:0] & ~{2{store_data_bypass_i0_e2_c2}};
   assign lsu_p.store_data_bypass_e4_c3[1:0] = store_data_bypass_e4_c3[1:0] & ~{2{store_data_bypass_i0_e2_c2}};

   assign lsu_p.unsign = (i0_dp.lsu) ? i0_dp.unsign : i1_dp.unsign;


   assign i0r.rs1[4:0] = i0[19:15];
   assign i0r.rs2[4:0] = i0[24:20];
   assign i0r.rd[4:0] = i0[11:7];

   assign i1r.rs1[4:0] = i1[19:15];
   assign i1r.rs2[4:0] = i1[24:20];
   assign i1r.rd[4:0] = i1[11:7];


   assign dec_i0_rs1_en_d = i0_dp.rs1 & (i0r.rs1[4:0] != 5'd0);
   assign dec_i0_rs2_en_d = i0_dp.rs2 & (i0r.rs2[4:0] != 5'd0);
   assign i0_rd_en_d =  i0_dp.rd & (i0r.rd[4:0] != 5'd0);

   assign dec_i0_rs1_d[4:0] = i0r.rs1[4:0];
   assign dec_i0_rs2_d[4:0] = i0r.rs2[4:0];
   assign i0_rd_d[4:0] = i0r.rd[4:0];


   assign i0_jalimm20 = i0_dp.jal & i0_dp.imm20;
   assign i1_jalimm20 = i1_dp.jal & i1_dp.imm20;


   assign i0_uiimm20 = ~i0_dp.jal & i0_dp.imm20;
   assign i1_uiimm20 = ~i1_dp.jal & i1_dp.imm20;


   assign dec_csr_ren_d = i0_dp.csr_read & i0_legal_decode_d;

   assign csr_clr_d =   i0_dp.csr_clr   & i0_legal_decode_d;
   assign csr_set_d   = i0_dp.csr_set   & i0_legal_decode_d;
   assign csr_write_d = i0_csr_write    & i0_legal_decode_d;

   assign i0_csr_write_only_d = i0_csr_write & ~i0_dp.csr_read;

   assign dec_csr_wen_unq_d = (i0_dp.csr_clr | i0_dp.csr_set | i0_csr_write);

   assign dec_csr_any_unq_d = any_csr_d;


   assign dec_csr_rdaddr_d[11:0] = i0[31:20];
   assign dec_csr_wraddr_wb[11:0] = wbd.csrwaddr[11:0];


   assign dec_csr_wen_wb = wbd.csrwen & wbd.i0valid & ~dec_tlu_i0_kill_writeb_wb;


   assign dec_csr_stall_int_ff = ((e4d.csrwaddr[11:0] == 12'h300) | (e4d.csrwaddr[11:0] == 12'h304)) & e4d.csrwen & e4d.i0valid & ~dec_tlu_i0_kill_writeb_wb;


   rvdffs #(5) csrmiscff (.*,
                        .en(~freeze),
                        .clk(active_clk),
                        .din({ dec_csr_ren_d,  csr_clr_d,  csr_set_d,  csr_write_d,  i0_dp.csr_imm}),
                        .dout({csr_read_e1,    csr_clr_e1, csr_set_e1, csr_write_e1, csr_imm_e1})
                       );


   rvdffe #(37) csr_data_e1ff (.*, .en(i0_e1_data_en), .din( {i0[19:15],dec_csr_rddata_d[31:0]}), .dout({csrimm_e1[4:0],csr_rddata_e1[31:0]}));


   assign csr_mask_e1[31:0] = ({32{ csr_imm_e1}} & {27'b0,csrimm_e1[4:0]}) |
                              ({32{~csr_imm_e1}} &  exu_csr_rs1_e1[31:0]);


   assign write_csr_data_e1[31:0] = ({32{csr_clr_e1}}   & (csr_rddata_e1[31:0] & ~csr_mask_e1[31:0])) |
                                    ({32{csr_set_e1}}   & (csr_rddata_e1[31:0] |  csr_mask_e1[31:0])) |
                                    ({32{csr_write_e1}} & (                       csr_mask_e1[31:0]));


   assign clear_pause = (dec_tlu_flush_lower_wb & ~dec_tlu_flush_pause_wb) |
                        (pause_state & (write_csr_data[31:1] == 31'b0));

   assign pause_state_in = (dec_tlu_wr_pause_wb | pause_state) & ~clear_pause;

   rvdff #(1) pause_state_f (.*, .clk(free_clk), .din(pause_state_in), .dout(pause_state));


   assign dec_pause_state = pause_state;

   rvdff #(2) pause_state_wb_ff (.*, .clk(free_clk), .din({dec_tlu_wr_pause_wb,tlu_wr_pause_wb1}), .dout({tlu_wr_pause_wb1,tlu_wr_pause_wb2}));


   assign dec_pause_state_cg = pause_state & ~tlu_wr_pause_wb1 & ~tlu_wr_pause_wb2;


   assign csr_data_wen = ((csr_clr_e1 | csr_set_e1 | csr_write_e1) & csr_read_e1 & ~freeze) | dec_tlu_wr_pause_wb | pause_state;

   assign write_csr_data_in[31:0] = (pause_state)         ? (write_csr_data[31:0] - 32'b1) :
                                    (dec_tlu_wr_pause_wb) ? dec_csr_wrdata_wb[31:0] : write_csr_data_e1[31:0];


   rvdffe #(32) write_csr_ff (.*, .en(csr_data_wen), .din(write_csr_data_in[31:0]), .dout(write_csr_data[31:0]));

   assign pause_stall = pause_state;


   assign dec_csr_wrdata_wb[31:0] = (wbd.csrwonly) ? i0_result_wb[31:0] : write_csr_data[31:0];


   assign dec_i0_immed_d[31:0] = ({32{ i0_dp.csr_read}} & dec_csr_rddata_d[31:0]) |
                                 ({32{~i0_dp.csr_read}} & i0_immed_d[31:0]);


   assign     i0_immed_d[31:0] = ({32{i0_dp.imm12}} &   { {20{i0[31]}},i0[31:20] }) |
                                 ({32{i0_dp.shimm5}} &    {27'b0, i0[24:20]}) |
                                 ({32{i0_jalimm20}} &   { {12{i0[31]}},i0[19:12],i0[20],i0[30:21],1'b0}) |
                                 ({32{i0_uiimm20}}  &     {i0[31:12],12'b0 }) |
                                 ({32{i0_csr_write_only_d & i0_dp.csr_imm}} & {27'b0,i0[19:15]});


   assign dec_i0_br_immed_d[12:1] = (i0_ap.predict_nt & ~i0_dp.jal) ? i0_br_offset[11:0] : {10'b0,i0_ap_pc4,i0_ap_pc2};


   assign dec_i1_rs1_en_d = i1_dp.rs1 & (i1r.rs1[4:0] != 5'd0);
   assign dec_i1_rs2_en_d = i1_dp.rs2 & (i1r.rs2[4:0] != 5'd0);
   assign i1_rd_en_d =  i1_dp.rd & (i1r.rd[4:0] != 5'd0);

   assign dec_i1_rs1_d[4:0] = i1r.rs1[4:0];
   assign dec_i1_rs2_d[4:0] = i1r.rs2[4:0];
   assign i1_rd_d[4:0] = i1r.rd[4:0];


   assign dec_i1_immed_d[31:0] = ({32{i1_dp.imm12}} &   { {20{i1[31]}},i1[31:20] }) |
                                 ({32{i1_dp.shimm5}} &    {27'b0, i1[24:20]}) |
                                 ({32{i1_jalimm20}} &   { {12{i1[31]}},i1[19:12],i1[20],i1[30:21],1'b0}) |
                                 ({32{i1_uiimm20}}  &     {i1[31:12],12'b0 });


   assign dec_i1_br_immed_d[12:1] = (i1_ap.predict_nt & ~i1_dp.jal) ? i1_br_offset[11:0] : {10'b0,i1_ap_pc4,i1_ap_pc2};


   assign last_br_immed_d[12:1] = (dec_i1_decode_d) ?
                                  ((i1_ap.predict_nt) ? {10'b0,i1_ap_pc4,i1_ap_pc2} : i1_br_offset[11:0] ) :
                                  ((i0_ap.predict_nt) ? {10'b0,i0_ap_pc4,i0_ap_pc2} : i0_br_offset[11:0] );

   assign i0_valid_d = dec_ib0_valid_d;
   assign i1_valid_d = dec_ib1_valid_d;


   assign i0_load_stall_d = i0_dp.load & lsu_load_stall_any;
   assign i1_load_stall_d = i1_dp.load & lsu_load_stall_any;

   assign i0_store_stall_d = i0_dp.store & lsu_store_stall_any;
   assign i1_store_stall_d = i1_dp.store & lsu_store_stall_any;

   assign i1_depend_i0_d = (dec_i1_rs1_en_d & i0_dp.rd & (i1r.rs1[4:0] == i0r.rd[4:0])) |
                           (dec_i1_rs2_en_d & i0_dp.rd & (i1r.rs2[4:0] == i0r.rd[4:0]));


   assign i1_load2_block_d = i1_dp.lsu & i0_dp.lsu;


   assign i0_presync = i0_dp.presync | dec_tlu_presync_d | debug_fence_i | debug_fence_raw | dec_tlu_pipelining_disable;

   assign i0_postsync = i0_dp.postsync | dec_tlu_postsync_d | debug_fence_i |
                        (i0_csr_write_only_d & (i0[31:20] == 12'h7c2));

   assign i1_mul2_block_d  = i1_dp.mul & i0_dp.mul;


   assign debug_fence_i     = dec_debug_fence_d & dbg_cmd_wrdata[0];
   assign debug_fence_raw   = dec_debug_fence_d & dbg_cmd_wrdata[1];

   assign debug_fence = debug_fence_raw | debug_fence_i;


   assign i0_csr_write = i0_dp.csr_write & ~dec_debug_fence_d;


   assign presync_stall = (i0_presync & prior_inflight_eff);

   assign prior_inflight_eff = (i0_dp.div) ? prior_inflight_e1e3 : prior_inflight;

   assign fload_e1 = e1d.i0valid && (i0_inst_e1[6:0] == 7'b0000111) && (i0_inst_e1[14:12] == 3'b010);
   assign fload_e2 = e2d.i0valid && (i0_inst_e2[6:0] == 7'b0000111) && (i0_inst_e2[14:12] == 3'b010);
   assign fload_e3 = e3d.i0valid && (i0_inst_e3[6:0] == 7'b0000111) && (i0_inst_e3[14:12] == 3'b010);
   assign fload_e4 = e4d.i0valid && (i0_inst_e4[6:0] == 7'b0000111) && (i0_inst_e4[14:12] == 3'b010);
   assign fload_wb = wbd.i0valid && (i0_inst_wb[6:0] == 7'b0000111) && (i0_inst_wb[14:12] == 3'b010);
   assign fload_rd_e1 = i0_inst_e1[11:7];
   assign fload_rd_e2 = i0_inst_e2[11:7];
   assign fload_rd_e3 = i0_inst_e3[11:7];
   assign fload_rd_e4 = i0_inst_e4[11:7];
   assign fload_rd_wb = i0_inst_wb[11:7];

   assign fpr_hazard_stall = (i0_fp_op || i0_fpstore) &&
      ((fload_e1 && ((fload_rd_e1 == i0[19:15]) || (fload_rd_e1 == i0[24:20]) || (fload_rd_e1 == i0[31:27]))) ||
       (fload_e2 && ((fload_rd_e2 == i0[19:15]) || (fload_rd_e2 == i0[24:20]) || (fload_rd_e2 == i0[31:27]))) ||
       (fload_e3 && ((fload_rd_e3 == i0[19:15]) || (fload_rd_e3 == i0[24:20]) || (fload_rd_e3 == i0[31:27]))) ||
       (fload_e4 && ((fload_rd_e4 == i0[19:15]) || (fload_rd_e4 == i0[24:20]) || (fload_rd_e4 == i0[31:27]))) ||
       (fload_wb && ((fload_rd_wb == i0[19:15]) || (fload_rd_wb == i0[24:20]) || (fload_rd_wb == i0[31:27]))));

   assign i0_block_d = (i0_dp.csr_read & prior_csr_write) |
                       pause_stall |
                       leak1_i0_stall |
                       dec_tlu_debug_stall |
                       postsync_stall |
                       presync_stall  |
                       ((i0_dp.fence | debug_fence) & ~lsu_idle) |
                       i0_nonblock_load_stall |
                       i0_load_block_d |
                       i0_mul_block_d |
                       i0_store_stall_d |
                       i0_load_stall_d |
                       i0_secondary_stall_d |
                        i0_secondary_block_d |
                        fpr_hazard_stall |
                        (i0_dp.fpu & ~fpu_req_ready);

   assign i1_block_d = leak1_i1_stall |
                      (i0_jal) |
              (((|dec_i0_trigger_match_d[3:0]) | ((i0_dp.condbr | i0_dp.jal) & i0_secondary_d)) & i1_dp.load ) |
                       i0_presync | i0_postsync |
                       i1_dp.presync | i1_dp.postsync |
                       i1_icaf_d |
                       dec_i1_perr_d |
                       dec_i1_sbecc_d |
                       i0_dp.csr_read |
                       i0_dp.csr_write |
                       i1_dp.csr_read |
                       i1_dp.csr_write |
                       i1_nonblock_load_stall |
                       i1_store_stall_d |
                       i1_load_block_d |
                       i1_mul_block_d |
                       (i1_depend_i0_d & ~non_block_case_d & ~store_data_bypass_i0_e2_c2) |
                       i1_load2_block_d |
                       i1_mul2_block_d |
                       i1_load_stall_d |
                       i1_secondary_block_d |
                       dec_tlu_dual_issue_disable |
                       i1_fp_any;


   assign prior_csr_write = e1d.csrwonly |
                            e2d.csrwonly |
                            e3d.csrwonly |
                            e4d.csrwonly |
                            wbd.csrwonly;


   assign any_csr_d = i0_dp.csr_read | i0_csr_write;


   assign i0_legal = i0_dp.legal & (~any_csr_d | dec_csr_legal_d);


   assign shift_illegal = dec_i0_decode_d & ~i0_legal;

   assign illegal_inst_en = shift_illegal & ~illegal_lockout & ~freeze;

   assign illegal_inst[31:0] = (dec_i0_pc4_d) ? i0[31:0] : { 16'b0, ifu_illegal_inst[15:0] };

   rvdffe #(32) illegal_any_ff (.*, .en(illegal_inst_en), .din(illegal_inst[31:0]), .dout(dec_illegal_inst[31:0]));

   assign illegal_lockout_in = (shift_illegal | illegal_lockout) & ~flush_final_e3;

   rvdffs #(1) illegal_lockout_any_ff (.*, .clk(active_clk), .en(~freeze), .din(illegal_lockout_in), .dout(illegal_lockout));


   assign dec_i0_decode_d = i0_valid_d & ~i0_block_d & ~flush_lower_wb & ~flush_final_e3 & ~freeze;


   assign i0_legal_decode_d = dec_i0_decode_d & i0_legal & ~freeze;


   assign dec_i1_decode_d = i0_legal_decode_d & i1_valid_d & i1_dp.legal & ~i1_block_d & ~freeze;

   assign dec_ib0_valid_eff_d = i0_valid_d & ~dec_i0_decode_d;
   assign dec_ib1_valid_eff_d = i1_valid_d & ~dec_i1_decode_d;


   assign dec_pmu_instr_decoded[1:0] = { dec_i1_decode_d, dec_i0_decode_d };

   assign dec_pmu_decode_stall = i0_valid_d & ~dec_i0_decode_d;

   assign dec_pmu_postsync_stall = postsync_stall;
   assign dec_pmu_presync_stall  = presync_stall;


   assign ps_stall_in =  (dec_i0_decode_d & (i0_jal | (i0_postsync) | ~i0_legal))  |
                         (dec_i1_decode_d &  i1_jal ) |
                          ((ps_stall & prior_inflight_e1e4) & ~(div_wen_wb | fpu_wen_wb));


    rvdffs #(1) postsync_stallff (.*, .clk(free_clk), .en(~freeze), .din(ps_stall_in), .dout(ps_stall));

   assign postsync_stall = (ps_stall | div_stall | fpu_stall);


   assign prior_inflight_e1e3 =       |{ e1d.i0valid,
                                         e2d.i0valid,
                                         e3d.i0valid,
                                         e1d.i1valid,
                                         e2d.i1valid,
                                         e3d.i1valid
                                         };


   assign prior_inflight_e1e4 =       |{ e1d.i0valid,
                                         e2d.i0valid,
                                         e3d.i0valid,
                                         e4d.i0valid,
                                         e1d.i1valid,
                                         e2d.i1valid,
                                         e3d.i1valid,
                                         e4d.i1valid
                                         };


   assign prior_inflight_wb =            |{
                                           wbd.i0valid,
                                           wbd.i1valid
                                           };

   assign prior_inflight = prior_inflight_e1e4 | prior_inflight_wb;

   assign dec_i0_alu_decode_d = i0_legal_decode_d & i0_dp.alu & ~i0_secondary_d;
   assign dec_i1_alu_decode_d = dec_i1_decode_d & i1_dp.alu & ~i1_secondary_d;

   assign dec_i0_lsu_decode_d = i0_legal_decode_d & i0_dp.lsu;

   assign lsu_decode_d = (i0_legal_decode_d & i0_dp.lsu) |
                         (dec_i1_decode_d & i1_dp.lsu);

   assign mul_decode_d = (i0_legal_decode_d & i0_dp.mul) |
                         (dec_i1_decode_d & i1_dp.mul);

   assign div_decode_d = (i0_legal_decode_d & i0_dp.div) |
                         (dec_i1_decode_d & i1_dp.div);


   rvdffs #(2) flushff (.*, .en(~freeze), .clk(free_clk), .din({exu_i0_flush_final,exu_i1_flush_final}), .dout({i0_flush_final_e3, i1_flush_final_e3}));


   assign flush_final_e3 = i0_flush_final_e3 | i1_flush_final_e3;


   assign i0_rs1_depend_i0_e1 = dec_i0_rs1_en_d & e1d.i0v & (e1d.i0rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i0_e2 = dec_i0_rs1_en_d & e2d.i0v & (e2d.i0rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i0_e3 = dec_i0_rs1_en_d & e3d.i0v & (e3d.i0rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i0_e4 = dec_i0_rs1_en_d & e4d.i0v & (e4d.i0rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i0_wb = dec_i0_rs1_en_d & wbd.i0v & (wbd.i0rd[4:0] == i0r.rs1[4:0]);

   assign i0_rs1_depend_i1_e1 = dec_i0_rs1_en_d & e1d.i1v & (e1d.i1rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i1_e2 = dec_i0_rs1_en_d & e2d.i1v & (e2d.i1rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i1_e3 = dec_i0_rs1_en_d & e3d.i1v & (e3d.i1rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i1_e4 = dec_i0_rs1_en_d & e4d.i1v & (e4d.i1rd[4:0] == i0r.rs1[4:0]);
   assign i0_rs1_depend_i1_wb = dec_i0_rs1_en_d & wbd.i1v & (wbd.i1rd[4:0] == i0r.rs1[4:0]);

   assign i0_rs2_depend_i0_e1 = dec_i0_rs2_en_d & e1d.i0v & (e1d.i0rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i0_e2 = dec_i0_rs2_en_d & e2d.i0v & (e2d.i0rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i0_e3 = dec_i0_rs2_en_d & e3d.i0v & (e3d.i0rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i0_e4 = dec_i0_rs2_en_d & e4d.i0v & (e4d.i0rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i0_wb = dec_i0_rs2_en_d & wbd.i0v & (wbd.i0rd[4:0] == i0r.rs2[4:0]);

   assign i0_rs2_depend_i1_e1 = dec_i0_rs2_en_d & e1d.i1v & (e1d.i1rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i1_e2 = dec_i0_rs2_en_d & e2d.i1v & (e2d.i1rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i1_e3 = dec_i0_rs2_en_d & e3d.i1v & (e3d.i1rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i1_e4 = dec_i0_rs2_en_d & e4d.i1v & (e4d.i1rd[4:0] == i0r.rs2[4:0]);
   assign i0_rs2_depend_i1_wb = dec_i0_rs2_en_d & wbd.i1v & (wbd.i1rd[4:0] == i0r.rs2[4:0]);


   assign i1_rs1_depend_i0_e1 = dec_i1_rs1_en_d & e1d.i0v & (e1d.i0rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i0_e2 = dec_i1_rs1_en_d & e2d.i0v & (e2d.i0rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i0_e3 = dec_i1_rs1_en_d & e3d.i0v & (e3d.i0rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i0_e4 = dec_i1_rs1_en_d & e4d.i0v & (e4d.i0rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i0_wb = dec_i1_rs1_en_d & wbd.i0v & (wbd.i0rd[4:0] == i1r.rs1[4:0]);

   assign i1_rs1_depend_i1_e1 = dec_i1_rs1_en_d & e1d.i1v & (e1d.i1rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i1_e2 = dec_i1_rs1_en_d & e2d.i1v & (e2d.i1rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i1_e3 = dec_i1_rs1_en_d & e3d.i1v & (e3d.i1rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i1_e4 = dec_i1_rs1_en_d & e4d.i1v & (e4d.i1rd[4:0] == i1r.rs1[4:0]);
   assign i1_rs1_depend_i1_wb = dec_i1_rs1_en_d & wbd.i1v & (wbd.i1rd[4:0] == i1r.rs1[4:0]);

   assign i1_rs2_depend_i0_e1 = dec_i1_rs2_en_d & e1d.i0v & (e1d.i0rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i0_e2 = dec_i1_rs2_en_d & e2d.i0v & (e2d.i0rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i0_e3 = dec_i1_rs2_en_d & e3d.i0v & (e3d.i0rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i0_e4 = dec_i1_rs2_en_d & e4d.i0v & (e4d.i0rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i0_wb = dec_i1_rs2_en_d & wbd.i0v & (wbd.i0rd[4:0] == i1r.rs2[4:0]);

   assign i1_rs2_depend_i1_e1 = dec_i1_rs2_en_d & e1d.i1v & (e1d.i1rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i1_e2 = dec_i1_rs2_en_d & e2d.i1v & (e2d.i1rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i1_e3 = dec_i1_rs2_en_d & e3d.i1v & (e3d.i1rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i1_e4 = dec_i1_rs2_en_d & e4d.i1v & (e4d.i1rd[4:0] == i1r.rs2[4:0]);
   assign i1_rs2_depend_i1_wb = dec_i1_rs2_en_d & wbd.i1v & (wbd.i1rd[4:0] == i1r.rs2[4:0]);


   rvdff #(2) freezeff (.*, .clk(active_clk), .din({freeze,freeze_prior1}), .dout({freeze_prior1,freeze_prior2}));


   assign freeze_after_unfreeze1 = freeze & ~freeze_prior1;
   assign freeze_after_unfreeze2 = freeze & ~freeze_prior1 & ~freeze_prior2;

   assign unfreeze_cycle1 = ~freeze & freeze_prior1;
   assign unfreeze_cycle2 = ~freeze & ~freeze_prior1 & freeze_prior2;

   rvdffe #(32) freeze_i0_e4ff (.*, .en(freeze_after_unfreeze1), .din(i0_result_e4_final[31:0]), .dout(i0_result_e4_freeze[31:0]));
   rvdffe #(32) freeze_i1_e4ff (.*, .en(freeze_after_unfreeze1), .din(i1_result_e4_final[31:0]), .dout(i1_result_e4_freeze[31:0]));


   rvdffe #(32) freeze_i0_wbff (.*,
                              .en(freeze_after_unfreeze1),
                              .din( (freeze_after_unfreeze2) ? i0_result_wb[31:0] : i0_result_e4_freeze[31:0]),
                              .dout(i0_result_wb_freeze[31:0])
                              );

   rvdffe #(32) freeze_i1_wbff (.*,
                              .en(freeze_after_unfreeze1),
                              .din( (freeze_after_unfreeze2) ? i1_result_wb[31:0] : i1_result_e4_freeze[31:0]),
                              .dout(i1_result_wb_freeze[31:0])
                              );


   assign dd.i0rs1bype2[1:0] = {  i0_dp.alu & i0_rs1_depth_d[3:0] == 4'd5 & i0_rs1_class_d.sec,
                                  i0_dp.alu & i0_rs1_depth_d[3:0] == 4'd6 & i0_rs1_class_d.sec };

   assign dd.i0rs2bype2[1:0] = {  i0_dp.alu & i0_rs2_depth_d[3:0] == 4'd5 & i0_rs2_class_d.sec,
                                  i0_dp.alu & i0_rs2_depth_d[3:0] == 4'd6 & i0_rs2_class_d.sec };

   assign dd.i1rs1bype2[1:0] = {  i1_dp.alu & i1_rs1_depth_d[3:0] == 4'd5 & i1_rs1_class_d.sec,
                                  i1_dp.alu & i1_rs1_depth_d[3:0] == 4'd6 & i1_rs1_class_d.sec };

   assign dd.i1rs2bype2[1:0] = {  i1_dp.alu & i1_rs2_depth_d[3:0] == 4'd5 & i1_rs2_class_d.sec,
                                  i1_dp.alu & i1_rs2_depth_d[3:0] == 4'd6 & i1_rs2_class_d.sec };


   assign i1_result_wb_eff[31:0] = (unfreeze_cycle1) ? i1_result_wb_freeze[31:0] :
                                   (unfreeze_cycle2) ? i1_result_e4_freeze[31:0] :
                                   i1_result_wb[31:0];

   assign i0_result_wb_eff[31:0] = (unfreeze_cycle1) ? i0_result_wb_freeze[31:0] :
                                   (unfreeze_cycle2) ? i0_result_e4_freeze[31:0] :
                                   i0_result_wb[31:0];


   assign i0_rs1_bypass_data_e2[31:0] = ({32{e2d.i0rs1bype2[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e2d.i0rs1bype2[0]}} & i0_result_wb_eff[31:0]);

   assign i0_rs2_bypass_data_e2[31:0] = ({32{e2d.i0rs2bype2[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e2d.i0rs2bype2[0]}} & i0_result_wb_eff[31:0]);

   assign i1_rs1_bypass_data_e2[31:0] = ({32{e2d.i1rs1bype2[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e2d.i1rs1bype2[0]}} & i0_result_wb_eff[31:0]);

   assign i1_rs2_bypass_data_e2[31:0] = ({32{e2d.i1rs2bype2[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e2d.i1rs2bype2[0]}} & i0_result_wb_eff[31:0]);


   assign dec_i0_rs1_bypass_en_e2 = |e2d.i0rs1bype2[1:0];
   assign dec_i0_rs2_bypass_en_e2 = |e2d.i0rs2bype2[1:0];
   assign dec_i1_rs1_bypass_en_e2 = |e2d.i1rs1bype2[1:0];
   assign dec_i1_rs2_bypass_en_e2 = |e2d.i1rs2bype2[1:0];


   assign i1_rs1_depend_i0_d = dec_i1_rs1_en_d & i0_dp.rd & (i1r.rs1[4:0] == i0r.rd[4:0]);
   assign i1_rs2_depend_i0_d = dec_i1_rs2_en_d & i0_dp.rd & (i1r.rs2[4:0] == i0r.rd[4:0]);


   assign dd.i0rs1bype3[3:0] = { i0_dp.alu & i0_rs1_depth_d[3:0]==4'd1 & (i0_rs1_class_d.sec | i0_rs1_class_d.load | i0_rs1_class_d.mul),
                                 i0_dp.alu & i0_rs1_depth_d[3:0]==4'd2 & (i0_rs1_class_d.sec | i0_rs1_class_d.load | i0_rs1_class_d.mul),
                                 i0_dp.alu & i0_rs1_depth_d[3:0]==4'd3 & (i0_rs1_class_d.sec | i0_rs1_class_d.load | i0_rs1_class_d.mul),
                                 i0_dp.alu & i0_rs1_depth_d[3:0]==4'd4 & (i0_rs1_class_d.sec | i0_rs1_class_d.load | i0_rs1_class_d.mul) };

   assign dd.i0rs2bype3[3:0] = { i0_dp.alu & i0_rs2_depth_d[3:0]==4'd1 & (i0_rs2_class_d.sec | i0_rs2_class_d.load | i0_rs2_class_d.mul),
                                 i0_dp.alu & i0_rs2_depth_d[3:0]==4'd2 & (i0_rs2_class_d.sec | i0_rs2_class_d.load | i0_rs2_class_d.mul),
                                 i0_dp.alu & i0_rs2_depth_d[3:0]==4'd3 & (i0_rs2_class_d.sec | i0_rs2_class_d.load | i0_rs2_class_d.mul),
                                 i0_dp.alu & i0_rs2_depth_d[3:0]==4'd4 & (i0_rs2_class_d.sec | i0_rs2_class_d.load | i0_rs2_class_d.mul) };


   assign i1rs1_intra[2:0] = {   i1_dp.alu & i0_dp.alu  & i1_rs1_depend_i0_d,
                                 i1_dp.alu & i0_dp.mul  & i1_rs1_depend_i0_d,
                                 i1_dp.alu & i0_dp.load & i1_rs1_depend_i0_d
                                 };

   assign i1rs2_intra[2:0] = {   i1_dp.alu & i0_dp.alu  & i1_rs2_depend_i0_d,
                                 i1_dp.alu & i0_dp.mul  & i1_rs2_depend_i0_d,
                                 i1_dp.alu & i0_dp.load & i1_rs2_depend_i0_d
                                 };

   assign i1_rs1_intra_bypass = |i1rs1_intra[2:0];

   assign i1_rs2_intra_bypass = |i1rs2_intra[2:0];


   assign dd.i1rs1bype3[6:0] = { i1rs1_intra[2:0],
                                 i1_dp.alu & i1_rs1_depth_d[3:0]==4'd1 & (i1_rs1_class_d.sec | i1_rs1_class_d.load | i1_rs1_class_d.mul) & ~i1_rs1_intra_bypass,
                                 i1_dp.alu & i1_rs1_depth_d[3:0]==4'd2 & (i1_rs1_class_d.sec | i1_rs1_class_d.load | i1_rs1_class_d.mul) & ~i1_rs1_intra_bypass,
                                 i1_dp.alu & i1_rs1_depth_d[3:0]==4'd3 & (i1_rs1_class_d.sec | i1_rs1_class_d.load | i1_rs1_class_d.mul) & ~i1_rs1_intra_bypass,
                                 i1_dp.alu & i1_rs1_depth_d[3:0]==4'd4 & (i1_rs1_class_d.sec | i1_rs1_class_d.load | i1_rs1_class_d.mul) & ~i1_rs1_intra_bypass };

   assign dd.i1rs2bype3[6:0] = { i1rs2_intra[2:0],
                                 i1_dp.alu & i1_rs2_depth_d[3:0]==4'd1 & (i1_rs2_class_d.sec | i1_rs2_class_d.load | i1_rs2_class_d.mul) & ~i1_rs2_intra_bypass,
                                 i1_dp.alu & i1_rs2_depth_d[3:0]==4'd2 & (i1_rs2_class_d.sec | i1_rs2_class_d.load | i1_rs2_class_d.mul) & ~i1_rs2_intra_bypass,
                                 i1_dp.alu & i1_rs2_depth_d[3:0]==4'd3 & (i1_rs2_class_d.sec | i1_rs2_class_d.load | i1_rs2_class_d.mul) & ~i1_rs2_intra_bypass,
                                 i1_dp.alu & i1_rs2_depth_d[3:0]==4'd4 & (i1_rs2_class_d.sec | i1_rs2_class_d.load | i1_rs2_class_d.mul) & ~i1_rs2_intra_bypass };


   assign dec_i0_rs1_bypass_en_e3 = |e3d.i0rs1bype3[3:0];
   assign dec_i0_rs2_bypass_en_e3 = |e3d.i0rs2bype3[3:0];
   assign dec_i1_rs1_bypass_en_e3 = |e3d.i1rs1bype3[6:0];
   assign dec_i1_rs2_bypass_en_e3 = |e3d.i1rs2bype3[6:0];


   assign i1_result_e4_eff[31:0] = (unfreeze_cycle1) ? i1_result_e4_freeze[31:0] :
                                   i1_result_e4_final[31:0];

   assign i0_result_e4_eff[31:0] = (unfreeze_cycle1) ? i0_result_e4_freeze[31:0] :
                                   i0_result_e4_final[31:0];


   assign i0_rs1_bypass_data_e3[31:0] = ({32{e3d.i0rs1bype3[3]}} & i1_result_e4_eff[31:0]) |
                                        ({32{e3d.i0rs1bype3[2]}} & i0_result_e4_eff[31:0]) |
                                        ({32{e3d.i0rs1bype3[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e3d.i0rs1bype3[0]}} & i0_result_wb_eff[31:0]);

   assign i0_rs2_bypass_data_e3[31:0] = ({32{e3d.i0rs2bype3[3]}} & i1_result_e4_eff[31:0]) |
                                        ({32{e3d.i0rs2bype3[2]}} & i0_result_e4_eff[31:0]) |
                                        ({32{e3d.i0rs2bype3[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e3d.i0rs2bype3[0]}} & i0_result_wb_eff[31:0]);

   assign i1_rs1_bypass_data_e3[31:0] = ({32{e3d.i1rs1bype3[6]}} & i0_result_e3[31:0]) |
                                        ({32{e3d.i1rs1bype3[5]}} & exu_mul_result_e3[31:0]) |
                                        ({32{e3d.i1rs1bype3[4]}} & lsu_result_dc3[31:0]) |
                                        ({32{e3d.i1rs1bype3[3]}} & i1_result_e4_eff[31:0]) |
                                        ({32{e3d.i1rs1bype3[2]}} & i0_result_e4_eff[31:0]) |
                                        ({32{e3d.i1rs1bype3[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e3d.i1rs1bype3[0]}} & i0_result_wb_eff[31:0]);


   assign i1_rs2_bypass_data_e3[31:0] = ({32{e3d.i1rs2bype3[6]}} & i0_result_e3[31:0]) |
                                        ({32{e3d.i1rs2bype3[5]}} & exu_mul_result_e3[31:0]) |
                                        ({32{e3d.i1rs2bype3[4]}} & lsu_result_dc3[31:0]) |
                                        ({32{e3d.i1rs2bype3[3]}} & i1_result_e4_eff[31:0]) |
                                        ({32{e3d.i1rs2bype3[2]}} & i0_result_e4_eff[31:0]) |
                                        ({32{e3d.i1rs2bype3[1]}} & i1_result_wb_eff[31:0]) |
                                        ({32{e3d.i1rs2bype3[0]}} & i0_result_wb_eff[31:0]);


   assign {i0_rs1_class_d, i0_rs1_depth_d[3:0]} =
                                                  (i0_rs1_depend_i1_e1) ? { i1_e1c, 4'd1 } :
                                                  (i0_rs1_depend_i0_e1) ? { i0_e1c, 4'd2 } :
                                                  (i0_rs1_depend_i1_e2) ? { i1_e2c, 4'd3 } :
                                                  (i0_rs1_depend_i0_e2) ? { i0_e2c, 4'd4 } :
                                                  (i0_rs1_depend_i1_e3) ? { i1_e3c, 4'd5 } :
                                                  (i0_rs1_depend_i0_e3) ? { i0_e3c, 4'd6 } :
                                                  (i0_rs1_depend_i1_e4) ? { i1_e4c, 4'd7 } :
                                                  (i0_rs1_depend_i0_e4) ? { i0_e4c, 4'd8 } :
                                                  (i0_rs1_depend_i1_wb) ? { i1_wbc, 4'd9 } :
                                                  (i0_rs1_depend_i0_wb) ? { i0_wbc, 4'd10 } : '0;

   assign {i0_rs2_class_d, i0_rs2_depth_d[3:0]} =
                                                  (i0_rs2_depend_i1_e1) ? { i1_e1c, 4'd1 } :
                                                  (i0_rs2_depend_i0_e1) ? { i0_e1c, 4'd2 } :
                                                  (i0_rs2_depend_i1_e2) ? { i1_e2c, 4'd3 } :
                                                  (i0_rs2_depend_i0_e2) ? { i0_e2c, 4'd4 } :
                                                  (i0_rs2_depend_i1_e3) ? { i1_e3c, 4'd5 } :
                                                  (i0_rs2_depend_i0_e3) ? { i0_e3c, 4'd6 } :
                                                  (i0_rs2_depend_i1_e4) ? { i1_e4c, 4'd7 } :
                                                  (i0_rs2_depend_i0_e4) ? { i0_e4c, 4'd8 } :
                                                  (i0_rs2_depend_i1_wb) ? { i1_wbc, 4'd9 } :
                                                  (i0_rs2_depend_i0_wb) ? { i0_wbc, 4'd10 } : '0;

   assign {i1_rs1_class_d, i1_rs1_depth_d[3:0]} =
                                                  (i1_rs1_depend_i1_e1) ? { i1_e1c, 4'd1 } :
                                                  (i1_rs1_depend_i0_e1) ? { i0_e1c, 4'd2 } :
                                                  (i1_rs1_depend_i1_e2) ? { i1_e2c, 4'd3 } :
                                                  (i1_rs1_depend_i0_e2) ? { i0_e2c, 4'd4 } :
                                                  (i1_rs1_depend_i1_e3) ? { i1_e3c, 4'd5 } :
                                                  (i1_rs1_depend_i0_e3) ? { i0_e3c, 4'd6 } :
                                                  (i1_rs1_depend_i1_e4) ? { i1_e4c, 4'd7 } :
                                                  (i1_rs1_depend_i0_e4) ? { i0_e4c, 4'd8 } :
                                                  (i1_rs1_depend_i1_wb) ? { i1_wbc, 4'd9 } :
                                                  (i1_rs1_depend_i0_wb) ? { i0_wbc, 4'd10 } : '0;

   assign {i1_rs2_class_d, i1_rs2_depth_d[3:0]} =
                                                  (i1_rs2_depend_i1_e1) ? { i1_e1c, 4'd1 } :
                                                  (i1_rs2_depend_i0_e1) ? { i0_e1c, 4'd2 } :
                                                  (i1_rs2_depend_i1_e2) ? { i1_e2c, 4'd3 } :
                                                  (i1_rs2_depend_i0_e2) ? { i0_e2c, 4'd4 } :
                                                  (i1_rs2_depend_i1_e3) ? { i1_e3c, 4'd5 } :
                                                  (i1_rs2_depend_i0_e3) ? { i0_e3c, 4'd6 } :
                                                  (i1_rs2_depend_i1_e4) ? { i1_e4c, 4'd7 } :
                                                  (i1_rs2_depend_i0_e4) ? { i0_e4c, 4'd8 } :
                                                  (i1_rs2_depend_i1_wb) ? { i1_wbc, 4'd9 } :
                                                  (i1_rs2_depend_i0_wb) ? { i0_wbc, 4'd10 } : '0;


   assign i0_rs1_match_e1 = (i0_rs1_depth_d[3:0] == 4'd1 |
                             i0_rs1_depth_d[3:0] == 4'd2);

   assign i0_rs1_match_e2 = (i0_rs1_depth_d[3:0] == 4'd3 |
                             i0_rs1_depth_d[3:0] == 4'd4);

   assign i0_rs1_match_e3 = (i0_rs1_depth_d[3:0] == 4'd5 |
                             i0_rs1_depth_d[3:0] == 4'd6);

   assign i0_rs2_match_e1 = (i0_rs2_depth_d[3:0] == 4'd1 |
                             i0_rs2_depth_d[3:0] == 4'd2);

   assign i0_rs2_match_e2 = (i0_rs2_depth_d[3:0] == 4'd3 |
                             i0_rs2_depth_d[3:0] == 4'd4);

   assign i0_rs2_match_e3 = (i0_rs2_depth_d[3:0] == 4'd5 |
                             i0_rs2_depth_d[3:0] == 4'd6);

   assign i0_rs1_match_e1_e2 = i0_rs1_match_e1 | i0_rs1_match_e2;
   assign i0_rs1_match_e1_e3 = i0_rs1_match_e1 | i0_rs1_match_e2 | i0_rs1_match_e3;

   assign i0_rs2_match_e1_e2 = i0_rs2_match_e1 | i0_rs2_match_e2;
   assign i0_rs2_match_e1_e3 = i0_rs2_match_e1 | i0_rs2_match_e2 | i0_rs2_match_e3;


   assign i0_secondary_d = ((i0_dp.alu & (i0_rs1_class_d.load | i0_rs1_class_d.mul) & i0_rs1_match_e1_e2) |
                            (i0_dp.alu & (i0_rs2_class_d.load | i0_rs2_class_d.mul) & i0_rs2_match_e1_e2) |
                            (i0_dp.alu & i0_rs1_class_d.sec & i0_rs1_match_e1_e3) |
                            (i0_dp.alu & i0_rs2_class_d.sec & i0_rs2_match_e1_e3)) & ~disable_secondary;


   assign i0_secondary_stall_d = ((i0_dp.alu & i1_rs1_depend_i0_d & ~i1_dp.alu & i0_secondary_d) |
                                  (i0_dp.alu & i1_rs2_depend_i0_d & ~i1_dp.alu & ~i1_dp.store & i0_secondary_d)) & ~disable_secondary;


   assign i1_rs1_match_e1 = (i1_rs1_depth_d[3:0] == 4'd1 |
                             i1_rs1_depth_d[3:0] == 4'd2);

   assign i1_rs1_match_e2 = (i1_rs1_depth_d[3:0] == 4'd3 |
                             i1_rs1_depth_d[3:0] == 4'd4);

   assign i1_rs1_match_e3 = (i1_rs1_depth_d[3:0] == 4'd5 |
                             i1_rs1_depth_d[3:0] == 4'd6);

   assign i1_rs2_match_e1 = (i1_rs2_depth_d[3:0] == 4'd1 |
                             i1_rs2_depth_d[3:0] == 4'd2);

   assign i1_rs2_match_e2 = (i1_rs2_depth_d[3:0] == 4'd3 |
                             i1_rs2_depth_d[3:0] == 4'd4);

   assign i1_rs2_match_e3 = (i1_rs2_depth_d[3:0] == 4'd5 |
                             i1_rs2_depth_d[3:0] == 4'd6);

   assign i1_rs1_match_e1_e2 = i1_rs1_match_e1 | i1_rs1_match_e2;
   assign i1_rs1_match_e1_e3 = i1_rs1_match_e1 | i1_rs1_match_e2 | i1_rs1_match_e3;

   assign i1_rs2_match_e1_e2 = i1_rs2_match_e1 | i1_rs2_match_e2;
   assign i1_rs2_match_e1_e3 = i1_rs2_match_e1 | i1_rs2_match_e2 | i1_rs2_match_e3;


   assign i1_secondary_d = ((i1_dp.alu & (i1_rs1_class_d.load | i1_rs1_class_d.mul) & i1_rs1_match_e1_e2) |
                            (i1_dp.alu & (i1_rs2_class_d.load | i1_rs2_class_d.mul) & i1_rs2_match_e1_e2) |
                            (i1_dp.alu & (i1_rs1_class_d.sec) & i1_rs1_match_e1_e3) |
                            (i1_dp.alu & (i1_rs2_class_d.sec) & i1_rs2_match_e1_e3) |
                            (non_block_case_d & i1_depend_i0_d)) & ~disable_secondary;


   assign store_data_bypass_i0_e2_c2 = i0_dp.alu & ~i0_secondary_d & i1_rs2_depend_i0_d & ~i1_rs1_depend_i0_d & i1_dp.store;

   assign non_block_case_d = (
                                (i1_dp.alu & i0_dp.load) |
                                (i1_dp.alu & i0_dp.mul)
                                ) & ~disable_secondary;


   assign store_data_bypass_c2 =  ((             i0_dp.store & i0_rs2_depth_d[3:0] == 4'd1 & i0_rs2_class_d.load) |
                              (             i0_dp.store & i0_rs2_depth_d[3:0] == 4'd2 & i0_rs2_class_d.load) |
                              (~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd1 & i1_rs2_class_d.load) |
                              (~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd2 & i1_rs2_class_d.load));

   assign store_data_bypass_c1 =  ((             i0_dp.store & i0_rs2_depth_d[3:0] == 4'd3 & i0_rs2_class_d.load) |
                              (             i0_dp.store & i0_rs2_depth_d[3:0] == 4'd4 & i0_rs2_class_d.load) |
                              (~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd3 & i1_rs2_class_d.load) |
                              (~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd4 & i1_rs2_class_d.load));

   assign load_ldst_bypass_c1 =  ((         (i0_dp.load | i0_dp.store) & i0_rs1_depth_d[3:0] == 4'd3 & i0_rs1_class_d.load) |
                              (             (i0_dp.load | i0_dp.store) & i0_rs1_depth_d[3:0] == 4'd4 & i0_rs1_class_d.load) |
                              (~i0_dp.lsu & (i1_dp.load | i1_dp.store) & i1_rs1_depth_d[3:0] == 4'd3 & i1_rs1_class_d.load) |
                              (~i0_dp.lsu & (i1_dp.load | i1_dp.store) & i1_rs1_depth_d[3:0] == 4'd4 & i1_rs1_class_d.load));

   assign load_mul_rs1_bypass_e1 =  ((             (i0_dp.mul) & i0_rs1_depth_d[3:0] == 4'd3 & i0_rs1_class_d.load) |
                                     (             (i0_dp.mul) & i0_rs1_depth_d[3:0] == 4'd4 & i0_rs1_class_d.load) |
                                     (~i0_dp.mul & (i1_dp.mul) & i1_rs1_depth_d[3:0] == 4'd3 & i1_rs1_class_d.load) |
                                     (~i0_dp.mul & (i1_dp.mul) & i1_rs1_depth_d[3:0] == 4'd4 & i1_rs1_class_d.load));

   assign load_mul_rs2_bypass_e1 =  ((             (i0_dp.mul) & i0_rs2_depth_d[3:0] == 4'd3 & i0_rs2_class_d.load) |
                                     (             (i0_dp.mul) & i0_rs2_depth_d[3:0] == 4'd4 & i0_rs2_class_d.load) |
                                     (~i0_dp.mul & (i1_dp.mul) & i1_rs2_depth_d[3:0] == 4'd3 & i1_rs2_class_d.load) |
                                     (~i0_dp.mul & (i1_dp.mul) & i1_rs2_depth_d[3:0] == 4'd4 & i1_rs2_class_d.load));


   assign store_data_bypass_e4_c3[1:0] = {
                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd1 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd1 & i0_rs2_class_d.sec ),

                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd2 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd2 & i0_rs2_class_d.sec )
                                     };

   assign store_data_bypass_e4_c2[1:0] = {
                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd3 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd3 & i0_rs2_class_d.sec ),

                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd4 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd4 & i0_rs2_class_d.sec )
                                     };


   assign store_data_bypass_e4_c1[1:0] = {
                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd5 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd5 & i0_rs2_class_d.sec ),

                                      ( ~i0_dp.lsu & i1_dp.store & i1_rs2_depth_d[3:0] == 4'd6 & i1_rs2_class_d.sec ) |
                                      (              i0_dp.store & i0_rs2_depth_d[3:0] == 4'd6 & i0_rs2_class_d.sec )
                                     };


   assign i0_not_alu_eff = (~i0_dp.alu | disable_secondary);
   assign i1_not_alu_eff = (~i1_dp.alu | disable_secondary);


   assign i0_load_block_d = (i0_not_alu_eff & i0_rs1_class_d.load & i0_rs1_match_e1) |
                            (i0_not_alu_eff & i0_rs1_class_d.load & i0_rs1_match_e2 & ~i0_dp.load & ~i0_dp.store & ~i0_dp.mul) |
                            (i0_not_alu_eff & i0_rs2_class_d.load & i0_rs2_match_e1 & ~i0_dp.store) |
                            (i0_not_alu_eff & i0_rs2_class_d.load & i0_rs2_match_e2 & ~i0_dp.store & ~i0_dp.mul);

   assign i1_load_block_d = (i1_not_alu_eff & i1_rs1_class_d.load & i1_rs1_match_e1) |
                            (i1_not_alu_eff & i1_rs1_class_d.load & i1_rs1_match_e2 & ~i1_dp.load & ~i1_dp.store & ~i1_dp.mul) |
                            (i1_not_alu_eff & i1_rs2_class_d.load & i1_rs2_match_e1 & ~i1_dp.store) |
                            (i1_not_alu_eff & i1_rs2_class_d.load & i1_rs2_match_e2 & ~i1_dp.store & ~i1_dp.mul);

   assign i0_mul_block_d = (i0_not_alu_eff & i0_rs1_class_d.mul & i0_rs1_match_e1_e2) |
                           (i0_not_alu_eff & i0_rs2_class_d.mul & i0_rs2_match_e1_e2);

   assign i1_mul_block_d = (i1_not_alu_eff & i1_rs1_class_d.mul & i1_rs1_match_e1_e2) |
                           (i1_not_alu_eff & i1_rs2_class_d.mul & i1_rs2_match_e1_e2);

   assign i0_secondary_block_d = ((~i0_dp.alu & i0_rs1_class_d.sec & i0_rs1_match_e1_e3) |
                                  (~i0_dp.alu & i0_rs2_class_d.sec & i0_rs2_match_e1_e3 & ~i0_dp.store)) & ~disable_secondary;

   assign i1_secondary_block_d = ((~i1_dp.alu & i1_rs1_class_d.sec & i1_rs1_match_e1_e3) |
                                  (~i1_dp.alu & i1_rs2_class_d.sec & i1_rs2_match_e1_e3 & ~i1_dp.store) & ~disable_secondary);


   assign dec_div_decode_e4 = e4d.i0div;


   assign dec_tlu_i0_valid_e4 = (e4d.i0valid & ~e4d.i0div & ~e4d.i0fpu & ~flush_lower_wb) |
                                exu_div_finish | fpu_resp_valid;
   assign dec_tlu_i1_valid_e4 = e4d.i1valid & ~flush_lower_wb;


   assign dt.legal     =  i0_legal_decode_d                ;
   assign dt.icaf      =  i0_icaf_d & i0_legal_decode_d;
   assign dt.icaf_second   =  dec_i0_icaf_second_d & i0_legal_decode_d;
   assign dt.perr      =   dec_i0_perr_d & i0_legal_decode_d;
   assign dt.sbecc     =   dec_i0_sbecc_d & i0_legal_decode_d;
   assign dt.fence_i   = (i0_dp.fence_i | debug_fence_i) & i0_legal_decode_d;


   assign dt.pmu_i0_itype = i0_itype;
   assign dt.pmu_i1_itype = i1_itype;
   assign dt.pmu_i0_br_unpred = i0_br_unpred;
   assign dt.pmu_i1_br_unpred = i1_br_unpred;
   assign dt.pmu_divide = 1'b0;
   assign dt.pmu_lsu_misaligned = 1'b0;

   assign dt.i0trigger[3:0] = dec_i0_trigger_match_d[3:0] &
                              {4{dec_i0_decode_d & ~i0_div_decode_d & ~i0_fpu_decode_d}};
   assign dt.i1trigger[3:0] = dec_i1_trigger_match_d[3:0] & {4{dec_i1_decode_d}};


   rvdffe #( $bits(trap_pkt_t) ) trap_e1ff (.*, .en(i0_e1_ctl_en), .din( dt),  .dout(e1t));

   always_comb begin
      e1t_in = e1t;
      e1t_in.i0trigger[3:0] = e1t.i0trigger & ~{4{flush_final_e3}};
      e1t_in.i1trigger[3:0] = e1t.i1trigger & ~{4{flush_final_e3}};
   end

   rvdffe #( $bits(trap_pkt_t) ) trap_e2ff (.*, .en(i0_e2_ctl_en), .din(e1t_in),  .dout(e2t));

   always_comb begin
      e2t_in = e2t;
      e2t_in.i0trigger[3:0] = e2t.i0trigger & ~{4{flush_final_e3 | flush_lower_wb}};
      e2t_in.i1trigger[3:0] = e2t.i1trigger & ~{4{flush_final_e3 | flush_lower_wb}};
   end

   rvdffe  #($bits(trap_pkt_t) ) trap_e3ff (.*, .en(i0_e3_ctl_en), .din(e2t_in),  .dout(e3t));


    always_comb begin
      e3t_in = e3t;

       e3t_in.i0trigger[3:0] = ({4{(e3d.i0load | e3d.i0store)}} & lsu_trigger_match_dc3[3:0]) | e3t.i0trigger[3:0];
       e3t_in.i1trigger[3:0] = ~{4{i0_flush_final_e3}} & (({4{~(e3d.i0load | e3d.i0store)}} & lsu_trigger_match_dc3[3:0]) | e3t.i1trigger[3:0]);

       e3t_in.pmu_lsu_misaligned = lsu_pmu_misaligned_dc3;

      if (freeze | flush_lower_wb) e3t_in = '0 ;
   end


   rvdffe #( $bits(trap_pkt_t) ) trap_e4ff (.*, .en(i0_e4_ctl_en), .din(e3t_in),  .dout(e4t));


   assign freeze_e3 = freeze & ~freeze_before;

   rvdff #(1) freeze_before_ff (.*, .clk(active_clk), .din(freeze), .dout(freeze_before));

   rvdff #(1) freeze_e4_ff     (.*, .clk(active_clk), .din(freeze_e3), .dout(freeze_e4));


   rvdffe #(9) e4_trigger_ff   (.*, .en(freeze_e3), .din({e3d.i0load,e3t.i0trigger[3:0],e3t.i1trigger[3:0]}), .dout({e4d_i0load,e4t_i0trigger[3:0],e4t_i1trigger[3:0]}));

   always_comb begin

      if (exu_div_finish | fpu_resp_valid)
        dec_tlu_packet_e4 = '0;
      else
        dec_tlu_packet_e4 = e4t;

      dec_tlu_packet_e4.legal = e4t.legal | exu_div_finish | fpu_resp_valid;
      dec_tlu_packet_e4.i0trigger[3:0] = exu_div_finish ? div_trigger[3:0] :
                                                  fpu_resp_valid ? fpu_trigger[3:0] : e4t.i0trigger[3:0];

      dec_tlu_packet_e4.pmu_divide = exu_div_finish;

      if (freeze_e4) begin
         dec_tlu_packet_e4.i0trigger[3:0] = e4t_i0trigger[3:0];
         dec_tlu_packet_e4.i1trigger[3:0] = e4t_i1trigger[3:0];
      end

   end

   assign dec_i0_load_e4 = e4d_i0load;


   assign i0_dc.mul   = i0_dp.mul & i0_legal_decode_d;
   assign i0_dc.load  = i0_dp.load & i0_legal_decode_d;
   assign i0_dc.sec = i0_dp.alu &  i0_secondary_d & i0_legal_decode_d;
   assign i0_dc.alu = i0_dp.alu & ~i0_secondary_d & i0_legal_decode_d;

   rvdffs #( $bits(class_pkt_t) ) i0_e1c_ff (.*, .en(i0_e1_ctl_en), .clk(active_clk), .din(i0_dc),   .dout(i0_e1c));
   rvdffs #( $bits(class_pkt_t) ) i0_e2c_ff (.*, .en(i0_e2_ctl_en), .clk(active_clk), .din(i0_e1c),  .dout(i0_e2c));
   rvdffs #( $bits(class_pkt_t) ) i0_e3c_ff (.*, .en(i0_e3_ctl_en), .clk(active_clk), .din(i0_e2c),  .dout(i0_e3c));

   assign i0_e4c_in = (freeze) ? '0 : i0_e3c;

   rvdffs  #( $bits(class_pkt_t) ) i0_e4c_ff (.*, .en(i0_e4_ctl_en),              .clk(active_clk), .din(i0_e4c_in), .dout(i0_e4c));

   rvdffs  #( $bits(class_pkt_t) ) i0_wbc_ff (.*, .en(i0_wb_ctl_en),              .clk(active_clk), .din(i0_e4c),    .dout(i0_wbc));


   assign i1_dc.mul   = i1_dp.mul & dec_i1_decode_d;
   assign i1_dc.load  = i1_dp.load & dec_i1_decode_d;
   assign i1_dc.sec = i1_dp.alu &  i1_secondary_d & dec_i1_decode_d;
   assign i1_dc.alu = i1_dp.alu & ~i1_secondary_d & dec_i1_decode_d;

   rvdffs #( $bits(class_pkt_t) ) i1_e1c_ff (.*, .en(i0_e1_ctl_en), .clk(active_clk), .din(i1_dc),   .dout(i1_e1c));
   rvdffs #( $bits(class_pkt_t) ) i1_e2c_ff (.*, .en(i0_e2_ctl_en), .clk(active_clk), .din(i1_e1c),  .dout(i1_e2c));
   rvdffs #( $bits(class_pkt_t) ) i1_e3c_ff (.*, .en(i0_e3_ctl_en), .clk(active_clk), .din(i1_e2c),  .dout(i1_e3c));

   assign i1_e4c_in = (freeze) ? '0 : i1_e3c;

   rvdffs #( $bits(class_pkt_t) ) i1_e4c_ff (.*, .en(i0_e4_ctl_en), .clk(active_clk), .din(i1_e4c_in), .dout(i1_e4c));

   rvdffs #( $bits(class_pkt_t) ) i1_wbc_ff (.*, .en(i0_wb_ctl_en), .clk(active_clk), .din(i1_e4c),    .dout(i1_wbc));


   assign dd.i0rd[4:0] = i0r.rd[4:0];
   assign dd.i0v = i0_rd_en_d & i0_legal_decode_d;
   assign dd.i0valid =              dec_i0_decode_d;

   assign dd.i0mul = i0_dp.mul & i0_legal_decode_d;
   assign dd.i0load = i0_dp.load & i0_legal_decode_d;
   assign dd.i0store = i0_dp.store & i0_legal_decode_d;
   assign dd.i0div = i0_dp.div & i0_legal_decode_d;
   assign dd.i0fpu = i0_dp.fpu & i0_legal_decode_d;
   assign dd.i0secondary = i0_secondary_d & i0_legal_decode_d;


   assign dd.i1rd[4:0] = i1r.rd[4:0];
   assign dd.i1v = i1_rd_en_d & dec_i1_decode_d;
   assign dd.i1valid =              dec_i1_decode_d;
   assign dd.i1mul = i1_dp.mul;
   assign dd.i1load = i1_dp.load;
   assign dd.i1store = i1_dp.store;
   assign dd.i1secondary = i1_secondary_d & dec_i1_decode_d;

   assign dd.csrwen = dec_csr_wen_unq_d & i0_legal_decode_d;
   assign dd.csrwonly = i0_csr_write_only_d & dec_i0_decode_d;
   assign dd.csrwaddr[11:0] = i0[31:20];


   assign i0_pipe_en[5] = dec_i0_decode_d;

   rvdffs #(3) i0cg0ff (.*, .clk(active_clk), .en(~freeze), .din(i0_pipe_en[5:3]), .dout(i0_pipe_en[4:2]));
   rvdff  #(2) i0cg1ff (.*, .clk(active_clk),               .din(i0_pipe_en[2:1]), .dout(i0_pipe_en[1:0]));


   assign i0_e1_ctl_en = (|i0_pipe_en[5:4] | clk_override) & ~freeze;
   assign i0_e2_ctl_en = (|i0_pipe_en[4:3] | clk_override) & ~freeze;
   assign i0_e3_ctl_en = (|i0_pipe_en[3:2] | clk_override) & ~freeze;
   assign i0_e4_ctl_en = (|i0_pipe_en[2:1] | clk_override);
   assign i0_wb_ctl_en = (|i0_pipe_en[1:0] | clk_override);

   assign i0_e1_data_en = (i0_pipe_en[5] | clk_override) & ~freeze;
   assign i0_e2_data_en = (i0_pipe_en[4] | clk_override) & ~freeze;
   assign i0_e3_data_en = (i0_pipe_en[3] | clk_override) & ~freeze;
   assign i0_e4_data_en = (i0_pipe_en[2] | clk_override);
   assign i0_wb_data_en = (i0_pipe_en[1] | clk_override);
   assign i0_wb1_data_en = (i0_pipe_en[0] | clk_override);

   assign dec_i0_data_en[4:2] = {i0_e1_data_en, i0_e2_data_en, i0_e3_data_en};
   assign dec_i0_ctl_en[4:1]  = {i0_e1_ctl_en, i0_e2_ctl_en, i0_e3_ctl_en, i0_e4_ctl_en};


   assign i1_pipe_en[5] = dec_i1_decode_d;

   rvdffs #(3) i1cg0ff (.*, .clk(free_clk), .en(~freeze), .din(i1_pipe_en[5:3]), .dout(i1_pipe_en[4:2]));
   rvdff  #(2) i1cg1ff (.*, .clk(free_clk),               .din(i1_pipe_en[2:1]), .dout(i1_pipe_en[1:0]));


   assign i1_e1_ctl_en = (|i1_pipe_en[5:4] | clk_override) & ~freeze;
   assign i1_e2_ctl_en = (|i1_pipe_en[4:3] | clk_override) & ~freeze;
   assign i1_e3_ctl_en = (|i1_pipe_en[3:2] | clk_override) & ~freeze;
   assign i1_e4_ctl_en = (|i1_pipe_en[2:1] | clk_override);
   assign i1_wb_ctl_en = (|i1_pipe_en[1:0] | clk_override);

   assign i1_e1_data_en = (i1_pipe_en[5] | clk_override) & ~freeze;
   assign i1_e2_data_en = (i1_pipe_en[4] | clk_override) & ~freeze;
   assign i1_e3_data_en = (i1_pipe_en[3] | clk_override) & ~freeze;
   assign i1_e4_data_en = (i1_pipe_en[2] | clk_override);
   assign i1_wb_data_en = (i1_pipe_en[1] | clk_override);
   assign i1_wb1_data_en = (i1_pipe_en[0] | clk_override);

   assign dec_i1_data_en[4:2] = {i1_e1_data_en, i1_e2_data_en, i1_e3_data_en};
   assign dec_i1_ctl_en[4:1]  = {i1_e1_ctl_en, i1_e2_ctl_en, i1_e3_ctl_en, i1_e4_ctl_en};

   rvdffe #( $bits(dest_pkt_t) ) e1ff (.*, .en(i0_e1_ctl_en), .din(dd),  .dout(e1d));

   always_comb begin
      e1d_in = e1d;

      e1d_in.i0v = e1d.i0v & ~flush_final_e3;
      e1d_in.i1v = e1d.i1v & ~flush_final_e3;
      e1d_in.i0valid = e1d.i0valid & ~flush_final_e3;
      e1d_in.i1valid = e1d.i1valid & ~flush_final_e3;
      e1d_in.i0secondary = e1d.i0secondary & ~flush_final_e3;
      e1d_in.i1secondary = e1d.i1secondary & ~flush_final_e3;
   end

   assign dec_i1_valid_e1 = e1d.i1valid;


   rvdffe #( $bits(dest_pkt_t) ) e2ff (.*, .en(i0_e2_ctl_en), .din(e1d_in), .dout(e2d));

   always_comb begin
      e2d_in = e2d;

      e2d_in.i0v = e2d.i0v &         ~flush_final_e3 & ~flush_lower_wb;
      e2d_in.i1v = e2d.i1v &         ~flush_final_e3 & ~flush_lower_wb;
      e2d_in.i0valid = e2d.i0valid & ~flush_final_e3 & ~flush_lower_wb;
      e2d_in.i1valid = e2d.i1valid & ~flush_final_e3 & ~flush_lower_wb;
      e2d_in.i0secondary = e2d.i0secondary & ~flush_final_e3 & ~flush_lower_wb;
      e2d_in.i1secondary = e2d.i1secondary & ~flush_final_e3 & ~flush_lower_wb;
   end

   rvdffe #( $bits(dest_pkt_t) ) e3ff (.*, .en(i0_e3_ctl_en), .din(e2d_in), .dout(e3d));

   always_comb begin
      e3d_in = e3d;

      e3d_in.i0v = e3d.i0v                              & ~flush_lower_wb;
      e3d_in.i0valid = e3d.i0valid                      & ~flush_lower_wb;

      e3d_in.i0secondary = e3d.i0secondary & ~flush_lower_wb;

      e3d_in.i1v = e3d.i1v         & ~i0_flush_final_e3 & ~flush_lower_wb;
      e3d_in.i1valid = e3d.i1valid & ~i0_flush_final_e3 & ~flush_lower_wb;

      e3d_in.i1secondary = e3d.i1secondary & ~i0_flush_final_e3 & ~flush_lower_wb;

      if (freeze) e3d_in = '0;

   end


   assign dec_i0_sec_decode_e3 = e3d.i0secondary & ~flush_lower_wb & ~freeze;
   assign dec_i1_sec_decode_e3 = e3d.i1secondary & ~i0_flush_final_e3 & ~flush_lower_wb & ~freeze;


   rvdffe #( $bits(dest_pkt_t) ) e4ff (.*, .en(i0_e4_ctl_en), .din(e3d_in), .dout(e4d));

   always_comb begin

      if (exu_div_finish | fpu_resp_valid)
        e4d_in = '0;
      else
        e4d_in = e4d;


      e4d_in.i0rd[4:0] = exu_div_finish ? div_waddr_wb[4:0] :
                         fpu_resp_valid ? fpu_rd[4:0] : e4d.i0rd[4:0];

      e4d_in.i0v = (e4d.i0v & ~e4d.i0div & ~e4d.i0fpu & ~flush_lower_wb) |
                   (exu_div_finish & (div_waddr_wb != 5'b0)) |
                   (fpu_resp_valid & fpu_writes_gpr & (fpu_rd != 5'b0));
      e4d_in.i0valid = (e4d.i0valid & ~e4d.i0fpu & ~flush_lower_wb) |
                       exu_div_finish | fpu_resp_valid;

      e4d_in.i0secondary = e4d.i0secondary & ~flush_lower_wb & ~exu_div_finish & ~fpu_resp_valid;
      e4d_in.i0load = e4d.i0load & ~flush_lower_wb & ~exu_div_finish & ~fpu_resp_valid;
      e4d_in.i0store = e4d.i0store & ~flush_lower_wb & ~exu_div_finish & ~fpu_resp_valid;

      e4d_in.i1v = e4d.i1v         & ~flush_lower_wb;
      e4d_in.i1valid = e4d.i1valid & ~flush_lower_wb;
      e4d_in.i1secondary = e3d.i1secondary & ~flush_lower_wb;

   end


   rvdffe #( $bits(dest_pkt_t) ) wbff (.*, .en(i0_wb_ctl_en | exu_div_finish | div_wen_wb |
                                              fpu_resp_valid | fpu_wen_wb), .din(e4d_in), .dout(wbd));

   assign dec_i0_waddr_wb[4:0] = wbd.i0rd[4:0];


   assign     i0_wen_wb = wbd.i0v & ~(~dec_tlu_i1_kill_writeb_wb & ~i1_load_kill_wen & wbd.i0v & wbd.i1v & (wbd.i0rd[4:0] == wbd.i1rd[4:0])) & ~dec_tlu_i0_kill_writeb_wb;
   assign dec_i0_wen_wb = i0_wen_wb & ~i0_load_kill_wen;

   assign dec_i0_wdata_wb[31:0] = i0_result_wb[31:0];

   assign dec_i1_waddr_wb[4:0] = wbd.i1rd[4:0];

   assign     i1_wen_wb = wbd.i1v & ~dec_tlu_i1_kill_writeb_wb;
   assign dec_i1_wen_wb = i1_wen_wb & ~i1_load_kill_wen;

   assign dec_i1_wdata_wb[31:0] = i1_result_wb[31:0];


   assign div_stall = exu_div_stall | div_stall_ff;

   rvdff  #(1) divstallff (.*, .clk(active_clk), .din(exu_div_stall), .dout(div_stall_ff));


   assign i0_div_decode_d = i0_legal_decode_d & i0_dp.div;

   rvdffe #(31) divpcff (.*, .en(i0_div_decode_d), .din(dec_i0_pc_d[31:1]), .dout(div_pc[31:1]));

   rvdffs #(4) divtriggerff (.*, .en(i0_div_decode_d), .clk(active_clk), .din(dec_i0_trigger_match_d[3:0]), .dout(div_trigger[3:0]));

   rvdffs #(5) divwbaddrff (.*, .en(i0_div_decode_d), .clk(active_clk), .din(i0r.rd[4:0]), .dout(div_waddr_wb[4:0]));


   rvdff  #(1) divwbff (.*, .clk(active_clk), .din(exu_div_finish), .dout(div_wen_wb));


   assign i0_fpu_decode_d = i0_legal_decode_d & i0_dp.fpu;
   assign fpu_int_rs1_d = dec_i0_rs1_bypass_en_d ? i0_rs1_bypass_data_d : gpr_i0_rs1_d;

   mycpu_fpr_ctl fpr_ctl (
      .clk(clk), .rst_l(rst_l),
      .raddr1(i0[19:15]), .raddr2(i0[24:20]), .raddr3(i0[31:27]),
      .rdata1(fpr_rs1_d), .rdata2(fpr_rs2_d), .rdata3(fpr_rs3_d),
      .wen(fpr_wen), .waddr(fpr_waddr), .wdata(fpr_wdata)
   );

   mycpu_fpu fpu (
      .clk(clk), .rst_l(rst_l),
      .flush_i(flush_final_e3 | flush_lower_wb),
      .req_valid_i(i0_fpu_decode_d), .req_ready_o(fpu_req_ready),
      .inst_i(i0), .int_rs1_i(fpu_int_rs1_d),
      .frs1_i(fpr_rs1_d), .frs2_i(fpr_rs2_d), .frs3_i(fpr_rs3_d),
      .frm_i(dec_tlu_frm),
      .resp_valid_o(fpu_resp_valid), .result_o(fpu_result), .flags_o(fpu_flags),
      .writes_gpr_o(fpu_writes_gpr), .writes_fpr_o(fpu_writes_fpr),
      .rd_o(fpu_rd), .busy_o(fpu_busy)
   );

   assign fpu_stall = fpu_busy | fpu_stall_ff;
   rvdff #(1) fpustallff (.*, .clk(active_clk), .din(fpu_busy), .dout(fpu_stall_ff));

   rvdffe #(31) fpupcff (.*, .en(i0_fpu_decode_d), .din(dec_i0_pc_d[31:1]), .dout(fpu_pc[31:1]));
   rvdffe #(32) fpuinstff (.*, .en(i0_fpu_decode_d), .din(i0_inst_d), .dout(fpu_inst));
   rvdffs #(4) fputriggerff (.*, .en(i0_fpu_decode_d), .clk(active_clk),
                             .din(dec_i0_trigger_match_d), .dout(fpu_trigger));

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         fpu_result_hold <= 32'b0;
         fpu_rd_hold <= 5'b0;
         fpu_writes_fpr_hold <= 1'b0;
         dec_fpu_fflags <= 5'b0;
      end else if (fpu_resp_valid) begin
         fpu_result_hold <= fpu_result;
         fpu_rd_hold <= fpu_rd;
         fpu_writes_fpr_hold <= fpu_writes_fpr;
         dec_fpu_fflags <= fpu_flags;
      end
   end

   rvdff #(1) fpuwbff (.*, .clk(active_clk), .din(fpu_resp_valid), .dout(fpu_wen_wb));

   assign fpload_wen_wb = wbd.i0valid && (i0_inst_wb[6:0] == 7'b0000111) &&
                           (i0_inst_wb[14:12] == 3'b010) && !dec_tlu_i0_kill_writeb_wb;
   assign fpload_waddr_wb = i0_inst_wb[11:7];
   assign fpr_wen = (fpu_wen_wb && fpu_writes_fpr_hold && !dec_tlu_i0_kill_writeb_wb) |
                    fpload_wen_wb;
   assign fpr_waddr = (fpu_wen_wb && fpu_writes_fpr_hold) ? fpu_rd_hold : fpload_waddr_wb;
   assign fpr_wdata = (fpu_wen_wb && fpu_writes_fpr_hold) ? fpu_result_hold : i0_result_wb;
   assign dec_fpu_fflags_valid = fpu_wen_wb && !dec_tlu_i0_kill_writeb_wb;
   assign dec_fpu_dirty = fpr_wen | dec_fpu_fflags_valid;

   assign dec_i0_fstore_d = i0_legal_decode_d && i0_dp.fpstore;
   assign dec_fpr_rs2_d = fpr_rs2_d;


   assign i0_result_e1[31:0] = exu_i0_result_e1[31:0];
   assign i1_result_e1[31:0] = exu_i1_result_e1[31:0];


   rvdffe #(32) i0e2resultff (.*, .en(i0_e2_data_en), .din(i0_result_e1[31:0]), .dout(i0_result_e2[31:0]));
   rvdffe #(32) i1e2resultff (.*, .en(i1_e2_data_en), .din(i1_result_e1[31:0]), .dout(i1_result_e2[31:0]));

   rvdffe #(32) i0e3resultff (.*, .en(i0_e3_data_en), .din(i0_result_e2[31:0]), .dout(i0_result_e3[31:0]));
   rvdffe #(32) i1e3resultff (.*, .en(i1_e3_data_en), .din(i1_result_e2[31:0]), .dout(i1_result_e3[31:0]));


   assign i0_result_e3_final[31:0] = ((e3d.i0v | fload_e3) & e3d.i0load) ? lsu_result_dc3[31:0] : (e3d.i0v & e3d.i0mul) ? exu_mul_result_e3[31:0] : i0_result_e3[31:0];

   assign i1_result_e3_final[31:0] = (e3d.i1v & e3d.i1load) ? lsu_result_dc3[31:0] : (e3d.i1v & e3d.i1mul) ? exu_mul_result_e3[31:0] : i1_result_e3[31:0];


   rvdffe #(32) i0e4resultff (.*, .en(i0_e4_data_en), .din(i0_result_e3_final[31:0]), .dout(i0_result_e4[31:0]));
   rvdffe #(32) i1e4resultff (.*, .en(i1_e4_data_en), .din(i1_result_e3_final[31:0]), .dout(i1_result_e4[31:0]));

   assign i0_result_e4_final[31:0] =
                                     (          e4d.i0secondary) ? exu_i0_result_e4[31:0] : ((e4d.i0v | fload_e4) & e4d.i0load) ? lsu_result_corr_dc4[31:0] : i0_result_e4[31:0];

   assign i1_result_e4_final[31:0] =
                                     (e4d.i1v & e4d.i1secondary) ? exu_i1_result_e4[31:0] : (e4d.i1v & e4d.i1load) ? lsu_result_corr_dc4[31:0] :i1_result_e4[31:0];

   rvdffe #(32) i0wbresultff (.*, .en(i0_wb_data_en), .din(i0_result_e4_final[31:0]), .dout(i0_result_wb_raw[31:0]));
   rvdffe #(32) i1wbresultff (.*, .en(i1_wb_data_en), .din(i1_result_e4_final[31:0]), .dout(i1_result_wb_raw[31:0]));

   assign i0_result_wb[31:0] = fpu_wen_wb ? fpu_result_hold :
                               div_wen_wb ? exu_div_result[31:0] : i0_result_wb_raw[31:0];

   assign i1_result_wb[31:0] = i1_result_wb_raw[31:0];


   rvdffe #(12) e1brpcff (.*, .en(i0_e1_data_en), .din(last_br_immed_d[12:1] ), .dout(last_br_immed_e1[12:1]));
   rvdffe #(12) e2brpcff (.*, .en(i0_e2_data_en), .din(last_br_immed_e1[12:1]), .dout(last_br_immed_e2[12:1]));


   rvdffe #(32) divinstff   (.*, .en(i0_div_decode_d), .din(i0_inst_d[31:0]), .dout(div_inst[31:0]));

   assign i0_inst_d[31:0] = (dec_i0_pc4_d) ? i0[31:0] : {16'b0, dec_i0_cinst_d[15:0] };

   rvdffe #(32) i0e1instff  (.*, .en(i0_e1_data_en), .din(i0_inst_d[31:0]),  .dout(i0_inst_e1[31:0]));
   rvdffe #(32) i0e2instff  (.*, .en(i0_e2_data_en), .din(i0_inst_e1[31:0]), .dout(i0_inst_e2[31:0]));
   rvdffe #(32) i0e3instff  (.*, .en(i0_e3_data_en), .din(i0_inst_e2[31:0]), .dout(i0_inst_e3[31:0]));
   rvdffe #(32) i0e4instff  (.*, .en(i0_e4_data_en), .din(i0_inst_e3[31:0]), .dout(i0_inst_e4[31:0]));
   rvdffe #(32) i0wbinstff  (.*, .en(i0_wb_data_en | exu_div_finish | fpu_resp_valid),
      .din(exu_div_finish ? div_inst[31:0] : fpu_resp_valid ? fpu_inst : i0_inst_e4[31:0]),
      .dout(i0_inst_wb[31:0]));
   rvdffe #(32) i0wb1instff (.*, .en(i0_wb1_data_en | div_wen_wb | fpu_wen_wb),
      .din(i0_inst_wb[31:0]), .dout(i0_inst_wb1[31:0]));

   assign i1_inst_d[31:0] = (dec_i1_pc4_d) ? i1[31:0] : {16'b0, dec_i1_cinst_d[15:0] };

   rvdffe #(32) i1e1instff  (.*, .en(i1_e1_data_en), .din(i1_inst_d[31:0]),  .dout(i1_inst_e1[31:0]));
   rvdffe #(32) i1e2instff  (.*, .en(i1_e2_data_en), .din(i1_inst_e1[31:0]), .dout(i1_inst_e2[31:0]));
   rvdffe #(32) i1e3instff  (.*, .en(i1_e3_data_en), .din(i1_inst_e2[31:0]), .dout(i1_inst_e3[31:0]));
   rvdffe #(32) i1e4instff  (.*, .en(i1_e4_data_en), .din(i1_inst_e3[31:0]), .dout(i1_inst_e4[31:0]));
   rvdffe #(32) i1wbinstff  (.*, .en(i1_wb_data_en), .din(i1_inst_e4[31:0]), .dout(i1_inst_wb[31:0]));
   rvdffe #(32) i1wb1instff (.*, .en(i1_wb1_data_en),.din(i1_inst_wb[31:0]), .dout(i1_inst_wb1[31:0]));

   assign dec_i0_inst_wb1[31:0] = i0_inst_wb1[31:0];
   assign dec_i1_inst_wb1[31:0] = i1_inst_wb1[31:0];


   rvdffe #(31) i0wbpcff  (.*, .en(i0_wb_data_en | exu_div_finish | fpu_resp_valid),
      .din(dec_tlu_i0_pc_e4[31:1]), .dout(i0_pc_wb[31:1]));
   rvdffe #(31) i0wb1pcff (.*, .en(i0_wb1_data_en | div_wen_wb | fpu_wen_wb),
      .din(i0_pc_wb[31:1]), .dout(i0_pc_wb1[31:1]));

   rvdffe #(31) i1wb1pcff (.*, .en(i1_wb1_data_en),.din(i1_pc_wb[31:1]),         .dout(i1_pc_wb1[31:1]));

   assign dec_i0_pc_wb1[31:1] = i0_pc_wb1[31:1];
   assign dec_i1_pc_wb1[31:1] = i1_pc_wb1[31:1];


   assign i0_pc_e1[31:1] = exu_i0_pc_e1[31:1];
   assign i1_pc_e1[31:1] = exu_i1_pc_e1[31:1];

   rvdffe #(31) i0e2pcff (.*, .en(i0_e2_data_en), .din(i0_pc_e1[31:1]), .dout(i0_pc_e2[31:1]));
   rvdffe #(31) i0e3pcff (.*, .en(i0_e3_data_en), .din(i0_pc_e2[31:1]), .dout(i0_pc_e3[31:1]));
   rvdffe #(31) i0e4pcff (.*, .en(i0_e4_data_en), .din(i0_pc_e3[31:1]), .dout(i0_pc_e4[31:1]));
   rvdffe #(31) i1e2pcff (.*, .en(i1_e2_data_en), .din(i1_pc_e1[31:1]), .dout(i1_pc_e2[31:1]));
   rvdffe #(31) i1e3pcff (.*, .en(i1_e3_data_en), .din(i1_pc_e2[31:1]), .dout(i1_pc_e3[31:1]));
   rvdffe #(31) i1e4pcff (.*, .en(i1_e4_data_en), .din(i1_pc_e3[31:1]), .dout(i1_pc_e4[31:1]));

   assign dec_i0_pc_e3[31:1] = i0_pc_e3[31:1];
   assign dec_i1_pc_e3[31:1] = i1_pc_e3[31:1];


   assign dec_tlu_i0_pc_e4[31:1] = exu_div_finish ? div_pc[31:1] :
                                    fpu_resp_valid ? fpu_pc[31:1] : i0_pc_e4[31:1];
   assign dec_tlu_i1_pc_e4[31:1] = i1_pc_e4[31:1];


   assign last_pc_e2[31:1] = (e2d.i1valid) ? i1_pc_e2[31:1] : i0_pc_e2[31:1];

   rvbradder ibradder_correct (
                     .pc(last_pc_e2[31:1]),
                     .offset(last_br_immed_e2[12:1]),
                     .dout(pred_correct_npc_e2[31:1])
                     );


   rvdffe #(31) i1wbpcff (.*, .en(i1_wb_data_en), .din(dec_tlu_i1_pc_e4[31:1]), .dout(i1_pc_wb[31:1]));


   assign i0_rs1bypass[9:0] = {   i0_rs1_depth_d[3:0] == 4'd1  &  i0_rs1_class_d.alu,
                                  i0_rs1_depth_d[3:0] == 4'd2  &  i0_rs1_class_d.alu,
                                  i0_rs1_depth_d[3:0] == 4'd3  &  i0_rs1_class_d.alu,
                                  i0_rs1_depth_d[3:0] == 4'd4  &  i0_rs1_class_d.alu,
                                  i0_rs1_depth_d[3:0] == 4'd5  & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul),
                                  i0_rs1_depth_d[3:0] == 4'd6  & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul),
                                  i0_rs1_depth_d[3:0] == 4'd7  & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul | i0_rs1_class_d.sec),
                                  i0_rs1_depth_d[3:0] == 4'd8  & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul | i0_rs1_class_d.sec),
                                  i0_rs1_depth_d[3:0] == 4'd9  & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul | i0_rs1_class_d.sec),
                                  i0_rs1_depth_d[3:0] == 4'd10 & (i0_rs1_class_d.alu | i0_rs1_class_d.load | i0_rs1_class_d.mul | i0_rs1_class_d.sec) };


   assign i0_rs2bypass[9:0] = {   i0_rs2_depth_d[3:0] == 4'd1  &  i0_rs2_class_d.alu,
                                  i0_rs2_depth_d[3:0] == 4'd2  &  i0_rs2_class_d.alu,
                                  i0_rs2_depth_d[3:0] == 4'd3  &  i0_rs2_class_d.alu,
                                  i0_rs2_depth_d[3:0] == 4'd4  &  i0_rs2_class_d.alu,
                                  i0_rs2_depth_d[3:0] == 4'd5  & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul),
                                  i0_rs2_depth_d[3:0] == 4'd6  & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul),
                                  i0_rs2_depth_d[3:0] == 4'd7  & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul | i0_rs2_class_d.sec),
                                  i0_rs2_depth_d[3:0] == 4'd8  & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul | i0_rs2_class_d.sec),
                                  i0_rs2_depth_d[3:0] == 4'd9  & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul | i0_rs2_class_d.sec),
                                  i0_rs2_depth_d[3:0] == 4'd10 & (i0_rs2_class_d.alu | i0_rs2_class_d.load | i0_rs2_class_d.mul | i0_rs2_class_d.sec) };


   assign i1_rs1bypass[9:0] = {   i1_rs1_depth_d[3:0] == 4'd1  &  i1_rs1_class_d.alu,
                                  i1_rs1_depth_d[3:0] == 4'd2  &  i1_rs1_class_d.alu,
                                  i1_rs1_depth_d[3:0] == 4'd3  &  i1_rs1_class_d.alu,
                                  i1_rs1_depth_d[3:0] == 4'd4  &  i1_rs1_class_d.alu,
                                  i1_rs1_depth_d[3:0] == 4'd5  & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul),
                                  i1_rs1_depth_d[3:0] == 4'd6  & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul),
                                  i1_rs1_depth_d[3:0] == 4'd7  & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul | i1_rs1_class_d.sec),
                                  i1_rs1_depth_d[3:0] == 4'd8  & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul | i1_rs1_class_d.sec),
                                  i1_rs1_depth_d[3:0] == 4'd9  & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul | i1_rs1_class_d.sec),
                                  i1_rs1_depth_d[3:0] == 4'd10 & (i1_rs1_class_d.alu | i1_rs1_class_d.load | i1_rs1_class_d.mul | i1_rs1_class_d.sec) };


   assign i1_rs2bypass[9:0] = {   i1_rs2_depth_d[3:0] == 4'd1  &  i1_rs2_class_d.alu,
                                  i1_rs2_depth_d[3:0] == 4'd2  &  i1_rs2_class_d.alu,
                                  i1_rs2_depth_d[3:0] == 4'd3  &  i1_rs2_class_d.alu,
                                  i1_rs2_depth_d[3:0] == 4'd4  &  i1_rs2_class_d.alu,
                                  i1_rs2_depth_d[3:0] == 4'd5  & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul),
                                  i1_rs2_depth_d[3:0] == 4'd6  & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul),
                                  i1_rs2_depth_d[3:0] == 4'd7  & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul | i1_rs2_class_d.sec),
                                  i1_rs2_depth_d[3:0] == 4'd8  & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul | i1_rs2_class_d.sec),
                                  i1_rs2_depth_d[3:0] == 4'd9  & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul | i1_rs2_class_d.sec),
                                  i1_rs2_depth_d[3:0] == 4'd10 & (i1_rs2_class_d.alu | i1_rs2_class_d.load | i1_rs2_class_d.mul | i1_rs2_class_d.sec) };


   assign dec_i0_rs1_bypass_en_d = |i0_rs1bypass[9:0];
   assign dec_i0_rs2_bypass_en_d = |i0_rs2bypass[9:0];
   assign dec_i1_rs1_bypass_en_d = |i1_rs1bypass[9:0];
   assign dec_i1_rs2_bypass_en_d = |i1_rs2bypass[9:0];


   assign i0_rs1_bypass_data_d[31:0] = ({32{i0_rs1bypass[9]}} & i1_result_e1[31:0]) |
                                       ({32{i0_rs1bypass[8]}} & i0_result_e1[31:0]) |
                                       ({32{i0_rs1bypass[7]}} & i1_result_e2[31:0]) |
                                       ({32{i0_rs1bypass[6]}} & i0_result_e2[31:0]) |
                                       ({32{i0_rs1bypass[5]}} & i1_result_e3_final[31:0]) |
                                       ({32{i0_rs1bypass[4]}} & i0_result_e3_final[31:0]) |
                                       ({32{i0_rs1bypass[3]}} & i1_result_e4_final[31:0]) |
                                       ({32{i0_rs1bypass[2]}} & i0_result_e4_final[31:0]) |
                                       ({32{i0_rs1bypass[1]}} & i1_result_wb[31:0]) |
                                       ({32{i0_rs1bypass[0]}} & i0_result_wb[31:0]);


   assign i0_rs2_bypass_data_d[31:0] = ({32{i0_rs2bypass[9]}} & i1_result_e1[31:0]) |
                                       ({32{i0_rs2bypass[8]}} & i0_result_e1[31:0]) |
                                       ({32{i0_rs2bypass[7]}} & i1_result_e2[31:0]) |
                                       ({32{i0_rs2bypass[6]}} & i0_result_e2[31:0]) |
                                       ({32{i0_rs2bypass[5]}} & i1_result_e3_final[31:0]) |
                                       ({32{i0_rs2bypass[4]}} & i0_result_e3_final[31:0]) |
                                       ({32{i0_rs2bypass[3]}} & i1_result_e4_final[31:0]) |
                                       ({32{i0_rs2bypass[2]}} & i0_result_e4_final[31:0]) |
                                       ({32{i0_rs2bypass[1]}} & i1_result_wb[31:0]) |
                                       ({32{i0_rs2bypass[0]}} & i0_result_wb[31:0]);

   assign i1_rs1_bypass_data_d[31:0] = ({32{i1_rs1bypass[9]}} & i1_result_e1[31:0]) |
                                       ({32{i1_rs1bypass[8]}} & i0_result_e1[31:0]) |
                                       ({32{i1_rs1bypass[7]}} & i1_result_e2[31:0]) |
                                       ({32{i1_rs1bypass[6]}} & i0_result_e2[31:0]) |
                                       ({32{i1_rs1bypass[5]}} & i1_result_e3_final[31:0]) |
                                       ({32{i1_rs1bypass[4]}} & i0_result_e3_final[31:0]) |
                                       ({32{i1_rs1bypass[3]}} & i1_result_e4_final[31:0]) |
                                       ({32{i1_rs1bypass[2]}} & i0_result_e4_final[31:0]) |
                                       ({32{i1_rs1bypass[1]}} & i1_result_wb[31:0]) |
                                       ({32{i1_rs1bypass[0]}} & i0_result_wb[31:0]);


   assign i1_rs2_bypass_data_d[31:0] = ({32{i1_rs2bypass[9]}} & i1_result_e1[31:0]) |
                                       ({32{i1_rs2bypass[8]}} & i0_result_e1[31:0]) |
                                       ({32{i1_rs2bypass[7]}} & i1_result_e2[31:0]) |
                                       ({32{i1_rs2bypass[6]}} & i0_result_e2[31:0]) |
                                       ({32{i1_rs2bypass[5]}} & i1_result_e3_final[31:0]) |
                                       ({32{i1_rs2bypass[4]}} & i0_result_e3_final[31:0]) |
                                       ({32{i1_rs2bypass[3]}} & i1_result_e4_final[31:0]) |
                                       ({32{i1_rs2bypass[2]}} & i0_result_e4_final[31:0]) |
                                       ({32{i1_rs2bypass[1]}} & i1_result_wb[31:0]) |
                                       ({32{i1_rs2bypass[0]}} & i0_result_wb[31:0]);


endmodule


module dec_dec_ctl
   import mycpu_types::*;
(
   input logic [31:0] inst,

   output dec_pkt_t out
   );

   logic [31:0] i;


   assign i[31:0] = inst[31:0];


assign out.alu = (i[2]) | (i[6]) | (!i[25]&i[4]) | (!i[5]&i[4]);

assign out.rs1 = (!i[14]&!i[13]&!i[2]) | (!i[13]&i[11]&!i[2]) | (i[19]&i[13]&!i[2]) | (
    !i[13]&i[10]&!i[2]) | (i[18]&i[13]&!i[2]) | (!i[13]&i[9]&!i[2]) | (
    i[17]&i[13]&!i[2]) | (!i[13]&i[8]&!i[2]) | (i[16]&i[13]&!i[2]) | (
    !i[13]&i[7]&!i[2]) | (i[15]&i[13]&!i[2]) | (!i[4]&!i[3]) | (!i[6]
    &!i[2]);

assign out.rs2 = (i[5]&!i[4]&!i[2]) | (!i[6]&i[5]&!i[2]);

assign out.imm12 = (!i[4]&!i[3]&i[2]) | (i[13]&!i[5]&i[4]&!i[2]) | (!i[13]&!i[12]
    &i[6]&i[4]) | (!i[12]&!i[5]&i[4]&!i[2]);

assign out.rd = (!i[5]&!i[2]) | (i[5]&i[2]) | (i[4]);

assign out.shimm5 = (!i[13]&i[12]&!i[5]&i[4]&!i[2]);

assign out.imm20 = (i[5]&i[3]) | (i[4]&i[2]);

assign out.pc = (!i[5]&!i[3]&i[2]) | (i[5]&i[3]);

assign out.load = (!i[5]&!i[4]&!i[2]);

assign out.store = (!i[6]&i[5]&!i[4]);

assign out.lsu = (!i[6]&!i[4]&!i[2]);

assign out.add = (!i[14]&!i[13]&!i[12]&!i[5]&i[4]) | (!i[5]&!i[3]&i[2]) | (!i[30]
    &!i[25]&!i[14]&!i[13]&!i[12]&!i[6]&i[4]&!i[2]);

assign out.sub = (i[30]&!i[12]&!i[6]&i[5]&i[4]&!i[2]) | (!i[25]&!i[14]&i[13]&!i[6]
    &i[4]&!i[2]) | (!i[14]&i[13]&!i[5]&i[4]&!i[2]) | (i[6]&!i[4]&!i[2]);

assign out.land = (i[14]&i[13]&i[12]&!i[5]&!i[2]) | (!i[25]&i[14]&i[13]&i[12]&!i[6]
    &!i[2]);

assign out.lor = (!i[6]&i[3]) | (!i[25]&i[14]&i[13]&!i[12]&i[4]&!i[2]) | (i[5]&i[4]
    &i[2]) | (!i[12]&i[6]&i[4]) | (i[13]&i[6]&i[4]) | (i[14]&i[13]&!i[12]
    &!i[5]&!i[2]) | (i[7]&i[6]&i[4]) | (i[8]&i[6]&i[4]) | (i[9]&i[6]&i[4]) | (
    i[10]&i[6]&i[4]) | (i[11]&i[6]&i[4]);

assign out.lxor = (!i[25]&i[14]&!i[13]&!i[12]&i[4]&!i[2]) | (i[14]&!i[13]&!i[12]
    &!i[5]&i[4]&!i[2]);

assign out.sll = (!i[25]&!i[14]&!i[13]&i[12]&!i[6]&i[4]&!i[2]);

assign out.sra = (i[30]&!i[13]&i[12]&!i[6]&i[4]&!i[2]);

assign out.srl = (!i[30]&!i[25]&i[14]&!i[13]&i[12]&!i[6]&i[4]&!i[2]);

assign out.slt = (!i[25]&!i[14]&i[13]&!i[6]&i[4]&!i[2]) | (!i[14]&i[13]&!i[5]&i[4]
    &!i[2]);

assign out.unsign = (!i[14]&i[13]&i[12]&!i[5]&!i[2]) | (i[13]&i[6]&!i[4]&!i[2]) | (
    i[14]&!i[5]&!i[4]) | (!i[25]&!i[14]&i[13]&i[12]&!i[6]&!i[2]) | (
    i[25]&i[14]&i[12]&!i[6]&i[5]&!i[2]);

assign out.condbr = (i[6]&!i[4]&!i[2]);

assign out.beq = (!i[14]&!i[12]&i[6]&!i[4]&!i[2]);

assign out.bne = (!i[14]&i[12]&i[6]&!i[4]&!i[2]);

assign out.bge = (i[14]&i[12]&i[5]&!i[4]&!i[2]);

assign out.blt = (i[14]&!i[12]&i[5]&!i[4]&!i[2]);

assign out.jal = (i[6]&i[2]);

assign out.by = (!i[13]&!i[12]&!i[6]&!i[4]&!i[2]);

assign out.half = (i[12]&!i[6]&!i[4]&!i[2]);

assign out.word = (i[13]&!i[6]&!i[4]);

assign out.csr_read = (i[13]&i[6]&i[4]) | (i[7]&i[6]&i[4]) | (i[8]&i[6]&i[4]) | (
    i[9]&i[6]&i[4]) | (i[10]&i[6]&i[4]) | (i[11]&i[6]&i[4]);

assign out.csr_clr = (i[15]&i[13]&i[12]&i[6]&i[4]) | (i[16]&i[13]&i[12]&i[6]&i[4]) | (
    i[17]&i[13]&i[12]&i[6]&i[4]) | (i[18]&i[13]&i[12]&i[6]&i[4]) | (
    i[19]&i[13]&i[12]&i[6]&i[4]);

assign out.csr_set = (i[15]&!i[12]&i[6]&i[4]) | (i[16]&!i[12]&i[6]&i[4]) | (i[17]
    &!i[12]&i[6]&i[4]) | (i[18]&!i[12]&i[6]&i[4]) | (i[19]&!i[12]&i[6]
    &i[4]);

assign out.csr_write = (!i[13]&i[12]&i[6]&i[4]);

assign out.csr_imm = (i[14]&!i[13]&i[6]&i[4]) | (i[15]&i[14]&i[6]&i[4]) | (i[16]
    &i[14]&i[6]&i[4]) | (i[17]&i[14]&i[6]&i[4]) | (i[18]&i[14]&i[6]&i[4]) | (
    i[19]&i[14]&i[6]&i[4]);

assign out.presync = (!i[5]&i[3]) | (i[25]&i[14]&!i[6]&i[5]&!i[2]) | (!i[13]&i[7]
    &i[6]&i[4]) | (!i[13]&i[8]&i[6]&i[4]) | (!i[13]&i[9]&i[6]&i[4]) | (
    !i[13]&i[10]&i[6]&i[4]) | (!i[13]&i[11]&i[6]&i[4]) | (i[15]&i[13]
    &i[6]&i[4]) | (i[16]&i[13]&i[6]&i[4]) | (i[17]&i[13]&i[6]&i[4]) | (
    i[18]&i[13]&i[6]&i[4]) | (i[19]&i[13]&i[6]&i[4]);

assign out.postsync = (i[12]&!i[5]&i[3]) | (!i[22]&!i[13]&!i[12]&i[6]&i[4]) | (
    i[25]&i[14]&!i[6]&i[5]&!i[2]) | (!i[13]&i[7]&i[6]&i[4]) | (!i[13]
    &i[8]&i[6]&i[4]) | (!i[13]&i[9]&i[6]&i[4]) | (!i[13]&i[10]&i[6]&i[4]) | (
    !i[13]&i[11]&i[6]&i[4]) | (i[15]&i[13]&i[6]&i[4]) | (i[16]&i[13]&i[6]
    &i[4]) | (i[17]&i[13]&i[6]&i[4]) | (i[18]&i[13]&i[6]&i[4]) | (i[19]
    &i[13]&i[6]&i[4]);

assign out.ebreak = (!i[22]&i[20]&!i[13]&!i[12]&i[6]&i[4]);

assign out.ecall = (!i[21]&!i[20]&!i[13]&!i[12]&i[6]&i[4]);

assign out.mret = (i[29]&!i[13]&!i[12]&i[6]&i[4]);

assign out.mul = (i[25]&!i[14]&!i[6]&i[5]&i[4]&!i[2]);

assign out.rs1_sign = (i[25]&!i[14]&i[13]&!i[12]&!i[6]&i[5]&i[4]&!i[2]) | (i[25]
    &!i[14]&!i[13]&i[12]&!i[6]&i[4]&!i[2]);

assign out.rs2_sign = (i[25]&!i[14]&!i[13]&i[12]&!i[6]&i[4]&!i[2]);

assign out.low = (i[25]&!i[14]&!i[13]&!i[12]&i[5]&i[4]&!i[2]);

assign out.div = (i[25]&i[14]&!i[6]&i[5]&!i[2]);

assign out.rem = (i[25]&i[14]&i[13]&!i[6]&i[5]&!i[2]);

assign out.fpu = 1'b0;
assign out.fpload = 1'b0;
assign out.fpstore = 1'b0;

assign out.fence = (!i[5]&i[3]);

assign out.fence_i = (i[12]&!i[5]&i[3]);

assign out.pm_alu = (i[28]&i[22]&!i[13]&!i[12]&i[4]) | (i[4]&i[2]) | (!i[25]&!i[6]
    &i[4]) | (!i[5]&i[4]);


assign out.legal = (!i[31]&!i[30]&i[29]&i[28]&!i[27]&!i[26]&!i[25]&!i[24]&!i[23]
    &!i[22]&i[21]&!i[20]&!i[19]&!i[18]&!i[17]&!i[16]&!i[15]&!i[14]&!i[11]
    &!i[10]&!i[9]&!i[8]&!i[7]&i[6]&i[5]&i[4]&!i[3]&!i[2]&i[1]&i[0]) | (
    !i[31]&!i[30]&!i[29]&i[28]&!i[27]&!i[26]&!i[25]&!i[24]&!i[23]&i[22]
    &!i[21]&i[20]&!i[19]&!i[18]&!i[17]&!i[16]&!i[15]&!i[14]&!i[11]&!i[10]
    &!i[9]&!i[8]&!i[7]&i[6]&i[5]&i[4]&!i[3]&!i[2]&i[1]&i[0]) | (!i[31]
    &!i[30]&!i[29]&!i[28]&!i[27]&!i[26]&!i[25]&!i[24]&!i[23]&!i[22]&!i[21]
    &!i[19]&!i[18]&!i[17]&!i[16]&!i[15]&!i[14]&!i[11]&!i[10]&!i[9]&!i[8]
    &!i[7]&i[5]&i[4]&!i[3]&!i[2]&i[1]&i[0]) | (!i[31]&!i[30]&!i[29]&!i[28]
    &!i[27]&!i[26]&!i[25]&!i[6]&i[4]&!i[3]&i[1]&i[0]) | (!i[31]&!i[29]
    &!i[28]&!i[27]&!i[26]&!i[25]&!i[14]&!i[13]&!i[12]&!i[6]&!i[3]&!i[2]
    &i[1]&i[0]) | (!i[31]&!i[29]&!i[28]&!i[27]&!i[26]&!i[25]&i[14]&!i[13]
    &i[12]&!i[6]&i[4]&!i[3]&i[1]&i[0]) | (!i[31]&!i[30]&!i[29]&!i[28]
    &!i[27]&!i[26]&!i[6]&i[5]&i[4]&!i[3]&i[1]&i[0]) | (!i[14]&!i[13]
    &!i[12]&i[6]&i[5]&!i[4]&!i[3]&i[1]&i[0]) | (i[14]&i[6]&i[5]&!i[4]
    &!i[3]&!i[2]&i[1]&i[0]) | (!i[12]&!i[6]&!i[5]&i[4]&!i[3]&i[1]&i[0]) | (
    !i[14]&!i[13]&i[5]&!i[4]&!i[3]&!i[2]&i[1]&i[0]) | (i[12]&i[6]&i[5]
    &i[4]&!i[3]&!i[2]&i[1]&i[0]) | (!i[31]&!i[30]&!i[29]&!i[28]&!i[27]
    &!i[26]&!i[25]&!i[24]&!i[23]&!i[22]&!i[21]&!i[20]&!i[19]&!i[18]&!i[17]
    &!i[16]&!i[15]&!i[14]&!i[13]&!i[11]&!i[10]&!i[9]&!i[8]&!i[7]&!i[6]
    &!i[5]&!i[4]&i[3]&i[2]&i[1]&i[0]) | (!i[31]&!i[30]&!i[29]&!i[28]
    &!i[19]&!i[18]&!i[17]&!i[16]&!i[15]&!i[14]&!i[13]&!i[12]&!i[11]&!i[10]
    &!i[9]&!i[8]&!i[7]&!i[6]&!i[5]&!i[4]&i[3]&i[2]&i[1]&i[0]) | (i[13]
    &i[6]&i[5]&i[4]&!i[3]&!i[2]&i[1]&i[0]) | (!i[13]&!i[6]&!i[5]&!i[4]
    &!i[3]&!i[2]&i[1]&i[0]) | (i[6]&i[5]&!i[4]&i[3]&i[2]&i[1]&i[0]) | (
    i[13]&!i[6]&!i[5]&i[4]&!i[3]&i[1]&i[0]) | (!i[14]&!i[12]&!i[6]&!i[4]
    &!i[3]&!i[2]&i[1]&i[0]) | (!i[6]&i[4]&!i[3]&i[2]&i[1]&i[0]);


endmodule
