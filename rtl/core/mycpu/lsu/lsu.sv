

module lsu
   import mycpu_types::*;
(

   input logic [31:0]                      i0_result_e4_eff,
   input logic [31:0]                      i1_result_e4_eff,
   input logic [31:0]                      i0_result_e2,

   input logic                             flush_final_e3,
   input logic                             i0_flush_final_e3,
   input logic                             dec_tlu_flush_lower_wb,
   input logic                             dec_tlu_i0_kill_writeb_wb,
   input logic                             dec_tlu_i1_kill_writeb_wb,
   input logic                             dec_tlu_cancel_e4,


   input logic                             dec_tlu_wb_coalescing_disable,
   input logic                             dec_tlu_ld_miss_byp_wb_disable,
   input logic                             dec_tlu_sideeffect_posted_disable,
   input logic                             dec_tlu_core_ecc_disable,

   input logic [31:0]                      exu_lsu_rs1_d,
   input logic [31:0]                      exu_lsu_rs2_d,
   input logic [11:0]                      dec_lsu_offset_d,

   input                                   lsu_pkt_t lsu_p,
   input logic                             dec_i0_lsu_decode_d,
   input logic [31:0]                      dec_tlu_mrac_ff,

   output logic [31:0]                     lsu_result_dc3,
   output logic                            lsu_single_ecc_error_incr,
   output logic [31:0]                     lsu_result_corr_dc4,
   output logic                            lsu_freeze_dc3,
   output logic                            lsu_load_stall_any,
   output logic                            lsu_store_stall_any,
   output logic                            lsu_load_ecc_stbuf_full_dc3,
   output logic                            lsu_idle_any,
   output logic                            lsu_halt_idle_any,

   output lsu_error_pkt_t                  lsu_error_pkt_dc3,
   output logic                            lsu_freeze_external_ints_dc3,
   output logic                            lsu_imprecise_error_load_any,
   output logic                            lsu_imprecise_error_store_any,
   output logic [31:0]                     lsu_imprecise_error_addr_any,


   input  logic                                 dec_nonblock_load_freeze_dc2,
   output logic                                 lsu_nonblock_load_valid_dc3,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_dc3,
   output logic                                 lsu_nonblock_load_inv_dc5,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_dc5,
   output logic                                 lsu_nonblock_load_data_valid,
   output logic                                 lsu_nonblock_load_data_error,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,
   output logic [31:0]                          lsu_nonblock_load_data,

   output logic                            lsu_pmu_misaligned_dc3,
   output logic                            lsu_pmu_bus_trxn,
   output logic                            lsu_pmu_bus_misaligned,
   output logic                            lsu_pmu_bus_error,
   output logic                            lsu_pmu_bus_busy,


   input                                   trigger_pkt_t [3:0] trigger_pkt_any,
   output logic [3:0]                      lsu_trigger_match_dc3,


   output logic                            dccm_wren,
   output logic                            dccm_rden,
   output logic [`RV_DCCM_BITS-1:0]        dccm_wr_addr,
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_lo,
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_hi,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0] dccm_wr_data,

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,


   output logic                            lsu_mmio_valid,
   output logic                            lsu_mmio_write,
   output logic [31:0]                     lsu_mmio_addr,
   output logic [31:0]                     lsu_mmio_wdata,
   output logic [3:0]                      lsu_mmio_wstrb,
   input  logic                            lsu_mmio_ready,
   input  logic [31:0]                     lsu_mmio_rdata,
   input  logic                            lsu_mmio_error,

   input logic                             lsu_bus_clk_en,

   input logic                             clk_override,
   input logic                             scan_mode,
   input logic                             clk,
   input logic                             free_clk,
   input logic                             rst_l

   );


`include "core_params.svh"

   logic        lsu_dccm_rden_dc3;
   logic [63:0] store_data_dc2;
   logic [63:0] store_data_dc3;
   logic [31:0] store_data_dc4;
   logic [31:0] store_data_dc5;
   logic [31:0] store_ecc_datafn_hi_dc3;
   logic [31:0] store_ecc_datafn_lo_dc3;

   logic        single_ecc_error_hi_dc3, single_ecc_error_lo_dc3;
   logic        lsu_single_ecc_error_dc3, lsu_single_ecc_error_dc4, lsu_single_ecc_error_dc5;
   logic        lsu_double_ecc_error_dc3;

   logic [31:0] dccm_data_hi_dc3;
   logic [31:0] dccm_data_lo_dc3;
   logic [6:0]  dccm_data_ecc_hi_dc3;
   logic [6:0]  dccm_data_ecc_lo_dc3;

   logic [31:0] lsu_ld_data_dc3;
   logic [31:0] lsu_ld_data_corr_dc3;

   logic [31:0] lsu_addr_dc1, lsu_addr_dc2, lsu_addr_dc3, lsu_addr_dc4, lsu_addr_dc5;
   logic [31:0] end_addr_dc1, end_addr_dc2, end_addr_dc3, end_addr_dc4, end_addr_dc5;

   lsu_pkt_t    lsu_pkt_dc1, lsu_pkt_dc2, lsu_pkt_dc3, lsu_pkt_dc4, lsu_pkt_dc5;
   logic        lsu_i0_valid_dc1, lsu_i0_valid_dc2, lsu_i0_valid_dc3, lsu_i0_valid_dc4, lsu_i0_valid_dc5;


   logic        isldst_dc1, dccm_ldst_dc2, dccm_ldst_dc3;
   logic        store_stbuf_reqvld_dc3;
   logic        load_stbuf_reqvld_dc3;
   logic        ldst_stbuf_reqvld_dc3;
   logic        lsu_commit_dc5;
   logic        lsu_exc_dc2;

   logic        addr_in_dccm_dc1, addr_in_dccm_dc2, addr_in_dccm_dc3;
   logic        addr_external_dc1, addr_external_dc2, addr_external_dc3, addr_external_dc4, addr_external_dc5;

   logic                       stbuf_reqvld_any;
   logic                       stbuf_reqvld_flushed_any;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_byteen_any;
   logic [LSU_SB_BITS-1:0]     stbuf_addr_any;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_data_any;


   logic [DCCM_ECC_WIDTH-1:0] stbuf_ecc_any;

   logic                       lsu_cmpen_dc2;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_fwddata_hi_dc3;
   logic [DCCM_DATA_WIDTH-1:0] stbuf_fwddata_lo_dc3;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_hi_dc3;
   logic [DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_lo_dc3;

   logic        lsu_stbuf_commit_any;
   logic        lsu_stbuf_empty_any;
   logic        lsu_stbuf_full_any;


   logic        lsu_busreq_dc5;
   logic        lsu_bus_buffer_pend_any;
   logic        lsu_bus_buffer_empty_any;
   logic        lsu_bus_buffer_full_any;
   logic        lsu_busreq_dc2;
   logic [31:0] bus_read_data_dc3;
   logic        ld_bus_error_dc3;
   logic [31:0] ld_bus_error_addr_dc3;

   logic        flush_dc2_up, flush_dc3, flush_dc4, flush_dc5, flush_prior_dc5;
   logic        is_sideeffects_dc2, is_sideeffects_dc3;


   logic        lsu_c1_dc3_clk, lsu_c1_dc4_clk, lsu_c1_dc5_clk;
   logic        lsu_c2_dc3_clk, lsu_c2_dc4_clk, lsu_c2_dc5_clk;
   logic        lsu_freeze_c1_dc2_clk, lsu_freeze_c1_dc3_clk;
   logic        lsu_freeze_c1_dc1_clken, lsu_freeze_c1_dc2_clken, lsu_freeze_c1_dc3_clken;
   logic        lsu_freeze_c2_dc1_clken, lsu_freeze_c2_dc2_clken, lsu_freeze_c2_dc3_clken, lsu_freeze_c2_dc4_clken;
   logic        lsu_store_c1_dc1_clken, lsu_store_c1_dc2_clken, lsu_store_c1_dc3_clken, lsu_store_c1_dc4_clk, lsu_store_c1_dc5_clk;

   logic        lsu_freeze_c2_dc1_clk, lsu_freeze_c2_dc2_clk, lsu_freeze_c2_dc3_clk, lsu_freeze_c2_dc4_clk;
   logic        lsu_stbuf_c1_clk;
   logic        lsu_bus_ibuf_c1_clk, lsu_bus_obuf_c1_clk, lsu_bus_buf_c1_clk;
   logic        lsu_dccm_c1_dc3_clk, lsu_dccm_c1_dc3_clken;
   logic        lsu_busm_clk;
   logic        lsu_free_c2_clk;


   lsu_lsc_ctl lsu_lsc_ctl(.*);


   assign lsu_store_stall_any = lsu_stbuf_full_any | lsu_bus_buffer_full_any;
   assign lsu_load_stall_any  = lsu_bus_buffer_full_any;


   assign flush_dc2_up = flush_final_e3 | i0_flush_final_e3 | dec_tlu_flush_lower_wb;
   assign flush_dc3    = (flush_final_e3 & i0_flush_final_e3) | dec_tlu_flush_lower_wb;
   assign flush_dc4    = dec_tlu_flush_lower_wb;
   assign flush_dc5    = (dec_tlu_i0_kill_writeb_wb | (dec_tlu_i1_kill_writeb_wb & ~lsu_i0_valid_dc5));
   assign flush_prior_dc5 = dec_tlu_i0_kill_writeb_wb & ~lsu_i0_valid_dc5;


   assign lsu_idle_any = ~(lsu_pkt_dc1.valid | lsu_pkt_dc2.valid | lsu_pkt_dc3.valid | lsu_pkt_dc4.valid | lsu_pkt_dc5.valid) &
                         lsu_bus_buffer_empty_any & lsu_stbuf_empty_any;

   assign lsu_halt_idle_any = lsu_idle_any;


   assign store_stbuf_reqvld_dc3 = lsu_pkt_dc3.valid & lsu_pkt_dc3.store & addr_in_dccm_dc3 & ~flush_dc3 & ~lsu_freeze_dc3;
   assign load_stbuf_reqvld_dc3  = lsu_pkt_dc3.valid & lsu_pkt_dc3.load & addr_in_dccm_dc3 & lsu_single_ecc_error_dc3 & ~flush_dc3 & ~lsu_freeze_dc3;


   assign isldst_dc1 = lsu_pkt_dc1.valid & (lsu_pkt_dc1.load | lsu_pkt_dc1.store);
   assign dccm_ldst_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & addr_in_dccm_dc2;
   assign dccm_ldst_dc3 = lsu_pkt_dc3.valid & (lsu_pkt_dc3.load | lsu_pkt_dc3.store) & addr_in_dccm_dc3;


   assign lsu_cmpen_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & addr_in_dccm_dc2;


   assign lsu_busreq_dc2 = lsu_pkt_dc2.valid & (lsu_pkt_dc2.load | lsu_pkt_dc2.store) & addr_external_dc2 & ~flush_dc2_up & ~lsu_exc_dc2;


   assign lsu_pmu_misaligned_dc3 = lsu_pkt_dc3.valid & ((lsu_pkt_dc3.half & lsu_addr_dc3[0]) | (lsu_pkt_dc3.word & (|lsu_addr_dc3[1:0])));


   lsu_dccm_ctl dccm_ctl (
      .lsu_addr_dc1(lsu_addr_dc1[31:0]),
      .end_addr_dc1(end_addr_dc1[DCCM_BITS-1:0]),
      .lsu_addr_dc3(lsu_addr_dc3[DCCM_BITS-1:0]),
      .*
   );

   lsu_stbuf stbuf(
      .lsu_addr_dc1(lsu_addr_dc1[LSU_SB_BITS-1:0]),
      .end_addr_dc1(end_addr_dc1[LSU_SB_BITS-1:0]),
      .lsu_addr_dc2(lsu_addr_dc2[LSU_SB_BITS-1:0]),
      .end_addr_dc2(end_addr_dc2[LSU_SB_BITS-1:0]),
      .lsu_addr_dc3(lsu_addr_dc3[LSU_SB_BITS-1:0]),
      .end_addr_dc3(end_addr_dc3[LSU_SB_BITS-1:0]),
      .*

   );

   logic [7:0] no_ecc_ldst_byteen_dc3;
   logic [7:0] no_ecc_store_byteen_dc3;
   logic [7:0] no_ecc_store_byteen_ext_dc3;
   logic [3:0] no_ecc_store_byteen_hi_dc3, no_ecc_store_byteen_lo_dc3;
   logic [63:0] no_ecc_store_data_ext_dc3;
   logic [31:0] no_ecc_store_data_hi_dc3, no_ecc_store_data_lo_dc3;

   assign no_ecc_ldst_byteen_dc3[7:0] = ({8{lsu_pkt_dc3.by}}    & 8'b0000_0001) |
                                          ({8{lsu_pkt_dc3.half}}  & 8'b0000_0011) |
                                          ({8{lsu_pkt_dc3.word}}  & 8'b0000_1111);
   assign no_ecc_store_byteen_dc3[7:0] = no_ecc_ldst_byteen_dc3[7:0] &
                                          {8{lsu_pkt_dc3.store}};
   assign no_ecc_store_byteen_ext_dc3[7:0] = no_ecc_store_byteen_dc3[7:0] <<
                                              lsu_addr_dc3[1:0];
   assign no_ecc_store_byteen_hi_dc3[3:0] = no_ecc_store_byteen_ext_dc3[7:4];
   assign no_ecc_store_byteen_lo_dc3[3:0] = no_ecc_store_byteen_ext_dc3[3:0];
   assign no_ecc_store_data_ext_dc3[63:0] = store_data_dc3[63:0] <<
                                             {lsu_addr_dc3[1:0], 3'b000};
   assign no_ecc_store_data_hi_dc3[31:0] = no_ecc_store_data_ext_dc3[63:32];
   assign no_ecc_store_data_lo_dc3[31:0] = no_ecc_store_data_ext_dc3[31:0];

   for (genvar noecc_byte = 0; noecc_byte < 4; noecc_byte++) begin: no_ecc_store_merge
      assign store_ecc_datafn_hi_dc3[(8*noecc_byte)+7:(8*noecc_byte)] =
               no_ecc_store_byteen_hi_dc3[noecc_byte] ? no_ecc_store_data_hi_dc3[(8*noecc_byte)+7:(8*noecc_byte)] :
               stbuf_fwdbyteen_hi_dc3[noecc_byte]      ? stbuf_fwddata_hi_dc3[(8*noecc_byte)+7:(8*noecc_byte)] :
                                                        dccm_data_hi_dc3[(8*noecc_byte)+7:(8*noecc_byte)];
      assign store_ecc_datafn_lo_dc3[(8*noecc_byte)+7:(8*noecc_byte)] =
               no_ecc_store_byteen_lo_dc3[noecc_byte] ? no_ecc_store_data_lo_dc3[(8*noecc_byte)+7:(8*noecc_byte)] :
               stbuf_fwdbyteen_lo_dc3[noecc_byte]      ? stbuf_fwddata_lo_dc3[(8*noecc_byte)+7:(8*noecc_byte)] :
                                                        dccm_data_lo_dc3[(8*noecc_byte)+7:(8*noecc_byte)];
   end

   assign stbuf_ecc_any               = '0;
   assign single_ecc_error_hi_dc3     = 1'b0;
   assign single_ecc_error_lo_dc3     = 1'b0;
   assign lsu_single_ecc_error_dc3    = 1'b0;
   assign lsu_double_ecc_error_dc3    = 1'b0;

   lsu_trigger trigger (
      .store_data_dc3(store_data_dc3[31:0]),
      .*
   );


   lsu_clkdomain clkdomain (.*);


   lsu_bus_intf bus_intf (.*);


   rvdff_fpga #(1) lsu_i0_valid_dc1ff    (.*, .din(dec_i0_lsu_decode_d), .dout(lsu_i0_valid_dc1), .clk(lsu_freeze_c2_dc1_clk), .clken(lsu_freeze_c2_dc1_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc2ff    (.*, .din(lsu_i0_valid_dc1),    .dout(lsu_i0_valid_dc2), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc3ff    (.*, .din(lsu_i0_valid_dc2),    .dout(lsu_i0_valid_dc3), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk));
   rvdff_fpga #(1) lsu_i0_valid_dc4ff    (.*, .din(lsu_i0_valid_dc3),    .dout(lsu_i0_valid_dc4), .clk(lsu_freeze_c2_dc4_clk), .clken(lsu_freeze_c2_dc4_clken), .rawclk(clk));

   rvdff #(1) lsu_i0_valid_dc5ff    (.*, .din(lsu_i0_valid_dc4),    .dout(lsu_i0_valid_dc5), .clk(lsu_c2_dc5_clk));
   rvdff #(1) lsu_single_ecc_err_dc4(.*, .din(lsu_single_ecc_error_dc3), .dout(lsu_single_ecc_error_dc4), .clk(lsu_c2_dc4_clk));
   rvdff #(1) lsu_single_ecc_err_dc5(.*, .din(lsu_single_ecc_error_dc4), .dout(lsu_single_ecc_error_dc5), .clk(lsu_c2_dc5_clk));


endmodule
