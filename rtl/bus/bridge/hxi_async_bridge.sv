module hxi_async_bridge (
  input logic src_clk_i,
  input logic src_rst_ni,
  input logic dst_clk_i,
  input logic dst_rst_ni,
  hxi_if.slave src_hxi,
  hxi_if.master dst_hxi
);
  typedef enum logic [1:0] {DST_IDLE, DST_REQUEST, DST_RESPONSE} dst_state_t;

  logic [31:0] req_addr_q;
  logic        req_write_q;
  logic [31:0] req_wdata_q;
  logic [3:0]  req_wstrb_q;
  logic        req_toggle_q;
  logic        src_wait_q;
  logic        src_rsp_valid_q;
  logic [31:0] src_rsp_rdata_q;
  logic        src_rsp_err_q;

  logic [31:0] dst_rsp_rdata_q;
  logic        dst_rsp_err_q;
  logic        rsp_toggle_q;

  (* ASYNC_REG = "TRUE" *) logic [1:0] req_toggle_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rsp_toggle_sync_q;
  logic req_seen_q;
  logic rsp_seen_q;
  dst_state_t dst_state_q;

  assign src_hxi.req_ready = !src_wait_q && !src_rsp_valid_q;
  assign src_hxi.rsp_valid = src_rsp_valid_q;
  assign src_hxi.rsp_rdata = src_rsp_rdata_q;
  assign src_hxi.rsp_err   = src_rsp_err_q;

  assign dst_hxi.req_valid = (dst_state_q == DST_REQUEST);
  assign dst_hxi.req_addr  = req_addr_q;
  assign dst_hxi.req_write = req_write_q;
  assign dst_hxi.req_wdata = req_wdata_q;
  assign dst_hxi.req_wstrb = req_wstrb_q;
  assign dst_hxi.rsp_ready = (dst_state_q == DST_RESPONSE);

  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
    if (!src_rst_ni) begin
      req_addr_q       <= '0;
      req_write_q      <= 1'b0;
      req_wdata_q      <= '0;
      req_wstrb_q      <= '0;
      req_toggle_q     <= 1'b0;
      src_wait_q       <= 1'b0;
      src_rsp_valid_q  <= 1'b0;
      src_rsp_rdata_q  <= '0;
      src_rsp_err_q    <= 1'b0;
      rsp_toggle_sync_q <= '0;
      rsp_seen_q       <= 1'b0;
    end else begin
      rsp_toggle_sync_q <= {rsp_toggle_sync_q[0], rsp_toggle_q};

      if (src_hxi.req_valid && src_hxi.req_ready) begin
        req_addr_q   <= src_hxi.req_addr;
        req_write_q  <= src_hxi.req_write;
        req_wdata_q  <= src_hxi.req_wdata;
        req_wstrb_q  <= src_hxi.req_wstrb;
        req_toggle_q <= !req_toggle_q;
        src_wait_q   <= 1'b1;
      end

      if (src_wait_q && (rsp_toggle_sync_q[1] != rsp_seen_q)) begin
        src_rsp_rdata_q <= dst_rsp_rdata_q;
        src_rsp_err_q   <= dst_rsp_err_q;
        src_rsp_valid_q <= 1'b1;
        src_wait_q      <= 1'b0;
        rsp_seen_q      <= rsp_toggle_sync_q[1];
      end

      if (src_rsp_valid_q && src_hxi.rsp_ready)
        src_rsp_valid_q <= 1'b0;
    end
  end

  always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin
    if (!dst_rst_ni) begin
      req_toggle_sync_q <= '0;
      req_seen_q        <= 1'b0;
      dst_state_q       <= DST_IDLE;
      dst_rsp_rdata_q   <= '0;
      dst_rsp_err_q     <= 1'b0;
      rsp_toggle_q      <= 1'b0;
    end else begin
      req_toggle_sync_q <= {req_toggle_sync_q[0], req_toggle_q};

      case (dst_state_q)
        DST_IDLE: begin
          if (req_toggle_sync_q[1] != req_seen_q) begin
            req_seen_q  <= req_toggle_sync_q[1];
            dst_state_q <= DST_REQUEST;
          end
        end
        DST_REQUEST: begin
          if (dst_hxi.req_valid && dst_hxi.req_ready)
            dst_state_q <= DST_RESPONSE;
        end
        DST_RESPONSE: begin
          if (dst_hxi.rsp_valid && dst_hxi.rsp_ready) begin
            dst_rsp_rdata_q <= dst_hxi.rsp_rdata;
            dst_rsp_err_q   <= dst_hxi.rsp_err;
            rsp_toggle_q    <= !rsp_toggle_q;
            dst_state_q     <= DST_IDLE;
          end
        end
        default: dst_state_q <= DST_IDLE;
      endcase
    end
  end

endmodule
