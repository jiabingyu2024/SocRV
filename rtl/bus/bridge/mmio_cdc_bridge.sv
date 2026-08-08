module mmio_cdc_bridge (
  input logic core_clk_i,
  input logic core_rst_ni,
  hxi_if.slave core_hxi,

  input logic periph_clk_i,
  input logic periph_rst_ni,
  output logic [31:0] paddr_o,
  output logic        psel_o,
  output logic        penable_o,
  output logic        pwrite_o,
  output logic [31:0] pwdata_o,
  output logic [3:0]  pstrb_o,
  input  logic [31:0] prdata_i,
  input  logic        pready_i,
  input  logic        pslverr_i
);
  typedef enum logic [1:0] {P_IDLE, P_SETUP, P_ACCESS} periph_state_t;

  logic core_busy_q;
  logic core_rsp_valid_q;
  logic [31:0] core_req_addr_q;
  logic core_req_write_q;
  logic [31:0] core_req_wdata_q;
  logic [3:0] core_req_wstrb_q;
  logic core_req_toggle_q;
  logic [31:0] core_rsp_rdata_q;
  logic core_rsp_err_q;

  // Bundled-data CDC: the payload crosses through two stages while the
  // transaction toggle crosses through three.  The source holds its payload
  // until the complete request/response handshake has returned.
  (* ASYNC_REG = "TRUE" *) logic [31:0] req_addr_meta_q, req_addr_sync_q;
  (* ASYNC_REG = "TRUE" *) logic req_write_meta_q, req_write_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [31:0] req_wdata_meta_q, req_wdata_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [3:0] req_wstrb_meta_q, req_wstrb_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [2:0] req_toggle_sync_q;

  periph_state_t periph_state_q;
  logic periph_seen_req_toggle_q;
  logic [31:0] periph_addr_q;
  logic periph_write_q;
  logic [31:0] periph_wdata_q;
  logic [3:0] periph_wstrb_q;
  logic [31:0] periph_rsp_rdata_q;
  logic periph_rsp_err_q;
  logic periph_rsp_toggle_q;

  (* ASYNC_REG = "TRUE" *) logic [31:0] rsp_rdata_meta_q, rsp_rdata_sync_q;
  (* ASYNC_REG = "TRUE" *) logic rsp_err_meta_q, rsp_err_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [2:0] rsp_toggle_sync_q;
  logic core_seen_rsp_toggle_q;

  assign core_hxi.req_ready = !core_busy_q && !core_rsp_valid_q;
  assign core_hxi.rsp_valid = core_rsp_valid_q;
  assign core_hxi.rsp_rdata = core_rsp_rdata_q;
  assign core_hxi.rsp_err   = core_rsp_err_q;

  assign paddr_o   = periph_addr_q;
  assign pwrite_o  = periph_write_q;
  assign pwdata_o  = periph_wdata_q;
  assign pstrb_o   = periph_wstrb_q;
  assign psel_o    = periph_state_q == P_SETUP || periph_state_q == P_ACCESS;
  assign penable_o = periph_state_q == P_ACCESS;

  always_ff @(posedge core_clk_i or negedge core_rst_ni) begin
    if (!core_rst_ni) begin
      core_busy_q <= 1'b0;
      core_rsp_valid_q <= 1'b0;
      core_req_addr_q <= '0;
      core_req_write_q <= 1'b0;
      core_req_wdata_q <= '0;
      core_req_wstrb_q <= '0;
      core_req_toggle_q <= 1'b0;
      core_rsp_rdata_q <= '0;
      core_rsp_err_q <= 1'b0;
      rsp_rdata_meta_q <= '0;
      rsp_rdata_sync_q <= '0;
      rsp_err_meta_q <= 1'b0;
      rsp_err_sync_q <= 1'b0;
      rsp_toggle_sync_q <= '0;
      core_seen_rsp_toggle_q <= 1'b0;
    end else begin
      rsp_rdata_meta_q <= periph_rsp_rdata_q;
      rsp_rdata_sync_q <= rsp_rdata_meta_q;
      rsp_err_meta_q <= periph_rsp_err_q;
      rsp_err_sync_q <= rsp_err_meta_q;
      rsp_toggle_sync_q <= {rsp_toggle_sync_q[1:0], periph_rsp_toggle_q};

      if (core_hxi.req_valid && core_hxi.req_ready) begin
        core_req_addr_q <= core_hxi.req_addr;
        core_req_write_q <= core_hxi.req_write;
        core_req_wdata_q <= core_hxi.req_wdata;
        core_req_wstrb_q <= core_hxi.req_wstrb;
        core_req_toggle_q <= !core_req_toggle_q;
        core_busy_q <= 1'b1;
      end
      if (core_busy_q &&
          rsp_toggle_sync_q[2] != core_seen_rsp_toggle_q) begin
        core_seen_rsp_toggle_q <= rsp_toggle_sync_q[2];
        core_rsp_rdata_q <= rsp_rdata_sync_q;
        core_rsp_err_q <= rsp_err_sync_q;
        core_rsp_valid_q <= 1'b1;
        core_busy_q <= 1'b0;
      end
      if (core_rsp_valid_q && core_hxi.rsp_ready)
        core_rsp_valid_q <= 1'b0;
    end
  end

  always_ff @(posedge periph_clk_i or negedge periph_rst_ni) begin
    if (!periph_rst_ni) begin
      req_addr_meta_q <= '0;
      req_addr_sync_q <= '0;
      req_write_meta_q <= 1'b0;
      req_write_sync_q <= 1'b0;
      req_wdata_meta_q <= '0;
      req_wdata_sync_q <= '0;
      req_wstrb_meta_q <= '0;
      req_wstrb_sync_q <= '0;
      req_toggle_sync_q <= '0;
      periph_seen_req_toggle_q <= 1'b0;
      periph_state_q <= P_IDLE;
      periph_addr_q <= '0;
      periph_write_q <= 1'b0;
      periph_wdata_q <= '0;
      periph_wstrb_q <= '0;
      periph_rsp_rdata_q <= '0;
      periph_rsp_err_q <= 1'b0;
      periph_rsp_toggle_q <= 1'b0;
    end else begin
      req_addr_meta_q <= core_req_addr_q;
      req_addr_sync_q <= req_addr_meta_q;
      req_write_meta_q <= core_req_write_q;
      req_write_sync_q <= req_write_meta_q;
      req_wdata_meta_q <= core_req_wdata_q;
      req_wdata_sync_q <= req_wdata_meta_q;
      req_wstrb_meta_q <= core_req_wstrb_q;
      req_wstrb_sync_q <= req_wstrb_meta_q;
      req_toggle_sync_q <= {req_toggle_sync_q[1:0], core_req_toggle_q};

      unique case (periph_state_q)
        P_IDLE: if (req_toggle_sync_q[2] != periph_seen_req_toggle_q) begin
          periph_seen_req_toggle_q <= req_toggle_sync_q[2];
          periph_addr_q <= req_addr_sync_q;
          periph_write_q <= req_write_sync_q;
          periph_wdata_q <= req_wdata_sync_q;
          periph_wstrb_q <= req_wstrb_sync_q;
          periph_state_q <= P_SETUP;
        end
        P_SETUP: periph_state_q <= P_ACCESS;
        P_ACCESS: if (pready_i) begin
          periph_rsp_rdata_q <= prdata_i;
          periph_rsp_err_q <= pslverr_i;
          periph_rsp_toggle_q <= !periph_rsp_toggle_q;
          periph_state_q <= P_IDLE;
        end
        default: periph_state_q <= P_IDLE;
      endcase
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge core_clk_i) begin
    if (core_rst_ni && core_rsp_valid_q)
      assert (!core_busy_q);
  end
`endif
endmodule
