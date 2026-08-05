module hxi_instruction_adapter (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic core_req_valid_i,
  input  logic [31:0] core_req_addr_i,
  output logic core_rsp_valid_o,
  input  logic core_rsp_ready_i,
  output logic [31:0] core_rsp_data_o,
  hxi_if.master hxi,
  output logic fault_o
);
  logic outstanding_q;
  logic [31:0] request_addr_q;
  logic response_valid_q;
  logic [31:0] response_data_q;
  logic response_error_q;
  logic fault_q;

  assign hxi.req_valid = core_req_valid_i && !outstanding_q &&
                         !response_valid_q;
  assign hxi.req_addr  = core_req_addr_i;
  assign hxi.req_write = 1'b0;
  assign hxi.req_wdata = '0;
  assign hxi.req_wstrb = '0;

  // A redirect cannot cancel an HXI transaction.  Drain a response belonging
  // to the old PC, but expose only a response that still matches the core's
  // current PC.  This is a one-entry epoch check without adding a tag to HXI.
  assign core_rsp_valid_o = response_valid_q &&
                            (request_addr_q == core_req_addr_i);
  assign core_rsp_data_o  = response_error_q ? 32'd0 : response_data_q;
  // Register the response at the CPU boundary.  Besides preserving the HXI
  // hold contract, this removes a combinational rsp_ready -> crossbar ->
  // D-side req_ready -> pipeline-stall -> rsp_ready loop.
  assign hxi.rsp_ready = outstanding_q && !response_valid_q;
  assign fault_o = fault_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      outstanding_q  <= 1'b0;
      request_addr_q <= '0;
      response_valid_q <= 1'b0;
      response_data_q  <= '0;
      response_error_q <= 1'b0;
      fault_q        <= 1'b0;
    end else begin
      if (response_valid_q &&
          ((request_addr_q != core_req_addr_i) || core_rsp_ready_i)) begin
        response_valid_q <= 1'b0;
      end
      if (hxi.rsp_valid && hxi.rsp_ready) begin
        outstanding_q <= 1'b0;
        response_valid_q <= 1'b1;
        response_data_q  <= hxi.rsp_rdata;
        response_error_q <= hxi.rsp_err;
        if (hxi.rsp_err) fault_q <= 1'b1;
      end
      if (hxi.req_valid && hxi.req_ready) begin
        outstanding_q  <= 1'b1;
        request_addr_q <= core_req_addr_i;
      end
    end
  end
endmodule
