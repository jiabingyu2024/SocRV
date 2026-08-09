module machine_timer (
   input  logic        clk,
   input  logic        rst_l,
   input  logic        req_valid,
   input  logic        req_write,
   input  logic [11:0] req_addr,
   input  logic [31:0] req_wdata,
   input  logic [3:0]  req_wstrb,
   output logic        req_ready,
   output logic [31:0] req_rdata,
   output logic        timer_irq
);
   logic [63:0] mtime;
   logic [63:0] mtimecmp;
   logic [1:0]  timer_ctrl;
   logic        wr_fire;
   logic [31:0] timer_ctrl_merged;

   function automatic logic [31:0] merge_wstrb(
      input logic [31:0] old_value,
      input logic [31:0] new_value,
      input logic [3:0]  strb
   );
      logic [31:0] value;
      value = old_value;
      for (int i = 0; i < 4; i++)
         if (strb[i]) value[i*8 +: 8] = new_value[i*8 +: 8];
      return value;
   endfunction

   assign req_ready = 1'b1;
   assign wr_fire = req_valid && req_ready && req_write;
   assign timer_ctrl_merged = merge_wstrb({30'b0, timer_ctrl}, req_wdata, req_wstrb);
   assign timer_irq = timer_ctrl[0] && timer_ctrl[1] && (mtime >= mtimecmp);

   always_comb begin
      unique case (req_addr[7:2])
         6'h00: req_rdata = mtime[31:0];
         6'h01: req_rdata = mtime[63:32];
         6'h02: req_rdata = mtimecmp[31:0];
         6'h03: req_rdata = mtimecmp[63:32];
         6'h04: req_rdata = {30'b0, timer_ctrl};
         6'h05: req_rdata = {31'b0, (mtime >= mtimecmp)};
         default: req_rdata = 32'b0;
      endcase
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         mtime      <= 64'b0;
         mtimecmp   <= 64'hffff_ffff_ffff_ffff;
         timer_ctrl <= 2'b01;
      end else begin
         if (timer_ctrl[0]) mtime <= mtime + 64'd1;
         if (wr_fire) begin
            unique case (req_addr[7:2])
               6'h00: mtime[31:0]   <= merge_wstrb(mtime[31:0], req_wdata, req_wstrb);
               6'h01: mtime[63:32]  <= merge_wstrb(mtime[63:32], req_wdata, req_wstrb);
               6'h02: mtimecmp[31:0]  <= merge_wstrb(mtimecmp[31:0], req_wdata, req_wstrb);
               6'h03: mtimecmp[63:32] <= merge_wstrb(mtimecmp[63:32], req_wdata, req_wstrb);
               6'h04: timer_ctrl <= timer_ctrl_merged[1:0];
               default: ;
            endcase
         end
      end
   end
endmodule
