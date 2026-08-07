module pipelined_instruction_adapter #(
  parameter int unsigned FETCH_DEPTH = 4,
  parameter int unsigned EPOCH_WIDTH = 8,
  parameter int unsigned CONTROL_GUARD_CYCLES = 2
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        core_req_valid_i,
  input  logic [31:0] core_req_addr_i,
  output logic        core_rsp_valid_o,
  input  logic        core_rsp_ready_i,
  output logic [31:0] core_rsp_data_o,
  hxi_if.master       hxi,
  output logic        fault_o
);
  localparam int unsigned PTR_WIDTH = $clog2(FETCH_DEPTH);
  localparam int unsigned COUNT_WIDTH = $clog2(FETCH_DEPTH + 1);
  localparam int unsigned GUARD_COUNT_WIDTH =
      (CONTROL_GUARD_CYCLES < 2) ? 1 : $clog2(CONTROL_GUARD_CYCLES + 1);

  typedef logic [PTR_WIDTH-1:0] ptr_t;
  typedef logic [COUNT_WIDTH-1:0] count_t;
  typedef logic [EPOCH_WIDTH-1:0] epoch_t;
  typedef logic [GUARD_COUNT_WIDTH-1:0] guard_count_t;

  logic [31:0] pending_addr_q [0:FETCH_DEPTH-1];
  epoch_t pending_epoch_q [0:FETCH_DEPTH-1];
  ptr_t pending_head_q;
  ptr_t pending_tail_q;
  count_t pending_count_q;

  logic [31:0] response_addr_q [0:FETCH_DEPTH-1];
  logic [31:0] response_data_q [0:FETCH_DEPTH-1];
  logic response_error_q [0:FETCH_DEPTH-1];
  ptr_t response_head_q;
  ptr_t response_tail_q;
  count_t response_count_q;

  logic stream_valid_q;
  logic [31:0] expected_core_addr_q;
  logic [31:0] candidate_addr_q;
  epoch_t current_epoch_q;
  logic fault_q;
  guard_count_t control_guard_q;

  logic redirect_detected;
  logic capacity_available;
  logic response_space_available;
  logic request_fire;
  logic response_fire;
  logic response_is_current;
  logic response_push;
  logic core_response_fire;
  logic [COUNT_WIDTH:0] reserved_slots;
  logic head_is_control_transfer;

  function automatic logic is_control_transfer(input logic [31:0] instruction);
    unique case (instruction[6:0])
      7'b1100011,  // conditional branch
      7'b1100111,  // JALR
      7'b1101111:  // JAL
        return 1'b1;
      7'b1110011:  // ECALL/EBREAK/MRET and other privileged SYSTEM redirects
        return instruction[14:12] == 3'b000;
      default:
        return 1'b0;
    endcase
  endfunction

  // The CPU keeps its current PC stable while no matching response is
  // available.  A change away from the sequential address expected after the
  // last accepted instruction is therefore a branch/exception/interrupt
  // redirect.  Redirects advance an epoch instead of trying to cancel HXI
  // requests that have already been accepted.
  assign redirect_detected = stream_valid_q && core_req_valid_i &&
                             (core_req_addr_i != expected_core_addr_q);

  assign reserved_slots = {1'b0, pending_count_q} +
                          {1'b0, response_count_q};
  assign capacity_available =
      reserved_slots < (COUNT_WIDTH+1)'(FETCH_DEPTH);

  assign hxi.req_valid = core_req_valid_i && !redirect_detected &&
                         capacity_available;
  assign hxi.req_addr = stream_valid_q ? candidate_addr_q : core_req_addr_i;
  assign hxi.req_write = 1'b0;
  assign hxi.req_wdata = '0;
  assign hxi.req_wstrb = '0;
  assign request_fire = hxi.req_valid && hxi.req_ready;

  assign head_is_control_transfer = response_count_q != 0 &&
                                    !response_error_q[response_head_q] &&
                                    is_control_transfer(
                                        response_data_q[response_head_q]);
  assign core_rsp_valid_o = response_count_q != 0 &&
                            control_guard_q == 0 && !redirect_detected &&
                            (response_addr_q[response_head_q] ==
                             core_req_addr_i);
  assign core_rsp_data_o =
      (response_count_q != 0 && !response_error_q[response_head_q]) ?
      response_data_q[response_head_q] : 32'd0;
  assign core_response_fire = core_rsp_valid_o && core_rsp_ready_i;

  // A response belonging to an old epoch can always be drained.  A current
  // response is accepted only when the response FIFO has a slot (including a
  // slot returned by a simultaneous CPU consume).  This is the response-hold
  // contract that the failed v1.5 bypass omitted.
  assign response_space_available =
      (response_count_q < count_t'(FETCH_DEPTH)) || redirect_detected;
  assign hxi.rsp_ready = pending_count_q != 0 &&
                         ((pending_epoch_q[pending_head_q] != current_epoch_q) ||
                          response_space_available);
  assign response_fire = hxi.rsp_valid && hxi.rsp_ready;
  assign response_is_current = pending_epoch_q[pending_head_q] ==
                               current_epoch_q;
  assign response_push = response_fire && response_is_current &&
                         !redirect_detected;

  assign fault_o = fault_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stream_valid_q <= 1'b0;
      expected_core_addr_q <= '0;
      candidate_addr_q <= '0;
      current_epoch_q <= '0;
      fault_q <= 1'b0;
    end else begin
      if (redirect_detected) begin
        expected_core_addr_q <= core_req_addr_i;
        candidate_addr_q <= core_req_addr_i;
        current_epoch_q <= current_epoch_q + 1'b1;
      end else begin
        if (!stream_valid_q && core_req_valid_i) begin
          stream_valid_q <= 1'b1;
          expected_core_addr_q <= core_req_addr_i;
          candidate_addr_q <= core_req_addr_i;
        end
        if (request_fire) begin
          stream_valid_q <= 1'b1;
          if (!stream_valid_q)
            expected_core_addr_q <= core_req_addr_i;
          candidate_addr_q <= hxi.req_addr + 32'd4;
        end
        if (core_response_fire) begin
          expected_core_addr_q <=
              response_addr_q[response_head_q] + 32'd4;
          if (response_error_q[response_head_q])
            fault_q <= 1'b1;
        end
      end
    end
  end

  // The existing CPU resolves control transfers after younger instructions
  // can already reach EX when fetch is supplied continuously.  Its flush path
  // does not suppress every same-cycle younger exception/side effect.  Keep
  // memory-side prefetching active, but pause instruction delivery briefly
  // after a control transfer.  Taken transfers clear the guard immediately on
  // the observed PC redirect; not-taken branches resume after the fixed pipe
  // separation.  This preserves burst throughput inside basic blocks without
  // changing the CPU core.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      control_guard_q <= '0;
    end else if (redirect_detected) begin
      control_guard_q <= '0;
    end else if (core_response_fire && head_is_control_transfer) begin
      control_guard_q <= guard_count_t'(CONTROL_GUARD_CYCLES);
    end else if (control_guard_q != 0) begin
      control_guard_q <= control_guard_q - 1'b1;
    end
  end

  // Accepted HXI requests reserve response capacity until their in-order
  // response is either queued or discarded as stale.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pending_head_q <= '0;
      pending_tail_q <= '0;
      pending_count_q <= '0;
    end else begin
      if (request_fire)
        pending_tail_q <= pending_tail_q + 1'b1;
      if (response_fire)
        pending_head_q <= pending_head_q + 1'b1;
      unique case ({request_fire, response_fire})
        2'b10: pending_count_q <= pending_count_q + 1'b1;
        2'b01: pending_count_q <= pending_count_q - 1'b1;
        default: begin end
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (request_fire) begin
      pending_addr_q[pending_tail_q] <= hxi.req_addr;
      pending_epoch_q[pending_tail_q] <= current_epoch_q;
    end
  end

  // Completed responses are held at the FIFO head until the CPU explicitly
  // accepts them.  A redirect invalidates queued responses immediately, while
  // already-issued HXI transactions remain in the pending FIFO and are drained
  // by their old epoch.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      response_head_q <= '0;
      response_tail_q <= '0;
      response_count_q <= '0;
    end else if (redirect_detected) begin
      response_head_q <= '0;
      response_tail_q <= '0;
      response_count_q <= '0;
    end else begin
      if (response_push)
        response_tail_q <= response_tail_q + 1'b1;
      if (core_response_fire)
        response_head_q <= response_head_q + 1'b1;
      unique case ({response_push, core_response_fire})
        2'b10: response_count_q <= response_count_q + 1'b1;
        2'b01: response_count_q <= response_count_q - 1'b1;
        default: begin end
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (response_push) begin
      response_addr_q[response_tail_q] <=
          pending_addr_q[pending_head_q];
      response_data_q[response_tail_q] <= hxi.rsp_rdata;
      response_error_q[response_tail_q] <= hxi.rsp_err;
    end
  end

`ifndef SYNTHESIS
  logic previous_request_stalled_q;
  logic [31:0] previous_request_addr_q;
  logic previous_response_stalled_q;
  logic [31:0] previous_response_data_q;

  initial begin
    assert (FETCH_DEPTH >= 2);
    assert ((FETCH_DEPTH & (FETCH_DEPTH - 1)) == 0);
    assert (EPOCH_WIDTH >= 8);
    assert (CONTROL_GUARD_CYCLES >= 2);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      previous_request_stalled_q <= 1'b0;
      previous_request_addr_q <= '0;
      previous_response_stalled_q <= 1'b0;
      previous_response_data_q <= '0;
    end else begin
      assert (pending_count_q <= count_t'(FETCH_DEPTH));
      assert (response_count_q <= count_t'(FETCH_DEPTH));
      assert (reserved_slots <= (COUNT_WIDTH+1)'(FETCH_DEPTH));
      if (hxi.rsp_valid)
        assert (pending_count_q != 0);
      if (previous_request_stalled_q) begin
        assert (hxi.req_valid);
        assert (hxi.req_addr == previous_request_addr_q);
      end
      if (previous_response_stalled_q && !redirect_detected) begin
        assert (core_rsp_valid_o);
        assert (core_rsp_data_o == previous_response_data_q);
      end
      previous_request_stalled_q <= hxi.req_valid && !hxi.req_ready;
      previous_request_addr_q <= hxi.req_addr;
      previous_response_stalled_q <= core_rsp_valid_o &&
                                     !core_rsp_ready_i;
      previous_response_data_q <= core_rsp_data_o;
    end
  end
`endif
endmodule
