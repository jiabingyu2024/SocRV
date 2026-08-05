module hxi_data_adapter (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic core_req_valid_i,
  output logic core_req_ready_o,
  input  logic core_req_write_i,
  input  logic [31:0] core_req_addr_i,
  input  logic [31:0] core_req_wdata_i,
  input  logic [3:0] core_req_wstrb_i,
  input  logic core_req_uncached_i,
  output logic core_rsp_valid_o,
  output logic [31:0] core_rsp_rdata_o,
  hxi_if.master hxi,
  output logic fault_o
);
  typedef enum logic [1:0] {
    IDLE,
    WAIT_FIRST,
    REQUEST_SECOND,
    WAIT_SECOND
  } state_e;

  state_e state_q;
  logic request_write_q;
  logic request_uncached_q;
  logic request_cross_q;
  logic [31:0] request_addr_q;
  logic [31:0] request_wdata_q;
  logic [3:0] request_wstrb_q;
  logic [1:0] request_offset_q;
  logic [31:0] first_read_word_q;
  logic fault_q;
  logic [2:0] access_bytes;
  logic request_cross;
  logic [4:0] low_shift;
  logic [5:0] high_shift;
  logic [63:0] combined_read;
  logic [63:0] shifted_read;

  assign access_bytes = core_req_wstrb_i[3] ? 3'd4 :
                        core_req_wstrb_i[1] ? 3'd2 : 3'd1;
  assign request_cross = ({1'b0, core_req_addr_i[1:0]} + access_bytes) > 3'd4;
  assign low_shift  = {core_req_addr_i[1:0], 3'b000};
  assign high_shift = {3'd4 - {1'b0, request_offset_q}, 3'b000};

  always_comb begin
    hxi.req_valid = 1'b0;
    hxi.req_addr  = '0;
    hxi.req_write = 1'b0;
    hxi.req_wdata = '0;
    hxi.req_wstrb = '0;
    core_req_ready_o = 1'b0;

    if (state_q == IDLE) begin
      hxi.req_valid = core_req_valid_i;
      hxi.req_addr  = {core_req_addr_i[31:2], 2'b00};
      hxi.req_write = core_req_write_i;
      hxi.req_wdata = core_req_wdata_i << low_shift;
      hxi.req_wstrb = core_req_write_i
          ? ((core_req_wstrb_i << core_req_addr_i[1:0]) & 4'hf) : 4'b0;
      core_req_ready_o = hxi.req_ready;
    end else if (state_q == REQUEST_SECOND) begin
      hxi.req_valid = 1'b1;
      hxi.req_addr  = {request_addr_q[31:2], 2'b00} + 32'd4;
      hxi.req_write = request_write_q;
      hxi.req_wdata = request_wdata_q >> high_shift;
      hxi.req_wstrb = request_write_q
          ? (request_wstrb_q >> (3'd4 - {1'b0, request_offset_q})) : 4'b0;
    end
  end

  // HXI returns a completion for stores as well as loads.  The migrated
  // DCache considers a store accepted at request handshake, so the adapter
  // retains ownership and blocks a younger request until that write response
  // has been consumed.  Only read responses are forwarded to the DCache.
  assign hxi.rsp_ready = (state_q == WAIT_FIRST) ||
                         (state_q == WAIT_SECOND);
  assign core_rsp_valid_o = hxi.rsp_valid &&
      (((state_q == WAIT_FIRST) && !request_write_q && !request_cross_q) ||
       ((state_q == WAIT_SECOND) && !request_write_q));
  assign combined_read = request_cross_q
      ? {hxi.rsp_rdata, first_read_word_q}
      : {32'b0, hxi.rsp_rdata};
  assign shifted_read = combined_read >> {request_offset_q, 3'b000};
  assign core_rsp_rdata_o = (request_cross_q || request_uncached_q)
      ? shifted_read[31:0] : hxi.rsp_rdata;
  assign fault_o = fault_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q              <= IDLE;
      request_write_q      <= 1'b0;
      request_uncached_q   <= 1'b0;
      request_cross_q      <= 1'b0;
      request_addr_q       <= '0;
      request_wdata_q      <= '0;
      request_wstrb_q      <= '0;
      request_offset_q     <= '0;
      first_read_word_q    <= '0;
      fault_q             <= 1'b0;
    end else begin
      unique case (state_q)
        IDLE: if (hxi.req_valid && hxi.req_ready) begin
          request_write_q    <= core_req_write_i;
          request_uncached_q <= core_req_uncached_i;
          request_cross_q    <= request_cross;
          request_addr_q     <= core_req_addr_i;
          request_wdata_q    <= core_req_wdata_i;
          request_wstrb_q    <= core_req_wstrb_i;
          request_offset_q   <= core_req_addr_i[1:0];
          state_q            <= WAIT_FIRST;
        end
        WAIT_FIRST: if (hxi.rsp_valid && hxi.rsp_ready) begin
          if (hxi.rsp_err) fault_q <= 1'b1;
          if (request_cross_q) begin
            first_read_word_q <= hxi.rsp_rdata;
            state_q <= REQUEST_SECOND;
          end else begin
            state_q <= IDLE;
          end
        end
        REQUEST_SECOND: if (hxi.req_valid && hxi.req_ready) begin
          state_q <= WAIT_SECOND;
        end
        WAIT_SECOND: if (hxi.rsp_valid && hxi.rsp_ready) begin
          if (hxi.rsp_err) fault_q <= 1'b1;
          state_q <= IDLE;
        end
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
