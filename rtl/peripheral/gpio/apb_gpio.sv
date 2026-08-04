module apb_gpio #(
  parameter int unsigned WIDTH = 16
) (
  input logic clk_i,
  input logic rst_ni,
  input logic [31:0] paddr_i,
  input logic psel_i,
  input logic penable_i,
  input logic pwrite_i,
  input logic [31:0] pwdata_i,
  input logic [3:0] pstrb_i,
  output logic [31:0] prdata_o,
  output logic pready_o,
  output logic pslverr_o,
  input logic [WIDTH-1:0] gpio_i,
  output logic [WIDTH-1:0] gpio_o,
  output logic [WIDTH-1:0] gpio_oe_o
);
  import common_types_pkg::apply_wstrb;
  logic [31:0] out_q;
  logic [31:0] oe_q;

  assign gpio_o     = out_q[WIDTH-1:0];
  assign gpio_oe_o  = oe_q[WIDTH-1:0];
  assign pready_o   = 1'b1;
  assign pslverr_o  = 1'b0;

  always_comb begin
    case (paddr_i[11:0])
      12'h000: prdata_o = out_q;
      12'h004: prdata_o = oe_q;
      12'h008: prdata_o = {{(32-WIDTH){1'b0}}, gpio_i};
      default: prdata_o = '0;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      out_q <= '0;
      oe_q  <= '0;
    end else if (psel_i && penable_i && pwrite_i) begin
      if (paddr_i[11:0] == 12'h000) out_q <= apply_wstrb(out_q, pwdata_i, pstrb_i);
      if (paddr_i[11:0] == 12'h004) oe_q  <= apply_wstrb(oe_q, pwdata_i, pstrb_i);
    end
  end
endmodule
