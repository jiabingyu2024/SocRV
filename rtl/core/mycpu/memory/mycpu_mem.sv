


module mycpu_mem
   import mycpu_types::*;
#(
   parameter string ICCM_LANE0_INIT_FILE = "",
   parameter string ICCM_LANE1_INIT_FILE = "",
   parameter string ICCM_LANE2_INIT_FILE = "",
   parameter string ICCM_LANE3_INIT_FILE = "",
   parameter string DCCM_BANK0_INIT_FILE = "",
   parameter string DCCM_BANK1_INIT_FILE = "",
   parameter string DCCM_BANK2_INIT_FILE = "",
   parameter string DCCM_BANK3_INIT_FILE = "",
   parameter string DCCM_BANK4_INIT_FILE = "",
   parameter string DCCM_BANK5_INIT_FILE = "",
   parameter string DCCM_BANK6_INIT_FILE = "",
   parameter string DCCM_BANK7_INIT_FILE = ""
)
(
   input logic         clk,
   input logic         rst_l,
   input logic         lsu_freeze_dc3,
   input logic         dccm_clk_override,
   input logic         icm_clk_override,
   input logic         dec_tlu_core_ecc_disable,


   input logic         dccm_wren,
   input logic         dccm_rden,
   input logic [`RV_DCCM_BITS-1:0]  dccm_wr_addr,
   input logic [`RV_DCCM_BITS-1:0]  dccm_rd_addr_lo,
   input logic [`RV_DCCM_BITS-1:0]  dccm_rd_addr_hi,
   input logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_wr_data,


   output logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,
   output logic [`RV_DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,


   input logic [`RV_ICCM_BITS-1:2]  iccm_rw_addr,
   input logic         iccm_rden,

   output logic [127:0] iccm_rd_data,
   input  logic         scan_mode

);
`include "core_params.svh"

      localparam DCCM_ENABLE = 1'b1;

   logic free_clk;
   rvoclkhdr free_cg   ( .en(1'b1),         .l1clk(free_clk), .* );


   if (DCCM_ENABLE == 1) begin: Gen_dccm_enable
      dccm_mem #(
         .BANK0_INIT_FILE(DCCM_BANK0_INIT_FILE),
         .BANK1_INIT_FILE(DCCM_BANK1_INIT_FILE),
         .BANK2_INIT_FILE(DCCM_BANK2_INIT_FILE),
         .BANK3_INIT_FILE(DCCM_BANK3_INIT_FILE),
         .BANK4_INIT_FILE(DCCM_BANK4_INIT_FILE),
         .BANK5_INIT_FILE(DCCM_BANK5_INIT_FILE),
         .BANK6_INIT_FILE(DCCM_BANK6_INIT_FILE),
         .BANK7_INIT_FILE(DCCM_BANK7_INIT_FILE)
      ) dccm (
         .clk_override(dccm_clk_override),
         .*
      );
   end else begin: Gen_dccm_disable
      assign dccm_rd_data_lo = '0;
      assign dccm_rd_data_hi = '0;
   end

   iccm_mem #(
                  .LANE0_INIT_FILE(ICCM_LANE0_INIT_FILE),
                  .LANE1_INIT_FILE(ICCM_LANE1_INIT_FILE),
                  .LANE2_INIT_FILE(ICCM_LANE2_INIT_FILE),
                  .LANE3_INIT_FILE(ICCM_LANE3_INIT_FILE)
                  ) iccm (.*,
                  .clk_override(icm_clk_override),
                  .iccm_rw_addr(iccm_rw_addr[`RV_ICCM_BITS-1:2]),
                   .iccm_rd_data(iccm_rd_data[127:0])
                   );

endmodule
