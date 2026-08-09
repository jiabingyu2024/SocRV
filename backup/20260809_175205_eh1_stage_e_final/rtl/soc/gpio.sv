module gpio #(
   parameter int WIDTH = 16
) (
   input  logic             clk,
   input  logic             rst_l,
   input  logic [WIDTH-1:0] gpio_in,
   output logic [WIDTH-1:0] gpio_out,
   output logic [WIDTH-1:0] gpio_oe,
   input  logic             req_valid,
   input  logic             req_write,
   input  logic [11:0]      req_addr,
   input  logic [31:0]      req_wdata,
   input  logic [3:0]       req_wstrb,
   output logic             req_ready,
   output logic [31:0]      req_rdata
);
   logic [WIDTH-1:0] gpio_meta;
   logic [WIDTH-1:0] gpio_sync;
   logic [31:0] write_mask;
   logic wr_fire;

   always_comb begin
      for (int i = 0; i < 4; i++)
         write_mask[i*8 +: 8] = {8{req_wstrb[i]}};
   end

   assign req_ready = 1'b1;
   assign wr_fire = req_valid && req_ready && req_write;

   always_comb begin
      unique case (req_addr[7:2])
         6'h00: req_rdata = {{(32-WIDTH){1'b0}}, gpio_sync};
         6'h01: req_rdata = {{(32-WIDTH){1'b0}}, gpio_out};
         6'h02: req_rdata = {{(32-WIDTH){1'b0}}, gpio_oe};
         default: req_rdata = 32'b0;
      endcase
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         gpio_meta <= '0;
         gpio_sync <= '0;
         gpio_out  <= '0;
         gpio_oe   <= '0;
      end else begin
         gpio_meta <= gpio_in;
         gpio_sync <= gpio_meta;
         if (wr_fire) begin
            unique case (req_addr[7:2])
               6'h01: gpio_out <= (gpio_out & ~write_mask[WIDTH-1:0]) |
                                   (req_wdata[WIDTH-1:0] & write_mask[WIDTH-1:0]);
               6'h02: gpio_oe  <= (gpio_oe & ~write_mask[WIDTH-1:0]) |
                                   (req_wdata[WIDTH-1:0] & write_mask[WIDTH-1:0]);
               6'h03: gpio_out <= gpio_out | (req_wdata[WIDTH-1:0] & write_mask[WIDTH-1:0]);
               6'h04: gpio_out <= gpio_out & ~(req_wdata[WIDTH-1:0] & write_mask[WIDTH-1:0]);
               6'h05: gpio_out <= gpio_out ^ (req_wdata[WIDTH-1:0] & write_mask[WIDTH-1:0]);
               default: ;
            endcase
         end
      end
   end
endmodule
