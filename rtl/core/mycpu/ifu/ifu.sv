

module ifu
   import mycpu_types::*;
(
   input logic free_clk,
   input logic active_clk,
   input logic clk,
   input logic clk_override,
   input logic rst_l,

   input logic dec_ib3_valid_d, dec_ib2_valid_d,

   input logic dec_ib0_valid_eff_d,
   input logic dec_ib1_valid_eff_d,

   input logic        exu_i0_br_ret_e4,
   input logic        exu_i1_br_ret_e4,
   input logic        exu_i0_br_call_e4,
   input logic        exu_i1_br_call_e4,

   input logic exu_flush_final,
   input logic dec_tlu_flush_err_wb ,
   input logic dec_tlu_flush_noredir_wb,
   input logic dec_tlu_dbg_halted,
   input logic dec_tlu_pmu_fw_halted,
   input logic [31:1] exu_flush_path_final,
   input logic        exu_flush_upper_e2,

   input logic [31:0]  dec_tlu_mrac_ff ,
   input logic         dec_tlu_fence_i_wb,
   input logic         dec_tlu_flush_leak_one_wb,

   input logic                       dec_tlu_bpred_disable,
   input logic                       dec_tlu_core_ecc_disable,

   input  logic                      ifu_bus_clk_en,


   output logic [1:0] ifu_pmu_instr_aligned,
   output logic       ifu_pmu_align_stall,
   output logic       ifu_pmu_fetch_stall,


   output logic [`RV_ICCM_BITS-1:2]               iccm_rw_addr,
   output logic                      iccm_rden,

   input  logic [127:0]              iccm_rd_data,


   output logic       ifu_pmu_fetch_miss,
   output logic       ifu_pmu_fetch_hit,
   output logic       ifu_pmu_bus_error,
   output logic       ifu_pmu_bus_busy,
   output logic       ifu_pmu_bus_trxn,


   output logic  ifu_i0_valid,
   output logic  ifu_i1_valid,
   output logic  ifu_i0_icaf,
   output logic  ifu_i1_icaf,
   output logic  ifu_i0_icaf_second,
   output logic  ifu_i1_icaf_second,
   output logic  ifu_i0_perr,
   output logic  ifu_i1_perr,
   output logic  ifu_i0_sbecc,
   output logic  ifu_i1_sbecc,
   output logic  ifu_i0_dbecc,
   output logic  ifu_i1_dbecc,
   output logic[31:0] ifu_i0_instr,
   output logic[31:0] ifu_i1_instr,
   output logic[31:1] ifu_i0_pc,
   output logic[31:1] ifu_i1_pc,
   output logic ifu_i0_pc4,
   output logic ifu_i1_pc4,
   output logic [15:0] ifu_illegal_inst,

   output logic ifu_miss_state_idle,


   output br_pkt_t i0_brp,
   output br_pkt_t i1_brp,

   input predict_pkt_t  exu_mp_pkt,
   input logic [`RV_BHT_GHR_RANGE] exu_mp_eghr,

   input br_tlu_pkt_t dec_tlu_br0_wb_pkt,
   input br_tlu_pkt_t dec_tlu_br1_wb_pkt,
   input dec_tlu_flush_lower_wb,

   input rets_pkt_t exu_rets_e1_pkt,
   input rets_pkt_t exu_rets_e4_pkt,


   output logic [15:0] ifu_i0_cinst,
   output logic [15:0] ifu_i1_cinst,


   input logic scan_mode
   );

   localparam TAGWIDTH = 2 ;
   localparam IDWIDTH  = 2 ;

   logic                   ifu_fb_consume1, ifu_fb_consume2;
   logic [31:1]            ifc_fetch_addr_f2;
   logic                   ifc_fetch_uncacheable_f1;

   logic [7:0]   ifu_fetch_val;
   logic [31:1]  ifu_fetch_pc;

   logic [31:1] ifc_fetch_addr_f1;

   logic        critical_word_ready;
   logic        ifc_iccm_access_f1;
   logic        ifc_region_acc_fault_f1;
   logic [7:0]  fetch_access_fault_f2;
   logic        ifu_ic_mb_empty;


   logic tcm_fetch_valid_f2;


   logic [7:0]  ifu_bp_way_f2;
   logic  ifu_bp_kill_next_f2;
   logic [31:1] ifu_bp_btb_target_f2;
   logic [7:1]  ifu_bp_inst_mask_f2;
   logic [7:0]  ifu_bp_hist1_f2;
   logic [7:0]  ifu_bp_hist0_f2;
   logic [11:0] ifu_bp_poffset_f2;
   logic [7:0]  ifu_bp_ret_f2;
   logic [7:0]  ifu_bp_pc4_f2;
   logic [7:0]  ifu_bp_valid_f2;
   logic [`RV_BHT_GHR_RANGE] ifu_bp_fghr_f2;

   logic [7:0]   fetch_byte_valid_f2;
   logic [127:0] fetch_data_f2;
   logic [127:0] ifu_fetch_data;
   logic ifc_fetch_req_f1_raw, ifc_fetch_req_f1, ifc_fetch_req_f2;
   logic fetch_parity_error;
   logic iccm_rd_ecc_single_err;
   logic [7:0] iccm_rd_ecc_double_err;

   fetch_error_pkt_t fetch_error_f2;

   logic         fetch_parity_qualifier_f2 ;
   logic [16:2]  ifu_fetch_error_index;
   logic         ifu_fetch_parity_error_valid;
   logic         ifu_fetch_single_bit_error;

   assign ifu_fetch_data[127:0] = fetch_data_f2[127:0];
   assign ifu_fetch_val[7:0] = fetch_byte_valid_f2[7:0];
   assign ifu_fetch_pc[31:1] = ifc_fetch_addr_f2[31:1];


   ifu_ifc_ctl ifc (.*
                    );


   ifu_aln_ctl aln (.*
                    );


   ifu_bp_ctl bp (.*);


   ifu_mem_ctl mem_ctl
     (.*,
      .fetch_addr_f1(ifc_fetch_addr_f1),
      .ifu_fetch_error_index(ifu_fetch_error_index[16:6]),
      .tcm_fetch_valid_f2(tcm_fetch_valid_f2),
      .fetch_data_f2(fetch_data_f2[127:0])
      );


endmodule
