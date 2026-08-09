module eh1_fpr_ctl (
   input  logic        clk,
   input  logic        rst_l,
   input  logic [4:0]  raddr1,
   input  logic [4:0]  raddr2,
   input  logic [4:0]  raddr3,
   output logic [31:0] rdata1,
   output logic [31:0] rdata2,
   output logic [31:0] rdata3,
   input  logic        wen,
   input  logic [4:0]  waddr,
   input  logic [31:0] wdata
);
   // Three asynchronous read ports keep operand selection out of the integer
   // critical path.  The 32x32 array maps naturally to FPGA distributed RAM or
   // flops; unlike GPR x0, every FPR is writable.
   (* ram_style = "distributed" *) logic [31:0] fpr [0:31];

   assign rdata1 = fpr[raddr1];
   assign rdata2 = fpr[raddr2];
   assign rdata3 = fpr[raddr3];

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         for (int i = 0; i < 32; i++) fpr[i] <= 32'b0;
      end else if (wen) begin
         fpr[waddr] <= wdata;
      end
   end

`ifndef SYNTHESIS
   always_ff @(posedge clk) begin
      if (rst_l && wen)
         $display("EH1F_FPR_WRITE f%0d=%08x", waddr, wdata);
   end
`endif
endmodule
