module hxi_data_router #(
  parameter int unsigned MAX_LOCAL_OUTSTANDING = 8
) (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave cpu_hxi,
  mem_native_if.master data_mem,
  hxi_if.master mmio_hxi
);
  import memory_map_pkg::*;

  localparam int unsigned COUNT_W = $clog2(MAX_LOCAL_OUTSTANDING + 1);
  logic [COUNT_W-1:0] local_pending_q;
  logic mmio_active_q;
  logic error_active_q;
  logic error_valid_q;
  logic data_target;
  logic mmio_target;
  logic default_target;
  logic local_req_fire;
  logic local_rsp_fire;
  logic mmio_req_fire;
  logic mmio_rsp_fire;

  assign data_target = in_region(cpu_hxi.req_addr, DATA_BASE, DATA_SIZE);
  assign mmio_target = in_region(cpu_hxi.req_addr, TIMER_BASE, TIMER_SIZE) ||
                       in_region(cpu_hxi.req_addr, IRQ_CTRL_BASE, IRQ_CTRL_SIZE) ||
                       in_region(cpu_hxi.req_addr, APB_BASE, APB_SIZE);
  assign default_target = !data_target && !mmio_target;

  // Local BRAM traffic remains fully pipelined.  MMIO and decode errors are
  // admitted only after every older BRAM response has retired, then block all
  // younger requests until their response is consumed.  This provides a
  // small, strongly ordered device boundary without a general crossbar.
  assign data_mem.req_valid = cpu_hxi.req_valid && data_target &&
                              !mmio_active_q && !error_active_q &&
                              local_pending_q < COUNT_W'(MAX_LOCAL_OUTSTANDING);
  assign data_mem.req_addr  = cpu_hxi.req_addr - DATA_BASE;
  assign data_mem.req_write = cpu_hxi.req_write;
  assign data_mem.req_wdata = cpu_hxi.req_wdata;
  assign data_mem.req_wstrb = cpu_hxi.req_wstrb;

  assign mmio_hxi.req_valid = cpu_hxi.req_valid && mmio_target &&
                              !mmio_active_q && !error_active_q &&
                              local_pending_q == 0;
  assign mmio_hxi.req_addr  = cpu_hxi.req_addr;
  assign mmio_hxi.req_write = cpu_hxi.req_write;
  assign mmio_hxi.req_wdata = cpu_hxi.req_wdata;
  assign mmio_hxi.req_wstrb = cpu_hxi.req_wstrb;

  always_comb begin
    cpu_hxi.req_ready = 1'b0;
    if (!mmio_active_q && !error_active_q) begin
      if (data_target &&
          local_pending_q < COUNT_W'(MAX_LOCAL_OUTSTANDING))
        cpu_hxi.req_ready = data_mem.req_ready;
      else if (mmio_target && local_pending_q == 0)
        cpu_hxi.req_ready = mmio_hxi.req_ready;
      else if (default_target && local_pending_q == 0)
        cpu_hxi.req_ready = 1'b1;
    end
  end

  always_comb begin
    cpu_hxi.rsp_valid = 1'b0;
    cpu_hxi.rsp_rdata = '0;
    cpu_hxi.rsp_err = 1'b0;
    data_mem.rsp_ready = 1'b0;
    mmio_hxi.rsp_ready = 1'b0;

    if (mmio_active_q) begin
      cpu_hxi.rsp_valid = mmio_hxi.rsp_valid;
      cpu_hxi.rsp_rdata = mmio_hxi.rsp_rdata;
      cpu_hxi.rsp_err = mmio_hxi.rsp_err;
      mmio_hxi.rsp_ready = cpu_hxi.rsp_ready;
    end else if (error_active_q) begin
      cpu_hxi.rsp_valid = error_valid_q;
      cpu_hxi.rsp_err = 1'b1;
    end else if (local_pending_q != 0) begin
      cpu_hxi.rsp_valid = data_mem.rsp_valid;
      cpu_hxi.rsp_rdata = data_mem.rsp_rdata;
      cpu_hxi.rsp_err = data_mem.rsp_err;
      data_mem.rsp_ready = cpu_hxi.rsp_ready;
    end
  end

  assign local_req_fire = data_mem.req_valid && data_mem.req_ready;
  assign local_rsp_fire = data_mem.rsp_valid && data_mem.rsp_ready;
  assign mmio_req_fire = mmio_hxi.req_valid && mmio_hxi.req_ready;
  assign mmio_rsp_fire = mmio_hxi.rsp_valid && mmio_hxi.rsp_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      local_pending_q <= '0;
      mmio_active_q <= 1'b0;
      error_active_q <= 1'b0;
      error_valid_q <= 1'b0;
    end else begin
      unique case ({local_req_fire, local_rsp_fire})
        2'b10: local_pending_q <= local_pending_q + 1'b1;
        2'b01: local_pending_q <= local_pending_q - 1'b1;
        default: begin end
      endcase
      if (mmio_req_fire)
        mmio_active_q <= 1'b1;
      if (mmio_rsp_fire)
        mmio_active_q <= 1'b0;

      if (cpu_hxi.req_valid && cpu_hxi.req_ready && default_target) begin
        error_active_q <= 1'b1;
        error_valid_q <= 1'b1;
      end
      if (error_valid_q && cpu_hxi.rsp_ready) begin
        error_active_q <= 1'b0;
        error_valid_q <= 1'b0;
      end
    end
  end

`ifndef SYNTHESIS
  initial assert (MAX_LOCAL_OUTSTANDING >= 1);
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert (local_pending_q <= COUNT_W'(MAX_LOCAL_OUTSTANDING));
      assert (!(mmio_active_q && error_active_q));
      if (mmio_active_q || error_active_q)
        assert (local_pending_q == 0);
    end
  end
`endif
endmodule
