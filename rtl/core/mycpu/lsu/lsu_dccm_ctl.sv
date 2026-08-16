

module lsu_dccm_ctl
   import mycpu_types::*;
(
   input logic                             lsu_freeze_c2_dc2_clk,
   input logic                             lsu_freeze_c2_dc3_clk,
   input logic                             lsu_freeze_c2_dc2_clken,
   input logic                             lsu_freeze_c2_dc3_clken,
   input logic                             lsu_dccm_c1_dc3_clk,
   input logic                             lsu_dccm_c1_dc3_clken,

   input logic                             rst_l,
   input logic                             clk,
   input logic                             lsu_freeze_dc3,

   input                                   lsu_pkt_t lsu_pkt_dc3,
   input                                   lsu_pkt_t lsu_pkt_dc1,
   input logic                             addr_in_dccm_dc1,
   input logic [31:0]                      lsu_addr_dc1,
   input logic [`RV_DCCM_BITS-1:0]         end_addr_dc1,
   input logic [`RV_DCCM_BITS-1:0]         lsu_addr_dc3,

   input logic                             stbuf_reqvld_any,
   input logic [`RV_LSU_SB_BITS-1:0]       stbuf_addr_any,

   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_data_any,
   input logic [`RV_DCCM_ECC_WIDTH-1:0]    stbuf_ecc_any,
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_fwddata_hi_dc3,
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   stbuf_fwddata_lo_dc3,
   input logic [`RV_DCCM_BYTE_WIDTH-1:0]   stbuf_fwdbyteen_hi_dc3,
   input logic [`RV_DCCM_BYTE_WIDTH-1:0]   stbuf_fwdbyteen_lo_dc3,

   input logic                             lsu_double_ecc_error_dc3,
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   store_ecc_datafn_hi_dc3,
   input logic [`RV_DCCM_DATA_WIDTH-1:0]   store_ecc_datafn_lo_dc3,

   output logic [`RV_DCCM_DATA_WIDTH-1:0]  dccm_data_hi_dc3,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  dccm_data_lo_dc3,
   output logic [`RV_DCCM_ECC_WIDTH-1:0]   dccm_data_ecc_hi_dc3,
   output logic [`RV_DCCM_ECC_WIDTH-1:0]   dccm_data_ecc_lo_dc3,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  lsu_ld_data_dc3,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]  lsu_ld_data_corr_dc3,
   output logic                            lsu_stbuf_commit_any,
   output logic                            lsu_dccm_rden_dc3,


   output logic                            dccm_wren,
   output logic                            dccm_rden,
   output logic [`RV_DCCM_BITS-1:0]        dccm_wr_addr,
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_lo,
   output logic [`RV_DCCM_BITS-1:0]        dccm_rd_addr_hi,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0] dccm_wr_data,

   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,

   input logic                             scan_mode
);

`include "core_params.svh"


   localparam int DCCM_WIDTH_BITS = $clog2(DCCM_BYTE_WIDTH);

   logic lsu_dccm_rden_dc1, lsu_dccm_rden_dc2;
   logic [31:0] dccm_data_hi_dc2, dccm_data_lo_dc2;
   logic [63:0] dccm_dout_dc3;
   logic [63:0] stbuf_fwddata_dc3;
   logic [7:0]  stbuf_fwdbyteen_dc3;
   logic [63:0] lsu_rdata_dc3;
   logic [63:32] lsu_ld_data_dc3_nc, lsu_ld_data_corr_dc3_nc;

   assign {lsu_ld_data_dc3_nc[63:32], lsu_ld_data_dc3[31:0]} =
                                             lsu_rdata_dc3[63:0] >> 8*lsu_addr_dc3[1:0];
   assign {lsu_ld_data_corr_dc3_nc[63:32], lsu_ld_data_corr_dc3[31:0]} =
                                             lsu_rdata_dc3[63:0] >> 8*lsu_addr_dc3[1:0];

   assign dccm_dout_dc3[63:0]       = {dccm_data_hi_dc3, dccm_data_lo_dc3};
   assign stbuf_fwddata_dc3[63:0]    = {stbuf_fwddata_hi_dc3, stbuf_fwddata_lo_dc3};
   assign stbuf_fwdbyteen_dc3[7:0]   = {stbuf_fwdbyteen_hi_dc3, stbuf_fwdbyteen_lo_dc3};

   for (genvar noecc_byte = 0; noecc_byte < 8; noecc_byte++) begin: no_ecc_load_forward
      assign lsu_rdata_dc3[(8*noecc_byte)+7:(8*noecc_byte)] =
               stbuf_fwdbyteen_dc3[noecc_byte] ? stbuf_fwddata_dc3[(8*noecc_byte)+7:(8*noecc_byte)] :
                                                 dccm_dout_dc3[(8*noecc_byte)+7:(8*noecc_byte)];
   end

   assign lsu_stbuf_commit_any = stbuf_reqvld_any & ~lsu_freeze_dc3 &
                                  (~lsu_dccm_rden_dc1 |
                                   ~((stbuf_addr_any[DCCM_WIDTH_BITS+:DCCM_BANK_BITS] ==
                                      lsu_addr_dc1[DCCM_WIDTH_BITS+:DCCM_BANK_BITS]) |
                                     (stbuf_addr_any[DCCM_WIDTH_BITS+:DCCM_BANK_BITS] ==
                                      end_addr_dc1[DCCM_WIDTH_BITS+:DCCM_BANK_BITS])));


   assign lsu_dccm_rden_dc1 = lsu_pkt_dc1.valid &
                               (lsu_pkt_dc1.load |
                                (lsu_pkt_dc1.store &
                                  (~lsu_pkt_dc1.word |
                                  (lsu_addr_dc1[1:0] != 2'b0)))) &
                               addr_in_dccm_dc1;

   assign dccm_wren                         = lsu_stbuf_commit_any;
   assign dccm_rden                         = lsu_dccm_rden_dc1 & addr_in_dccm_dc1;
   assign dccm_wr_addr[DCCM_BITS-1:0]       = stbuf_addr_any[DCCM_BITS-1:0];
   assign dccm_rd_addr_lo[DCCM_BITS-1:0]    = lsu_addr_dc1[DCCM_BITS-1:0];
   assign dccm_rd_addr_hi[DCCM_BITS-1:0]    = end_addr_dc1[DCCM_BITS-1:0];
   assign dccm_wr_data[DCCM_FDATA_WIDTH-1:0] = stbuf_data_any[DCCM_DATA_WIDTH-1:0];

   assign dccm_data_lo_dc2[31:0] = dccm_rd_data_lo[31:0];
   assign dccm_data_hi_dc2[31:0] = dccm_rd_data_hi[31:0];

   rvdff_fpga #(1) dccm_rden_dc2ff (.*,
                                     .din(lsu_dccm_rden_dc1),
                                     .dout(lsu_dccm_rden_dc2),
                                     .clk(lsu_freeze_c2_dc2_clk),
                                     .clken(lsu_freeze_c2_dc2_clken),
                                     .rawclk(clk));
   rvdff_fpga #(1) dccm_rden_dc3ff (.*,
                                     .din(lsu_dccm_rden_dc2),
                                     .dout(lsu_dccm_rden_dc3),
                                     .clk(lsu_freeze_c2_dc3_clk),
                                     .clken(lsu_freeze_c2_dc3_clken),
                                     .rawclk(clk));
   rvdff_fpga #(32) dccm_data_hi_ff (.*,
                                      .din(dccm_data_hi_dc2),
                                      .dout(dccm_data_hi_dc3),
                                      .clk(lsu_dccm_c1_dc3_clk),
                                      .clken(lsu_dccm_c1_dc3_clken),
                                      .rawclk(clk));
   rvdff_fpga #(32) dccm_data_lo_ff (.*,
                                      .din(dccm_data_lo_dc2),
                                      .dout(dccm_data_lo_dc3),
                                      .clk(lsu_dccm_c1_dc3_clk),
                                      .clken(lsu_dccm_c1_dc3_clken),
                                      .rawclk(clk));

   assign dccm_data_ecc_hi_dc3 = '0;
   assign dccm_data_ecc_lo_dc3 = '0;


endmodule
