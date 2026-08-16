



module ifu_mem_ctl
   import mycpu_types::*;
(
   input logic clk,
   input logic free_clk,
   input logic active_clk,
   input logic rst_l,

   input logic                       exu_flush_final,
   input logic                       dec_tlu_flush_err_wb,

   input logic [31:1]                fetch_addr_f1,
   input logic                       ifc_fetch_uncacheable_f1,
   input logic                       ifc_fetch_req_f1,
   input logic                       ifc_fetch_req_f1_raw,
   input logic                       ifc_iccm_access_f1,
   input logic                       ifc_region_acc_fault_f1,
   input logic                       dec_tlu_fence_i_wb,


   input logic [16:6]                ifu_fetch_error_index,
   input logic                       ifu_fetch_parity_error_valid,
   input logic                       ifu_fetch_single_bit_error,
   input logic [7:1]                 ifu_bp_inst_mask_f2,

   output logic                      ifu_miss_state_idle,
   output logic                      ifu_ic_mb_empty,


   output logic                      ifu_pmu_fetch_miss,
   output logic                      ifu_pmu_fetch_hit,
   output logic                      ifu_pmu_bus_error,
   output logic                      ifu_pmu_bus_busy,
   output logic                      ifu_pmu_bus_trxn,

   input  logic                      ifu_bus_clk_en,


   output logic [`RV_ICCM_BITS-1:2]  iccm_rw_addr,
   output logic                      iccm_rden,

   input  logic [127:0]              iccm_rd_data,


   output logic                      tcm_fetch_valid_f2,
   output logic                      critical_word_ready,
   output logic  [7:0]               fetch_access_fault_f2,
   output logic                      fetch_parity_error,
   output logic                      iccm_rd_ecc_single_err,
   output logic  [7:0]               iccm_rd_ecc_double_err,
   output logic [7:0]                fetch_byte_valid_f2,
   output logic [127:0]              fetch_data_f2,
   output fetch_error_pkt_t           fetch_error_f2 ,
   output logic                      fetch_parity_qualifier_f2  ,
   input  logic                      dec_tlu_core_ecc_disable,


   input  logic         scan_mode
   );

`include "core_params.svh"


   logic       tcm_fetch_req_f2;
   logic       tcm_iccm_access_f2;
   logic       tcm_access_fault_f2;
   logic [2:0] tcm_vaddr_f2;
   rvdff #(6) tcm_fetch_f1_f2_ff (.*,
                                   .clk(active_clk),
                                   .din({ifc_fetch_req_f1, ifc_iccm_access_f1,
                                         ~ifc_iccm_access_f1, fetch_addr_f1[3:1]}),
                                   .dout({tcm_fetch_req_f2, tcm_iccm_access_f2,
                                          tcm_access_fault_f2, tcm_vaddr_f2[2:0]}));

   assign iccm_rw_addr[`RV_ICCM_BITS-1:2] = fetch_addr_f1[`RV_ICCM_BITS-1:2];
   assign iccm_rden = ifc_fetch_req_f1 & ifc_iccm_access_f1;

   assign tcm_fetch_valid_f2 = tcm_fetch_req_f2 & ~exu_flush_final;
   assign fetch_data_f2[127:0] = iccm_rd_data[127:0];
   assign fetch_access_fault_f2[7:0] = {8{tcm_fetch_req_f2 &
                                          tcm_access_fault_f2 &
                                          ~exu_flush_final}};


   assign fetch_byte_valid_f2[7] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[7] &
                               ~tcm_vaddr_f2[2] & ~tcm_vaddr_f2[1] & ~tcm_vaddr_f2[0];
   assign fetch_byte_valid_f2[6] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[6] &
                               ~tcm_vaddr_f2[2] & ~tcm_vaddr_f2[1];
   assign fetch_byte_valid_f2[5] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[5] &
                               ~tcm_vaddr_f2[2] & (~tcm_vaddr_f2[0] | ~tcm_vaddr_f2[1]);
   assign fetch_byte_valid_f2[4] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[4] & ~tcm_vaddr_f2[2];
   assign fetch_byte_valid_f2[3] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[3] &
                               (~tcm_vaddr_f2[1] & ~tcm_vaddr_f2[0] | ~tcm_vaddr_f2[2]);
   assign fetch_byte_valid_f2[2] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[2] &
                               (~tcm_vaddr_f2[1] | ~tcm_vaddr_f2[2]);
   assign fetch_byte_valid_f2[1] = tcm_fetch_valid_f2 & ifu_bp_inst_mask_f2[1] &
                               (~tcm_vaddr_f2[0] | ~tcm_vaddr_f2[1] | ~tcm_vaddr_f2[2]);
   assign fetch_byte_valid_f2[0] = tcm_fetch_valid_f2;

   assign ifu_miss_state_idle = 1'b1;
   assign ifu_ic_mb_empty     = 1'b1;
   assign critical_word_ready      = 1'b0;

   assign ifu_pmu_fetch_miss   = 1'b0;
   assign ifu_pmu_fetch_hit    = tcm_fetch_req_f2 & tcm_iccm_access_f2 & ~exu_flush_final;
   assign ifu_pmu_bus_error = 1'b0;
   assign ifu_pmu_bus_busy  = 1'b0;
   assign ifu_pmu_bus_trxn  = 1'b0;

   assign fetch_parity_error  = 1'b0;
   assign iccm_rd_ecc_single_err  = 1'b0;
   assign iccm_rd_ecc_double_err  = '0;
   assign fetch_error_f2             = '0;
   assign fetch_parity_qualifier_f2     = 1'b0;
endmodule

