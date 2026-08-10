module sysctrl #(
   parameter logic [31:0] CORE_CLOCK_HZ       = 32'd100_000_000,
   parameter logic [31:0] PERIPHERAL_CLOCK_HZ = 32'd50_000_000,
   parameter logic [31:0] BUILD_ID             = 32'h000d_0002
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
   output logic        software_irq,
   output logic [31:0] test_status,
   output logic [31:0] test_code
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
         6'h01: req_rdata = CORE_CLOCK_HZ;
         6'h02: req_rdata = reset_cause;
         6'h03: req_rdata = BUILD_ID;
         6'h04: req_rdata = {31'b0, software_irq};
         6'h05: req_rdata = test_status;
         6'h06: req_rdata = test_code;
         6'h08: req_rdata = PERIPHERAL_CLOCK_HZ;
         default: req_rdata = 32'b0;
      endcase
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         reset_cause <= 32'h0000_0001;
         software_irq <= 1'b0;
         test_status <= 32'b0;
         test_code   <= 32'b0;
      end else if (req_valid && req_ready && req_write) begin
         unique case (req_addr[7:2])
            6'h02: reset_cause <= reset_cause & ~(req_wdata & write_mask);
            6'h04: if (req_wstrb[0]) software_irq <= req_wdata[0];
            6'h05: test_status <= (test_status & ~write_mask) | (req_wdata & write_mask);
            6'h06: test_code <= (test_code & ~write_mask) | (req_wdata & write_mask);
            default: ;
         endcase
      end
   end
endmodule
