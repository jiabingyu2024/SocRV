

module mycpu_core
   import mycpu_types::*;
(
   input logic                  clk,
   input logic                  rst_l,
   input logic                  dbg_rst_l,
   input logic [31:1]           rst_vec,
   input logic                  nmi_int,
   input logic [31:1]           nmi_vec,
   output logic                 core_rst_l,

   output logic [63:0] trace_rv_i_insn_ip,
   output logic [63:0] trace_rv_i_address_ip,
   output logic [2:0]  trace_rv_i_valid_ip,
   output logic [2:0]  trace_rv_i_exception_ip,
   output logic [4:0]  trace_rv_i_ecause_ip,
   output logic [2:0]  trace_rv_i_interrupt_ip,
   output logic [31:0] trace_rv_i_tval_ip,


   output logic                 lsu_freeze_dc3,
   output logic                 dccm_clk_override,
   output logic                 icm_clk_override,
   output logic                 dec_tlu_core_ecc_disable,


   input logic  i_cpu_halt_req,
   input logic  i_cpu_run_req,
   output logic o_cpu_halt_ack,
   output logic o_cpu_halt_status,
   output logic o_cpu_run_ack,
   output logic o_debug_mode_status,


   input logic mpc_debug_halt_req,
   input logic mpc_debug_run_req,
   input logic mpc_reset_run_req,
   output logic mpc_debug_halt_ack,
   output logic mpc_debug_run_ack,
   output logic debug_brkpt_status,

   output logic [1:0] dec_tlu_perfcnt0,
   output logic [1:0] dec_tlu_perfcnt1,
   output logic [1:0] dec_tlu_perfcnt2,
   output logic [1:0] dec_tlu_perfcnt3,


   output logic                          dccm_wren,
   output logic                          dccm_rden,
   output logic [`RV_DCCM_BITS-1:0]          dccm_wr_addr,
   output logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_lo,
   output logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_hi,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0]   dccm_wr_data,

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_lo,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_hi,


   output logic                               lsu_mmio_valid,
   output logic                               lsu_mmio_write,
   output logic [31:0]                        lsu_mmio_addr,
   output logic [31:0]                        lsu_mmio_wdata,
   output logic [3:0]                         lsu_mmio_wstrb,
   input  logic                               lsu_mmio_ready,
   input  logic [31:0]                        lsu_mmio_rdata,
   input  logic                               lsu_mmio_error,


   output logic [`RV_ICCM_BITS-1:2]           iccm_rw_addr,
   output logic                  iccm_rden,

   input  logic [127:0]          iccm_rd_data,

   input   logic                 lsu_bus_clk_en,
   input   logic                 ifu_bus_clk_en,

   input logic [8:1]                           extintsrc_req,
   input logic                   timer_int,
   input logic                   scan_mode
);

`include "core_params.svh"


`define ADDRWIDTH 32


   logic [1:0]                   ifu_pmu_instr_aligned;
   logic                         ifu_pmu_align_stall;
   logic  [31:0] gpr_i0_rs1_d;
   logic  [31:0] gpr_i0_rs2_d;
   logic  [31:0] gpr_i1_rs1_d;
   logic  [31:0] gpr_i1_rs2_d;

   logic [31:0] i0_rs1_bypass_data_d;
   logic [31:0] i0_rs2_bypass_data_d;
   logic [31:0] i1_rs1_bypass_data_d;
   logic [31:0] i1_rs2_bypass_data_d;
   logic [31:0] exu_i0_result_e1, exu_i1_result_e1;
   logic  [31:1] exu_i0_pc_e1;
   logic  [31:1] exu_i1_pc_e1;
   logic [31:1]  exu_npc_e4;
   logic [31:1] dec_tlu_i0_pc_e4;
   logic [31:1] dec_tlu_i1_pc_e4;

   alu_pkt_t  i0_ap, i1_ap;


   trigger_pkt_t [3:0]     trigger_pkt_any;
   logic [3:0]             lsu_trigger_match_dc3;
   logic        dec_ib3_valid_d, dec_ib2_valid_d;
   logic        dec_ib1_valid_eff_d;
   logic        dec_ib0_valid_eff_d;


   logic [31:0] dec_i0_immed_d;
   logic [31:0] dec_i1_immed_d;

   logic [12:1] dec_i0_br_immed_d;
   logic [12:1] dec_i1_br_immed_d;

   logic         dec_i0_select_pc_d;
   logic         dec_i1_select_pc_d;

   logic [31:1] dec_i0_pc_d, dec_i1_pc_d;
   logic        dec_i0_rs1_bypass_en_d;
   logic        dec_i0_rs2_bypass_en_d;
   logic        dec_i1_rs1_bypass_en_d;
   logic        dec_i1_rs2_bypass_en_d;


   logic         dec_i0_alu_decode_d;
   logic         dec_i1_alu_decode_d;

   rets_pkt_t exu_rets_e1_pkt;
   rets_pkt_t exu_rets_e4_pkt;

   logic         dec_tlu_cancel_e4;
   logic         ifu_miss_state_idle;
   logic         dec_tlu_flush_noredir_wb;
   logic         dec_tlu_flush_leak_one_wb;
   logic         dec_tlu_flush_err_wb;
   logic         ifu_i0_valid, ifu_i1_valid;
   logic [31:0]  ifu_i0_instr, ifu_i1_instr;
   logic [31:1]  ifu_i0_pc, ifu_i1_pc;

   logic        exu_i0_flush_final;
   logic        exu_i1_flush_final;

   logic        exu_flush_final;
   logic        exu_flush_upper_e2;

   logic [31:1] exu_flush_path_final;

   logic [31:0] exu_lsu_rs1_d;
   logic [31:0] exu_lsu_rs2_d;


   lsu_pkt_t    lsu_p;

   logic [11:0] dec_lsu_offset_d;
   logic        dec_i0_lsu_d;
   logic        dec_i1_lsu_d;
   logic        dec_i0_fstore_d;
   logic [31:0] dec_fpr_rs2_d;

   logic [31:0]  lsu_result_dc3;
   logic [31:0]  lsu_result_corr_dc4;
   lsu_error_pkt_t lsu_error_pkt_dc3;
   logic         lsu_single_ecc_error_incr;
   logic         lsu_freeze_external_ints_dc3;
   logic         lsu_imprecise_error_load_any;
   logic         lsu_imprecise_error_store_any;
   logic [31:0]  lsu_imprecise_error_addr_any;
   logic         lsu_load_stall_any;
   logic         lsu_store_stall_any;
   logic         lsu_load_ecc_stbuf_full_dc3;
   logic         lsu_idle_any;
   logic         lsu_halt_idle_any;


   logic                                  lsu_nonblock_load_valid_dc3;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_tag_dc3;
   logic                                  lsu_nonblock_load_inv_dc5;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_inv_tag_dc5;
   logic                                  lsu_nonblock_load_data_valid;
   logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]   lsu_nonblock_load_data_tag;
   logic [31:0]                           lsu_nonblock_load_data;

   logic        flush_final_e3;
   logic        i0_flush_final_e3;

   logic        dec_csr_ren_d;

   logic [31:0] exu_csr_rs1_e1;

   logic        dec_tlu_flush_lower_wb;
   logic        dec_tlu_i0_kill_writeb_wb;
   logic        dec_tlu_i1_kill_writeb_wb;
   logic        dec_tlu_fence_i_wb;

   logic dec_tlu_i0_valid_e4;
   logic dec_tlu_i1_valid_e4;
   logic [31:1] dec_tlu_flush_path_wb;
   logic [31:0] dec_tlu_mrac_ff;

   logic        ifu_i0_pc4, ifu_i1_pc4;

   mul_pkt_t  mul_p;

   logic [31:0] exu_mul_result_e3;

   logic dec_i0_mul_d;
   logic dec_i1_mul_d;

   div_pkt_t  div_p;

   logic [31:0] exu_div_result;
   logic exu_div_finish;
   logic exu_div_stall;


   logic dec_i0_div_d;
   logic dec_i1_div_d;


   logic [15:0] ifu_illegal_inst;

   logic        dec_i1_valid_e1;

   logic        dec_div_decode_e4;

   logic [31:1] pred_correct_npc_e2;

   logic [31:0] exu_i0_result_e4;
   logic [31:0] exu_i1_result_e4;

   logic        dec_i0_rs1_bypass_en_e3;
   logic        dec_i0_rs2_bypass_en_e3;
   logic        dec_i1_rs1_bypass_en_e3;
   logic        dec_i1_rs2_bypass_en_e3;
   logic [31:0] i0_rs1_bypass_data_e3;
   logic [31:0] i0_rs2_bypass_data_e3;
   logic [31:0] i1_rs1_bypass_data_e3;
   logic [31:0] i1_rs2_bypass_data_e3;
   logic        dec_i0_sec_decode_e3;
   logic        dec_i1_sec_decode_e3;
   logic [31:1] dec_i0_pc_e3;
   logic [31:1] dec_i1_pc_e3;

   logic        dec_i0_rs1_bypass_en_e2;
   logic        dec_i0_rs2_bypass_en_e2;
   logic        dec_i1_rs1_bypass_en_e2;
   logic        dec_i1_rs2_bypass_en_e2;
   logic [31:0] i0_rs1_bypass_data_e2;
   logic [31:0] i0_rs2_bypass_data_e2;
   logic [31:0] i1_rs1_bypass_data_e2;
   logic [31:0] i1_rs2_bypass_data_e2;

   logic        exu_i0_flush_lower_e4;
   logic        exu_i1_flush_lower_e4;
   logic [31:1] exu_i0_flush_path_e4;
   logic [31:1] exu_i1_flush_path_e4;
   logic        exu_i0_inst_misaligned_e4;
   logic        exu_i1_inst_misaligned_e4;
   logic [31:1] exu_i0_inst_misaligned_addr_e4;
   logic [31:1] exu_i1_inst_misaligned_addr_e4;

   br_tlu_pkt_t dec_tlu_br0_wb_pkt;
   br_tlu_pkt_t dec_tlu_br1_wb_pkt;


   predict_pkt_t  exu_mp_pkt;
   logic [`RV_BHT_GHR_RANGE]  exu_mp_eghr;

   logic [`RV_BHT_GHR_RANGE]  exu_i0_br_fghr_e4;
   logic [1:0]  exu_i0_br_hist_e4;
   logic [1:0]  exu_i0_br_bank_e4;
   logic        exu_i0_br_error_e4;
   logic        exu_i0_br_start_error_e4;
   logic        exu_i0_br_valid_e4;
   logic        exu_i0_br_mp_e4;
   logic        exu_i0_br_ret_e4;
   logic        exu_i0_br_call_e4;
   logic        exu_i0_br_middle_e4;
   logic [`RV_BHT_GHR_RANGE]  exu_i1_br_fghr_e4;

   logic [1:0]  exu_i1_br_hist_e4;
   logic [1:0]  exu_i1_br_bank_e4;
   logic        exu_i1_br_error_e4;
   logic        exu_i1_br_start_error_e4;
   logic        exu_i1_br_valid_e4;
   logic        exu_i1_br_mp_e4;
   logic        exu_i1_br_ret_e4;
   logic        exu_i1_br_call_e4;
   logic        exu_i1_br_middle_e4;

   logic        exu_i0_br_way_e4;
   logic        exu_i1_br_way_e4;
   logic        dec_i0_lsu_decode_d;

   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i0_br_index_e4;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_i1_br_index_e4;


   logic [31:0] i0_result_e4_eff;
   logic [31:0] i1_result_e4_eff;

   logic [31:0] i0_result_e2;

   logic        ifu_i0_icaf;
   logic        ifu_i1_icaf;
   logic        ifu_i0_icaf_second;
   logic        ifu_i1_icaf_second;
   logic        ifu_i0_perr;
   logic        ifu_i1_perr;
   logic        ifu_i0_sbecc;
   logic        ifu_i1_sbecc;
   logic        ifu_i0_dbecc;
   logic        ifu_i1_dbecc;

   br_pkt_t i0_brp;
   br_pkt_t i1_brp;

   predict_pkt_t  i0_predict_p_d;
   predict_pkt_t  i1_predict_p_d;


   logic  dec_tlu_sec_alu_disable;
   logic  dec_tlu_non_blocking_disable;
   logic  dec_tlu_fast_div_disable;
   logic  dec_tlu_bpred_disable;
   logic  dec_tlu_wb_coalescing_disable;
   logic  dec_tlu_ld_miss_byp_wb_disable;
   logic  dec_tlu_sideeffect_posted_disable;

   logic  dec_tlu_misc_clk_override;
   logic  dec_tlu_exu_clk_override;
   logic  dec_tlu_ifu_clk_override;
   logic  dec_tlu_lsu_clk_override;
   logic  dec_tlu_bus_clk_override;
   logic  dec_tlu_dccm_clk_override;
   logic  dec_tlu_icm_clk_override;

   assign        dccm_clk_override = dec_tlu_dccm_clk_override;
   assign        icm_clk_override = dec_tlu_icm_clk_override;


   logic [31:0]            dbg_cmd_addr;
   logic [31:0]            dbg_cmd_wrdata;
   logic                   dbg_cmd_valid;
   logic                   dbg_cmd_write;
   logic [1:0]             dbg_cmd_type;
   logic [1:0]             dbg_cmd_size;
   logic                   dbg_halt_req;
   logic                   dbg_resume_req;
   logic                   dbg_core_rst_l;

   logic [31:0]            dec_dbg_rddata;
   logic                   dec_dbg_cmd_done;
   logic                   dec_dbg_cmd_fail;
   logic                   dec_tlu_mpc_halted_only;
   logic                   dec_tlu_dbg_halted;
   logic                   dec_tlu_pmu_fw_halted;
   logic                   dec_tlu_resume_ack;
   logic                   dec_tlu_debug_mode;
   logic                   dec_debug_wdata_rs1_d;

   logic [4:2]             dec_i0_data_en;
   logic [4:1]             dec_i0_ctl_en;
   logic [4:2]             dec_i1_data_en;
   logic [4:1]             dec_i1_ctl_en;

   logic                   dec_nonblock_load_freeze_dc2;


   logic                   exu_pmu_i0_br_misp;
   logic                   exu_pmu_i0_br_ataken;
   logic                   exu_pmu_i0_pc4;
   logic                   exu_pmu_i1_br_misp;
   logic                   exu_pmu_i1_br_ataken;
   logic                   exu_pmu_i1_pc4;

   logic                   lsu_pmu_misaligned_dc3;
   logic                   lsu_pmu_bus_trxn;
   logic                   lsu_pmu_bus_misaligned;
   logic                   lsu_pmu_bus_error;
   logic                   lsu_pmu_bus_busy;

   logic                   ifu_pmu_fetch_stall;
   logic                   ifu_pmu_fetch_miss;
   logic                   ifu_pmu_fetch_hit;
   logic                   ifu_pmu_bus_error;
   logic                   ifu_pmu_bus_busy;
   logic                   ifu_pmu_bus_trxn;

   logic                   active_state;
   logic                   free_clk, active_clk;
   logic                   dec_pause_state_cg;

   logic                   lsu_nonblock_load_data_error;

   logic [15:0]            ifu_i0_cinst;
   logic [15:0]            ifu_i1_cinst;

   trace_pkt_t  trace_rv_trace_pkt;


   assign active_state = ~dec_pause_state_cg | dec_tlu_flush_lower_wb | dec_tlu_misc_clk_override;

   rvoclkhdr free_cg   ( .en(1'b1),         .l1clk(free_clk), .* );
   rvoclkhdr active_cg ( .en(active_state), .l1clk(active_clk), .* );


   assign dbg_cmd_addr   = '0;
   assign dbg_cmd_wrdata = '0;
   assign dbg_cmd_valid  = 1'b0;
   assign dbg_cmd_write  = 1'b0;
   assign dbg_cmd_type   = '0;
   assign dbg_cmd_size   = '0;
   assign dbg_halt_req   = 1'b0;
   assign dbg_resume_req = 1'b0;
   assign dbg_core_rst_l = 1'b1;

   assign core_rst_l = rst_l & (dbg_core_rst_l | scan_mode);


   ifu ifu (
       .clk_override(dec_tlu_ifu_clk_override),
       .rst_l(core_rst_l),
       .*
   );

   exu exu (
      .clk_override(dec_tlu_exu_clk_override),
      .rst_l(core_rst_l),
      .*
   );

   lsu lsu (
      .clk_override(dec_tlu_lsu_clk_override),
      .rst_l(core_rst_l),
      .*
   );


   logic        mexintpend;
   logic        mhwakeup;

   logic        dec_tlu_claim_ack_wb;

   dec dec (
            .dbg_cmd_wrdata(dbg_cmd_wrdata[1:0]),
            .rst_l(core_rst_l),
            .*
            );


   assign mexintpend  = extintsrc_req[1];
   assign mhwakeup    = 1'b0;


      assign trace_rv_i_insn_ip[63:0]     = trace_rv_trace_pkt.trace_rv_i_insn_ip[63:0];

      assign trace_rv_i_address_ip[63:0]  = trace_rv_trace_pkt.trace_rv_i_address_ip[63:0];

      assign trace_rv_i_valid_ip[2:0]     = trace_rv_trace_pkt.trace_rv_i_valid_ip[2:0];

      assign trace_rv_i_exception_ip[2:0] = trace_rv_trace_pkt.trace_rv_i_exception_ip[2:0];

      assign trace_rv_i_ecause_ip[4:0]    = trace_rv_trace_pkt.trace_rv_i_ecause_ip[4:0];

      assign trace_rv_i_interrupt_ip[2:0] = trace_rv_trace_pkt.trace_rv_i_interrupt_ip[2:0];

      assign trace_rv_i_tval_ip[31:0]     = trace_rv_trace_pkt.trace_rv_i_tval_ip[31:0];


endmodule

