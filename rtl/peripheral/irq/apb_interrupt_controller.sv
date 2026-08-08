module apb_interrupt_controller #(
  parameter int unsigned IRQ_COUNT = soc_config_pkg::EXT_IRQ_COUNT
) (
  input logic clk_i,
  input logic rst_ni,
  input logic [IRQ_COUNT-1:0] ext_irq_i,
  input logic [31:0] paddr_i,
  input logic psel_i,
  input logic penable_i,
  input logic pwrite_i,
  input logic [31:0] pwdata_i,
  input logic [3:0] pstrb_i,
  output logic [31:0] prdata_o,
  output logic pready_o,
  output logic pslverr_o,
  output logic irq_software_o,
  output logic irq_external_o
);
  import common_types_pkg::apply_wstrb;
  logic [IRQ_COUNT-1:0] pending_q;
  logic [IRQ_COUNT-1:0] enable_q;
  logic software_q;
  logic access;

  assign access = psel_i && penable_i;
  assign pready_o = 1'b1;
  assign pslverr_o = access && !(paddr_i[11:0] inside {
      12'h000, 12'h004, 12'h008});
  assign irq_software_o = software_q;
  assign irq_external_o = |(pending_q & enable_q);

  always_comb begin
    unique case (paddr_i[11:0])
      12'h000: prdata_o = {{(32-IRQ_COUNT){1'b0}}, pending_q};
      12'h004: prdata_o = {{(32-IRQ_COUNT){1'b0}}, enable_q};
      12'h008: prdata_o = {31'b0, software_q};
      default: prdata_o = '0;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    logic [31:0] merged;
    if (!rst_ni) begin
      pending_q <= '0;
      enable_q <= '0;
      software_q <= 1'b0;
    end else begin
      pending_q <= pending_q | ext_irq_i;
      if (access && pwrite_i) begin
        unique case (paddr_i[11:0])
          12'h000: pending_q <= (pending_q | ext_irq_i) &
                                   ~pwdata_i[IRQ_COUNT-1:0];
          12'h004: begin
            merged = apply_wstrb(
                {{(32-IRQ_COUNT){1'b0}}, enable_q}, pwdata_i, pstrb_i);
            enable_q <= merged[IRQ_COUNT-1:0];
          end
          12'h008: if (pstrb_i[0]) software_q <= pwdata_i[0];
          default: begin end
        endcase
      end
    end
  end
endmodule
