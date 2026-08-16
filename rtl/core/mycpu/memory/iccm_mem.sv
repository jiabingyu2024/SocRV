

module iccm_mem
   import mycpu_types::*;
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
   input  logic                         iccm_rden,
   input  logic [`RV_ICCM_BITS-1:2]     iccm_rw_addr,
   output logic [127:0]                 iccm_rd_data,
   input  logic                         scan_mode
);

   localparam int ICCM_LINE_ADDR_BITS = `RV_ICCM_BITS - 4;
   localparam int ICCM_LINE_DEPTH     = 1 << ICCM_LINE_ADDR_BITS;

   logic [ICCM_LINE_ADDR_BITS-1:0] line_addr;
   logic [31:0]                    lane_q [0:3];

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

   always_ff @(posedge clk) begin
      if (iccm_rden) begin
         lane_q[0] <= lane0[line_addr];
         lane_q[1] <= lane1[line_addr];
         lane_q[2] <= lane2[line_addr];
         lane_q[3] <= lane3[line_addr];
      end
   end

   assign iccm_rd_data[127:0] = {lane_q[3], lane_q[2], lane_q[1], lane_q[0]};


endmodule
