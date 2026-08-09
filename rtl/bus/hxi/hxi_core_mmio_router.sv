module hxi_core_mmio_router (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave  cpu_hxi,
  hxi_if.master timer_hxi,
  hxi_if.master irq_hxi,
  hxi_if.master periph_hxi
);
  import memory_map_pkg::*;

  typedef enum logic [1:0] {
    TARGET_TIMER,
    TARGET_IRQ,
    TARGET_PERIPH
  } target_t;

  logic active_q;
  target_t active_target_q;
  target_t request_target;
  logic request_fire;
  logic response_fire;

  always_comb begin
    if (in_region(cpu_hxi.req_addr, TIMER_BASE, TIMER_SIZE))
      request_target = TARGET_TIMER;
    else if (in_region(cpu_hxi.req_addr, IRQ_CTRL_BASE, IRQ_CTRL_SIZE))
      request_target = TARGET_IRQ;
    else
      request_target = TARGET_PERIPH;
  end

  assign timer_hxi.req_addr = cpu_hxi.req_addr;
  assign timer_hxi.req_write = cpu_hxi.req_write;
  assign timer_hxi.req_wdata = cpu_hxi.req_wdata;
  assign timer_hxi.req_wstrb = cpu_hxi.req_wstrb;
  assign irq_hxi.req_addr = cpu_hxi.req_addr;
  assign irq_hxi.req_write = cpu_hxi.req_write;
  assign irq_hxi.req_wdata = cpu_hxi.req_wdata;
  assign irq_hxi.req_wstrb = cpu_hxi.req_wstrb;
  assign periph_hxi.req_addr = cpu_hxi.req_addr;
  assign periph_hxi.req_write = cpu_hxi.req_write;
  assign periph_hxi.req_wdata = cpu_hxi.req_wdata;
  assign periph_hxi.req_wstrb = cpu_hxi.req_wstrb;

  always_comb begin
    cpu_hxi.req_ready = 1'b0;
    timer_hxi.req_valid = 1'b0;
    irq_hxi.req_valid = 1'b0;
    periph_hxi.req_valid = 1'b0;

    if (!active_q) begin
      unique case (request_target)
        TARGET_TIMER: begin
          timer_hxi.req_valid = cpu_hxi.req_valid;
          cpu_hxi.req_ready = timer_hxi.req_ready;
        end
        TARGET_IRQ: begin
          irq_hxi.req_valid = cpu_hxi.req_valid;
          cpu_hxi.req_ready = irq_hxi.req_ready;
        end
        default: begin
          periph_hxi.req_valid = cpu_hxi.req_valid;
          cpu_hxi.req_ready = periph_hxi.req_ready;
        end
      endcase
    end
  end

  always_comb begin
    cpu_hxi.rsp_valid = 1'b0;
    cpu_hxi.rsp_rdata = '0;
    cpu_hxi.rsp_err = 1'b0;
    timer_hxi.rsp_ready = 1'b0;
    irq_hxi.rsp_ready = 1'b0;
    periph_hxi.rsp_ready = 1'b0;

    if (active_q) begin
      unique case (active_target_q)
        TARGET_TIMER: begin
          cpu_hxi.rsp_valid = timer_hxi.rsp_valid;
          cpu_hxi.rsp_rdata = timer_hxi.rsp_rdata;
          cpu_hxi.rsp_err = timer_hxi.rsp_err;
          timer_hxi.rsp_ready = cpu_hxi.rsp_ready;
        end
        TARGET_IRQ: begin
          cpu_hxi.rsp_valid = irq_hxi.rsp_valid;
          cpu_hxi.rsp_rdata = irq_hxi.rsp_rdata;
          cpu_hxi.rsp_err = irq_hxi.rsp_err;
          irq_hxi.rsp_ready = cpu_hxi.rsp_ready;
        end
        default: begin
          cpu_hxi.rsp_valid = periph_hxi.rsp_valid;
          cpu_hxi.rsp_rdata = periph_hxi.rsp_rdata;
          cpu_hxi.rsp_err = periph_hxi.rsp_err;
          periph_hxi.rsp_ready = cpu_hxi.rsp_ready;
        end
      endcase
    end
  end

  assign request_fire = cpu_hxi.req_valid && cpu_hxi.req_ready;
  assign response_fire = cpu_hxi.rsp_valid && cpu_hxi.rsp_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_q <= 1'b0;
      active_target_q <= TARGET_PERIPH;
    end else begin
      if (request_fire) begin
        active_q <= 1'b1;
        active_target_q <= request_target;
      end
      if (response_fire)
        active_q <= 1'b0;
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      if (request_fire) assert (!active_q);
      if (response_fire) assert (active_q);
    end
  end
`endif
endmodule
