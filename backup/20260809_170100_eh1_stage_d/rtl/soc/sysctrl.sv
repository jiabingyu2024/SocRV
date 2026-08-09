module sysctrl #(
   parameter logic [31:0] CLOCK_HZ = 32'd250_000_000,
   parameter logic [31:0] BUILD_ID = 32'h000d_0001
) (
   input  logic        clk,
   input  logic        rst_l,
   input  logic        req_valid,
   input  logic        req_write,
   input  logic [11:0] req_addr,
   input  logic [31:0] req_wdata,
   input  logic [3:0]  req_wstrb,
   output logic        req_ready,
   output logic [31:0] req_rdata,
   output logic [31:0] test_status
);
   logic [31:0] reset_cause;
   logic [31:0] write_mask;

   always_comb begin
      for (int i = 0; i < 4; i++)
         write_mask[i*8 +: 8] = {8{req_wstrb[i]}};
   end

   assign req_ready = 1'b1;
   always_comb begin
      unique case (req_addr[7:2])
         6'h00: req_rdata = 32'h4548_3146;
         6'h01: req_rdata = CLOCK_HZ;
         6'h02: req_rdata = reset_cause;
         6'h03: req_rdata = test_status;
         6'h04: req_rdata = BUILD_ID;
         default: req_rdata = 32'b0;
      endcase
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         reset_cause <= 32'h0000_0001;
         test_status <= 32'b0;
      end else if (req_valid && req_ready && req_write) begin
         unique case (req_addr[7:2])
            6'h02: reset_cause <= reset_cause & ~(req_wdata & write_mask);
            6'h03: test_status <= (test_status & ~write_mask) | (req_wdata & write_mask);
            default: ;
         endcase
      end
   end
endmodule
