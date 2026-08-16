

module dec
   import mycpu_types::*;
(
   input logic clk,
   input logic free_clk,
   input logic active_clk,


   output logic       dec_pause_state_cg,

   input logic rst_l,
   input logic [31:1] rst_vec,

   input logic        nmi_int,
   input logic [31:1] nmi_vec,

   input logic  i_cpu_halt_req,
   input logic  i_cpu_run_req,

   output logic o_cpu_halt_status,
   output logic o_cpu_halt_ack,
   output logic o_cpu_run_ack,
   output logic o_debug_mode_status,


   input logic mpc_debug_halt_req,
   input logic mpc_debug_run_req,
   input logic mpc_reset_run_req,
   output logic mpc_debug_halt_ack,
   output logic mpc_debug_run_ack,
   output logic debug_brkpt_status,


   output logic dec_ib0_valid_eff_d,
   output logic dec_ib1_valid_eff_d,

   input logic       exu_pmu_i0_br_misp,
   input logic       exu_pmu_i0_br_ataken,
   input logic       exu_pmu_i0_pc4,
   input logic       exu_pmu_i1_br_misp,
   input logic       exu_pmu_i1_br_ataken,
   input logic       exu_pmu_i1_pc4,


   input logic                                 lsu_nonblock_load_valid_dc3,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_dc3,
   input logic                                 lsu_nonblock_load_inv_dc5,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_dc5,
   input logic                                 lsu_nonblock_load_data_valid,
   input logic                                 lsu_nonblock_load_data_error,
   input logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,
   input logic [31:0]                          lsu_nonblock_load_data,

   input logic       lsu_pmu_bus_trxn,
   input logic       lsu_pmu_bus_misaligned,
   input logic       lsu_pmu_bus_error,
   input logic       lsu_pmu_bus_busy,
   input logic       lsu_pmu_misaligned_dc3,

   input logic [1:0] ifu_pmu_instr_aligned,
   input logic       ifu_pmu_align_stall,
   input logic       ifu_pmu_fetch_stall,
   input logic       ifu_pmu_fetch_miss,
   input logic       ifu_pmu_fetch_hit,
   input logic       ifu_pmu_bus_error,
   input logic       ifu_pmu_bus_busy,
   input logic       ifu_pmu_bus_trxn,

   input logic [3:0]  lsu_trigger_match_dc3,
   input logic        dbg_cmd_valid,
   input logic  [1:0] dbg_cmd_size,
   input logic        dbg_cmd_write,
   input logic  [1:0] dbg_cmd_type,
   input logic [31:0] dbg_cmd_addr,
   input logic  [1:0] dbg_cmd_wrdata,


   input logic   ifu_i0_icaf,
   input logic   ifu_i1_icaf,
   input logic   ifu_i0_icaf_second,
   input logic   ifu_i1_icaf_second,
   input logic   ifu_i0_perr,
   input logic   ifu_i1_perr,
   input logic   ifu_i0_sbecc,
   input logic   ifu_i1_sbecc,
   input logic   ifu_i0_dbecc,
   input logic   ifu_i1_dbecc,

   input logic lsu_freeze_dc3,
   input logic lsu_idle_any,
   input logic lsu_halt_idle_any,

   input br_pkt_t i0_brp,
   input br_pkt_t i1_brp,

   input    lsu_error_pkt_t lsu_error_pkt_dc3,
   input logic         lsu_single_ecc_error_incr,

   input logic lsu_load_ecc_stbuf_full_dc3,

   input logic         lsu_imprecise_error_load_any,
   input logic         lsu_imprecise_error_store_any,
   input logic [31:0]  lsu_imprecise_error_addr_any,
   input logic         lsu_freeze_external_ints_dc3,

   input logic exu_i0_flush_lower_e4,
   input logic exu_i1_flush_lower_e4,
   input logic [31:1] exu_i0_flush_path_e4,
   input logic [31:1] exu_i1_flush_path_e4,
   input logic exu_i0_inst_misaligned_e4,
   input logic exu_i1_inst_misaligned_e4,
   input logic [31:1] exu_i0_inst_misaligned_addr_e4,
   input logic [31:1] exu_i1_inst_misaligned_addr_e4,

   input logic [15:0] ifu_illegal_inst,

   input logic exu_div_stall,
   input logic [31:0]  exu_div_result,
   input logic exu_div_finish,

   input logic [31:0] exu_mul_result_e3,

   input logic [31:0] exu_csr_rs1_e1,

   input logic [31:0] lsu_result_dc3,
   input logic [31:0] lsu_result_corr_dc4,

   input logic        lsu_load_stall_any,
   input logic        lsu_store_stall_any,
   input logic exu_i0_flush_final,
   input logic exu_i1_flush_final,

   input logic [31:1] exu_npc_e4,

   input logic exu_flush_final,

   input logic [31:0] exu_i0_result_e1,
   input logic [31:0] exu_i1_result_e1,

   input logic [31:0] exu_i0_result_e4,
   input logic [31:0] exu_i1_result_e4,


   input logic         ifu_i0_valid, ifu_i1_valid,
   input logic [31:0]  ifu_i0_instr, ifu_i1_instr,
   input logic [31:1]  ifu_i0_pc, ifu_i1_pc,
   input logic         ifu_i0_pc4, ifu_i1_pc4,
   input logic  [31:1] exu_i0_pc_e1,
   input logic  [31:1] exu_i1_pc_e1,

   input logic mexintpend,
   input logic timer_int,

   input logic       mhwakeup,


   input logic dbg_halt_req,
   input logic dbg_resume_req,
   input logic ifu_miss_state_idle,

  output logic dec_tlu_flush_noredir_wb ,
   output logic dec_tlu_mpc_halted_only,
   output logic dec_tlu_dbg_halted,
   output logic dec_tlu_pmu_fw_halted,
   output logic dec_tlu_debug_mode,
   output logic dec_tlu_resume_ack,
   output logic dec_tlu_flush_leak_one_wb,
   output logic dec_tlu_flush_err_wb,

   output logic dec_debug_wdata_rs1_d,

   output logic [31:0] dec_dbg_rddata,

   output logic dec_dbg_cmd_done,
   output logic dec_dbg_cmd_fail,

   output trigger_pkt_t  [3:0] trigger_pkt_any,


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

   output logic  [31:0] gpr_i0_rs1_d,
   output logic  [31:0] gpr_i0_rs2_d,
   output logic  [31:0] gpr_i1_rs1_d,
   output logic  [31:0] gpr_i1_rs2_d,

   output logic [31:0] dec_i0_immed_d,
   output logic [31:0] dec_i1_immed_d,

   output logic [12:1] dec_i0_br_immed_d,
   output logic [12:1] dec_i1_br_immed_d,

   output        alu_pkt_t i0_ap,
   output        alu_pkt_t i1_ap,

   output logic          dec_i0_alu_decode_d,
   output logic          dec_i1_alu_decode_d,

   output logic          dec_i0_select_pc_d,
   output logic          dec_i1_select_pc_d,

   output logic [31:1] dec_i0_pc_d, dec_i1_pc_d,
   output logic         dec_i0_rs1_bypass_en_d,
   output logic         dec_i0_rs2_bypass_en_d,
   output logic         dec_i1_rs1_bypass_en_d,
   output logic         dec_i1_rs2_bypass_en_d,

   output logic [31:0] i0_rs1_bypass_data_d,
   output logic [31:0] i0_rs2_bypass_data_d,
   output logic [31:0] i1_rs1_bypass_data_d,
   output logic [31:0] i1_rs2_bypass_data_d,
   output logic         dec_ib3_valid_d,
   output logic         dec_ib2_valid_d,

   output lsu_pkt_t    lsu_p,
   output mul_pkt_t    mul_p,
   output div_pkt_t    div_p,

   output logic [11:0] dec_lsu_offset_d,
   output logic        dec_i0_lsu_d,
   output logic        dec_i1_lsu_d,
   output logic        dec_i0_fstore_d,
   output logic [31:0] dec_fpr_rs2_d,

   output logic        flush_final_e3,
   output logic        i0_flush_final_e3,

   output logic        dec_csr_ren_d,

   output logic        dec_tlu_cancel_e4,

   output logic        dec_tlu_flush_lower_wb,
   output logic [31:1] dec_tlu_flush_path_wb,
   output logic        dec_tlu_i0_kill_writeb_wb,
   output logic        dec_tlu_i1_kill_writeb_wb,
   output logic        dec_tlu_fence_i_wb,

   output logic        dec_i0_mul_d,
   output logic        dec_i1_mul_d,
   output logic        dec_i0_div_d,
   output logic        dec_i1_div_d,
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

   output br_tlu_pkt_t dec_tlu_br0_wb_pkt,
   output br_tlu_pkt_t dec_tlu_br1_wb_pkt,

   output logic [1:0] dec_tlu_perfcnt0,
   output logic [1:0] dec_tlu_perfcnt1,
   output logic [1:0] dec_tlu_perfcnt2,
   output logic [1:0] dec_tlu_perfcnt3,

   output predict_pkt_t  i0_predict_p_d,
   output predict_pkt_t  i1_predict_p_d,

   output logic dec_i0_lsu_decode_d,

   output logic [31:0] i0_result_e4_eff,
   output logic [31:0] i1_result_e4_eff,

   output   logic dec_tlu_i0_valid_e4,
   output   logic dec_tlu_i1_valid_e4,

   output logic [31:0] i0_result_e2,
   output logic [31:0] dec_tlu_mrac_ff,

   output logic [31:1] dec_tlu_i0_pc_e4,
   output logic [31:1] dec_tlu_i1_pc_e4,

   output logic [4:2] dec_i0_data_en,
   output logic [4:1] dec_i0_ctl_en,
   output logic [4:2] dec_i1_data_en,
   output logic [4:1] dec_i1_ctl_en,

   output logic       dec_nonblock_load_freeze_dc2,

   input logic [15:0] ifu_i0_cinst,
   input logic [15:0] ifu_i1_cinst,

   output trace_pkt_t  trace_rv_trace_pkt,


   output logic  dec_tlu_sideeffect_posted_disable,
   output logic  dec_tlu_core_ecc_disable,
   output logic  dec_tlu_sec_alu_disable,
   output logic  dec_tlu_non_blocking_disable,
   output logic  dec_tlu_fast_div_disable,
   output logic  dec_tlu_bpred_disable,
   output logic  dec_tlu_wb_coalescing_disable,
   output logic  dec_tlu_ld_miss_byp_wb_disable,


   output logic  dec_tlu_misc_clk_override,
   output logic  dec_tlu_exu_clk_override,
   output logic  dec_tlu_ifu_clk_override,
   output logic  dec_tlu_lsu_clk_override,
   output logic  dec_tlu_bus_clk_override,
   output logic  dec_tlu_dccm_clk_override,
   output logic  dec_tlu_icm_clk_override,

   input  logic        scan_mode

   );

   localparam GPR_BANKS = 1;
   localparam GPR_BANKS_LOG2 = (GPR_BANKS == 1) ? 1 : $clog2(GPR_BANKS);

   logic  dec_tlu_dec_clk_override;
   logic  clk_override;

   logic               dec_ib1_valid_d;
   logic               dec_ib0_valid_d;

   logic [1:0]         dec_pmu_instr_decoded;
   logic               dec_pmu_decode_stall;
   logic               dec_pmu_presync_stall;
   logic               dec_pmu_postsync_stall;

   logic dec_tlu_wr_pause_wb;

   logic        dec_i0_rs1_en_d;
   logic        dec_i0_rs2_en_d;

   logic [4:0]  dec_i0_rs1_d;
   logic [4:0]  dec_i0_rs2_d;


   logic        dec_i1_rs1_en_d;
   logic        dec_i1_rs2_en_d;

   logic [4:0]  dec_i1_rs1_d;
   logic [4:0]  dec_i1_rs2_d;


   logic [31:0] dec_i0_instr_d, dec_i1_instr_d;

   logic  dec_tlu_pipelining_disable;
   logic  dec_tlu_dual_issue_disable;


   logic [4:0]  dec_i0_waddr_wb;
   logic        dec_i0_wen_wb;
   logic [31:0] dec_i0_wdata_wb;

   logic [4:0]  dec_i1_waddr_wb;
   logic        dec_i1_wen_wb;
   logic [31:0] dec_i1_wdata_wb;

   logic        dec_csr_wen_wb;
   logic [11:0] dec_csr_rdaddr_d;
   logic [11:0] dec_csr_wraddr_wb;

   logic [31:0] dec_csr_wrdata_wb;

   logic [31:0] dec_csr_rddata_d;
   logic        dec_csr_legal_d;

   logic        dec_csr_wen_unq_d;
   logic        dec_csr_any_unq_d;
   logic        dec_csr_stall_int_ff;


   trap_pkt_t dec_tlu_packet_e4;

   logic        dec_i0_pc4_d, dec_i1_pc4_d;
   logic        dec_tlu_presync_d;
   logic        dec_tlu_postsync_d;
   logic        dec_tlu_debug_stall;

   logic [31:0] dec_illegal_inst;


   logic                      wen_bank_id;
   logic [GPR_BANKS_LOG2-1:0] wr_bank_id;

   logic                      dec_i0_icaf_d;
   logic                      dec_i1_icaf_d;
   logic                      dec_i0_perr_d;
   logic                      dec_i1_perr_d;
   logic                      dec_i0_sbecc_d;
   logic                      dec_i1_sbecc_d;
   logic                      dec_i0_dbecc_d;
   logic                      dec_i1_dbecc_d;

   logic                      dec_i0_icaf_second_d;

   logic                      dec_i0_decode_d;
   logic                      dec_i1_decode_d;

   logic [3:0]                dec_i0_trigger_match_d;
   logic [3:0]                dec_i1_trigger_match_d;


   logic                      dec_debug_fence_d;

   logic                      dec_nonblock_load_wen;
   logic [4:0]                dec_nonblock_load_waddr;
   logic                      dec_tlu_flush_pause_wb;

   logic                      dec_i0_load_e4;
   logic [2:0]                dec_tlu_frm;
   logic                      dec_tlu_fp_enabled;
   logic                      dec_fpu_fflags_valid;
   logic [4:0]                dec_fpu_fflags;
   logic                      dec_fpu_dirty;

   logic                      dec_pause_state;

   br_pkt_t dec_i0_brp;
   br_pkt_t dec_i1_brp;

   assign clk_override = dec_tlu_dec_clk_override;


   assign dec_dbg_rddata[31:0] = dec_i0_wdata_wb[31:0];


   assign wen_bank_id = '0;
   assign wr_bank_id  = '0;


   dec_gpr_ctl #(.GPR_BANKS(GPR_BANKS),
                 .GPR_BANKS_LOG2(GPR_BANKS_LOG2)) arf (.*,

                    .raddr0(dec_i0_rs1_d[4:0]), .rden0(dec_i0_rs1_en_d),
                    .raddr1(dec_i0_rs2_d[4:0]), .rden1(dec_i0_rs2_en_d),
                    .raddr2(dec_i1_rs1_d[4:0]), .rden2(dec_i1_rs1_en_d),
                    .raddr3(dec_i1_rs2_d[4:0]), .rden3(dec_i1_rs2_en_d),

                    .waddr0(dec_i0_waddr_wb[4:0]),         .wen0(dec_i0_wen_wb),         .wd0(dec_i0_wdata_wb[31:0]),
                    .waddr1(dec_i1_waddr_wb[4:0]),         .wen1(dec_i1_wen_wb),         .wd1(dec_i1_wdata_wb[31:0]),
                    .waddr2(dec_nonblock_load_waddr[4:0]), .wen2(dec_nonblock_load_wen), .wd2(lsu_nonblock_load_data[31:0]),


                    .rd0(gpr_i0_rs1_d[31:0]), .rd1(gpr_i0_rs2_d[31:0]),
                    .rd2(gpr_i1_rs1_d[31:0]), .rd3(gpr_i1_rs2_d[31:0])
                    );


   dec_trigger dec_trigger (.*);


   logic [15:0] dec_i0_cinst_d;
   logic [15:0] dec_i1_cinst_d;
   logic [31:0]               dec_i0_inst_wb1;
   logic [31:0]               dec_i1_inst_wb1;
   logic [31:1]               dec_i0_pc_wb1;
   logic [31:1]               dec_i1_pc_wb1;
   logic dec_tlu_i1_valid_wb1, dec_tlu_i0_valid_wb1,  dec_tlu_int_valid_wb1;
   logic [4:0] dec_tlu_exc_cause_wb1;
   logic [31:0] dec_tlu_mtval_wb1;

   logic        dec_tlu_i0_exc_valid_wb1, dec_tlu_i1_exc_valid_wb1;


   assign trace_rv_trace_pkt.trace_rv_i_insn_ip    = { 32'b0, dec_i1_inst_wb1[31:0], dec_i0_inst_wb1[31:0] };
   assign trace_rv_trace_pkt.trace_rv_i_address_ip = { 32'b0, dec_i1_pc_wb1[31:1], 1'b0, dec_i0_pc_wb1[31:1], 1'b0 };

   assign trace_rv_trace_pkt.trace_rv_i_valid_ip =     {dec_tlu_int_valid_wb1,
                                                    dec_tlu_i1_valid_wb1 | dec_tlu_i1_exc_valid_wb1,
                                                    dec_tlu_i0_valid_wb1 | dec_tlu_i0_exc_valid_wb1
                                                    };
   assign trace_rv_trace_pkt.trace_rv_i_exception_ip = {dec_tlu_int_valid_wb1, dec_tlu_i1_exc_valid_wb1, dec_tlu_i0_exc_valid_wb1};
   assign trace_rv_trace_pkt.trace_rv_i_ecause_ip =     dec_tlu_exc_cause_wb1[4:0];
   assign trace_rv_trace_pkt.trace_rv_i_interrupt_ip = {dec_tlu_int_valid_wb1,2'b0};
   assign trace_rv_trace_pkt.trace_rv_i_tval_ip =    dec_tlu_mtval_wb1[31:0];

   dec_ib_ctl instbuff (.*
                        );

   dec_decode_ctl decode (.*);

   dec_tlu_ctl tlu (.*);


endmodule

