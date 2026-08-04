module machine_timer (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave hxi,
  output logic irq_timer_o
);
  import common_types_pkg::apply_wstrb;
  logic [63:0] mtime_q;
  logic [63:0] mtimecmp_q;
  logic [31:0] control_q;
  logic rsp_valid_q;
  logic [31:0] rsp_rdata_q;
  logic rsp_err_q;
  logic [11:0] offset;

  assign offset          = hxi.req_addr[11:0];
  assign hxi.req_ready   = !rsp_valid_q;
  assign hxi.rsp_valid   = rsp_valid_q;
  assign hxi.rsp_rdata   = rsp_rdata_q;
  assign hxi.rsp_err     = rsp_err_q;
  assign irq_timer_o     = control_q[1] && (mtime_q >= mtimecmp_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mtime_q     <= '0;
      mtimecmp_q  <= '1;
      control_q   <= 32'h0000_0001;
      rsp_valid_q <= 1'b0;
      rsp_rdata_q <= '0;
      rsp_err_q   <= 1'b0;
    end else begin
      if (control_q[0]) mtime_q <= mtime_q + 64'd1;
      if (rsp_valid_q && hxi.rsp_ready) rsp_valid_q <= 1'b0;
      if (hxi.req_valid && hxi.req_ready) begin
        rsp_valid_q <= 1'b1;
        rsp_err_q   <= 1'b0;
        case (offset)
          12'h000: begin
            rsp_rdata_q <= mtime_q[31:0];
            if (hxi.req_write) mtime_q[31:0] <= apply_wstrb(mtime_q[31:0], hxi.req_wdata, hxi.req_wstrb);
          end
          12'h004: begin
            rsp_rdata_q <= mtime_q[63:32];
            if (hxi.req_write) mtime_q[63:32] <= apply_wstrb(mtime_q[63:32], hxi.req_wdata, hxi.req_wstrb);
          end
          12'h008: begin
            rsp_rdata_q <= mtimecmp_q[31:0];
            if (hxi.req_write) mtimecmp_q[31:0] <= apply_wstrb(mtimecmp_q[31:0], hxi.req_wdata, hxi.req_wstrb);
          end
          12'h00c: begin
            rsp_rdata_q <= mtimecmp_q[63:32];
            if (hxi.req_write) mtimecmp_q[63:32] <= apply_wstrb(mtimecmp_q[63:32], hxi.req_wdata, hxi.req_wstrb);
          end
          12'h010: begin
            rsp_rdata_q <= control_q;
            if (hxi.req_write) control_q <= apply_wstrb(control_q, hxi.req_wdata, hxi.req_wstrb);
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
