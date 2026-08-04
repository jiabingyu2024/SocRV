module hxi_default_slave (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave hxi
);
  logic rsp_valid_q;
  logic [31:0] rsp_rdata_q;

  assign hxi.req_ready = !rsp_valid_q;
  assign hxi.rsp_valid = rsp_valid_q;
  assign hxi.rsp_rdata = rsp_rdata_q;
  assign hxi.rsp_err   = 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rsp_valid_q <= 1'b0;
      rsp_rdata_q <= '0;
    end else begin
      if (rsp_valid_q && hxi.rsp_ready) rsp_valid_q <= 1'b0;
      if (hxi.req_valid && hxi.req_ready) begin
        rsp_valid_q <= 1'b1;
        rsp_rdata_q <= 32'hBAD0_ADD0;
      end
    end
  end
endmodule
