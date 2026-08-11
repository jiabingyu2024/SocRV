// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
// SocRv no-ECC TCM derivative, 2026.

// 128 KiB instruction closely coupled memory.
//
// Physical organization is four independent 8192 x 32-bit lanes.  All four
// lanes share one line address and are read synchronously, providing one
// 128-bit fetch line per cycle without a tag lookup, refill path, parity or
// ECC.  The optional write port exists for loader/debug bring-up; production
// FPGA images normally initialize the lanes from the bitstream.
module ifu_iccm_mem
   import veer_types::*;
#(
   parameter string LANE0_INIT_FILE = "",
   parameter string LANE1_INIT_FILE = "",
   parameter string LANE2_INIT_FILE = "",
   parameter string LANE3_INIT_FILE = ""
)
(
   input  logic                         clk,
   input  logic                         free_clk,
   input  logic                         rst_l,
   input  logic                         clk_override,
   input  logic                         iccm_wren,
   input  logic                         iccm_rden,
   input  logic [`RV_ICCM_BITS-1:2]     iccm_rw_addr,
   input  logic [2:0]                   iccm_wr_size,
   input  logic [63:0]                  iccm_wr_data,
   output logic [127:0]                 iccm_rd_data,
   input  logic                         scan_mode
);

   localparam int ICCM_LINE_ADDR_BITS = `RV_ICCM_BITS - 4;
   localparam int ICCM_LINE_DEPTH     = 1 << ICCM_LINE_ADDR_BITS;

   logic [ICCM_LINE_ADDR_BITS-1:0] line_addr;
   logic [1:0]                     word_sel;
   logic                           write_doubleword;
   logic [31:0]                    lane_q [0:3];
   logic [31:0]                    lane_out_q [0:3];

   (* ram_style = "block" *) logic [31:0] lane0 [0:ICCM_LINE_DEPTH-1];
   (* ram_style = "block" *) logic [31:0] lane1 [0:ICCM_LINE_DEPTH-1];
   (* ram_style = "block" *) logic [31:0] lane2 [0:ICCM_LINE_DEPTH-1];
   (* ram_style = "block" *) logic [31:0] lane3 [0:ICCM_LINE_DEPTH-1];

`ifndef SYNTHESIS
   string lane0_runtime_file;
   string lane1_runtime_file;
   string lane2_runtime_file;
   string lane3_runtime_file;
`endif

   initial begin
`ifndef SYNTHESIS
      if ($value$plusargs("iccm_lane0=%s", lane0_runtime_file))
         $readmemh(lane0_runtime_file, lane0);
      else
`endif
      if (LANE0_INIT_FILE != "") $readmemh(LANE0_INIT_FILE, lane0);
`ifndef SYNTHESIS
      if ($value$plusargs("iccm_lane1=%s", lane1_runtime_file))
         $readmemh(lane1_runtime_file, lane1);
      else
`endif
      if (LANE1_INIT_FILE != "") $readmemh(LANE1_INIT_FILE, lane1);
`ifndef SYNTHESIS
      if ($value$plusargs("iccm_lane2=%s", lane2_runtime_file))
         $readmemh(lane2_runtime_file, lane2);
      else
`endif
      if (LANE2_INIT_FILE != "") $readmemh(LANE2_INIT_FILE, lane2);
`ifndef SYNTHESIS
      if ($value$plusargs("iccm_lane3=%s", lane3_runtime_file))
         $readmemh(lane3_runtime_file, lane3);
      else
`endif
      if (LANE3_INIT_FILE != "") $readmemh(LANE3_INIT_FILE, lane3);
   end

   assign line_addr        = iccm_rw_addr[`RV_ICCM_BITS-1:4];
   assign word_sel         = iccm_rw_addr[3:2];
   assign write_doubleword = (iccm_wr_size[1:0] == 2'b11);

   always_ff @(posedge clk) begin
      // Keep a real register immediately behind each BRAM output.  Xilinx can
      // absorb this stage into the RAMB36 output register; the IFU response
      // protocol deliberately accounts for the additional cycle.
      lane_out_q[0] <= lane_q[0];
      lane_out_q[1] <= lane_q[1];
      lane_out_q[2] <= lane_q[2];
      lane_out_q[3] <= lane_q[3];

      if (iccm_rden) begin
         lane_q[0] <= lane0[line_addr];
         lane_q[1] <= lane1[line_addr];
         lane_q[2] <= lane2[line_addr];
         lane_q[3] <= lane3[line_addr];
      end

      if (iccm_wren && (word_sel == 2'd0))
         lane0[line_addr] <= iccm_wr_data[31:0];
      if (iccm_wren && ((word_sel == 2'd1) || (write_doubleword && (word_sel == 2'd0))))
         lane1[line_addr] <= (word_sel == 2'd1) ? iccm_wr_data[31:0] : iccm_wr_data[63:32];
      if (iccm_wren && ((word_sel == 2'd2) || (write_doubleword && (word_sel == 2'd1))))
         lane2[line_addr] <= (word_sel == 2'd2) ? iccm_wr_data[31:0] : iccm_wr_data[63:32];
      if (iccm_wren && ((word_sel == 2'd3) || (write_doubleword && (word_sel == 2'd2))))
         lane3[line_addr] <= (word_sel == 2'd3) ? iccm_wr_data[31:0] : iccm_wr_data[63:32];
   end

   assign iccm_rd_data[127:0] = {lane_out_q[3], lane_out_q[2], lane_out_q[1], lane_out_q[0]};

   // free_clk, rst_l, clk_override and scan_mode intentionally do not affect
   // the BRAM array.  Keeping them on the compatibility boundary avoids
   // unnecessary wrapper churn until the final minimal SoC shell is installed.

endmodule
