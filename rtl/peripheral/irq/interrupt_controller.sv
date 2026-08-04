module interrupt_controller #(
  parameter int unsigned IRQ_COUNT = soc_config_pkg::EXT_IRQ_COUNT
) (
  input logic clk_i,
  input logic rst_ni,
  input logic [IRQ_COUNT-1:0] ext_irq_i,
  hxi_if.slave hxi,
  output logic irq_software_o,
  output logic irq_external_o
);
  import common_types_pkg::apply_wstrb;
  logic [IRQ_COUNT-1:0] pending_q;
  logic [IRQ_COUNT-1:0] enable_q;
  logic software_q;
  logic rsp_valid_q;
  logic [31:0] rsp_rdata_q;
  logic rsp_err_q;

  assign hxi.req_ready   = !rsp_valid_q;
  assign hxi.rsp_valid   = rsp_valid_q;
  assign hxi.rsp_rdata   = rsp_rdata_q;
  assign hxi.rsp_err     = rsp_err_q;
  assign irq_software_o  = software_q;
  assign irq_external_o  = |(pending_q & enable_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    logic [31:0] merged;
    if (!rst_ni) begin
      pending_q   <= '0;
      enable_q    <= '0;
      software_q  <= 1'b0;
      rsp_valid_q <= 1'b0;
      rsp_rdata_q <= '0;
      rsp_err_q   <= 1'b0;
    end else begin
      pending_q <= pending_q | ext_irq_i;
      if (rsp_valid_q && hxi.rsp_ready) rsp_valid_q <= 1'b0;
      if (hxi.req_valid && hxi.req_ready) begin
        rsp_valid_q <= 1'b1;
        rsp_err_q   <= 1'b0;
        case (hxi.req_addr[11:0])
          12'h000: begin
            rsp_rdata_q <= {{(32-IRQ_COUNT){1'b0}}, pending_q};
            if (hxi.req_write) pending_q <= (pending_q | ext_irq_i) & ~hxi.req_wdata[IRQ_COUNT-1:0];
          end
          12'h004: begin
            rsp_rdata_q <= {{(32-IRQ_COUNT){1'b0}}, enable_q};
            if (hxi.req_write) begin
              merged = apply_wstrb({{(32-IRQ_COUNT){1'b0}}, enable_q}, hxi.req_wdata, hxi.req_wstrb);
              enable_q <= merged[IRQ_COUNT-1:0];
            end
          end
          12'h008: begin
            rsp_rdata_q <= {31'b0, software_q};
            if (hxi.req_write && hxi.req_wstrb[0]) software_q <= hxi.req_wdata[0];
          end
          default: begin
            rsp_rdata_q <= '0;
            rsp_err_q   <= 1'b1;
          end
        endcase
      end
    end
  end
endmodule
