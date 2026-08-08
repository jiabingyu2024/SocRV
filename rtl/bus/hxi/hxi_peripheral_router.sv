module hxi_peripheral_router (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave  input_i,
  hxi_if.master timer_o,
  hxi_if.master irq_o,
  hxi_if.master apb_o,
  hxi_if.master default_o
);
  import memory_map_pkg::*;

  typedef enum logic [1:0] {TARGET_TIMER, TARGET_IRQ, TARGET_APB, TARGET_DEFAULT} target_t;
  target_t target_now;
  target_t target_q;
  logic busy_q;
  logic req_fire;
  logic rsp_fire;

  always_comb begin
    if (in_region(input_i.req_addr, TIMER_BASE, TIMER_SIZE))
      target_now = TARGET_TIMER;
    else if (in_region(input_i.req_addr, IRQ_CTRL_BASE, IRQ_CTRL_SIZE))
      target_now = TARGET_IRQ;
    else if (in_region(input_i.req_addr, APB_BASE, APB_SIZE))
      target_now = TARGET_APB;
    else
      target_now = TARGET_DEFAULT;
  end

  always_comb begin
    timer_o.req_valid = 1'b0;
    irq_o.req_valid = 1'b0;
    apb_o.req_valid = 1'b0;
    default_o.req_valid = 1'b0;
    timer_o.req_addr = input_i.req_addr;
    irq_o.req_addr = input_i.req_addr;
    apb_o.req_addr = input_i.req_addr;
    default_o.req_addr = input_i.req_addr;
    timer_o.req_write = input_i.req_write;
    irq_o.req_write = input_i.req_write;
    apb_o.req_write = input_i.req_write;
    default_o.req_write = input_i.req_write;
    timer_o.req_wdata = input_i.req_wdata;
    irq_o.req_wdata = input_i.req_wdata;
    apb_o.req_wdata = input_i.req_wdata;
    default_o.req_wdata = input_i.req_wdata;
    timer_o.req_wstrb = input_i.req_wstrb;
    irq_o.req_wstrb = input_i.req_wstrb;
    apb_o.req_wstrb = input_i.req_wstrb;
    default_o.req_wstrb = input_i.req_wstrb;
    timer_o.rsp_ready = 1'b0;
    irq_o.rsp_ready = 1'b0;
    apb_o.rsp_ready = 1'b0;
    default_o.rsp_ready = 1'b0;

    input_i.req_ready = 1'b0;
    input_i.rsp_valid = 1'b0;
    input_i.rsp_rdata = '0;
    input_i.rsp_err = 1'b0;

    if (!busy_q) begin
      case (target_now)
        TARGET_TIMER: begin
          timer_o.req_valid = input_i.req_valid;
          input_i.req_ready = timer_o.req_ready;
        end
        TARGET_IRQ: begin
          irq_o.req_valid = input_i.req_valid;
          input_i.req_ready = irq_o.req_ready;
        end
        TARGET_APB: begin
          apb_o.req_valid = input_i.req_valid;
          input_i.req_ready = apb_o.req_ready;
        end
        TARGET_DEFAULT: begin
          default_o.req_valid = input_i.req_valid;
          input_i.req_ready = default_o.req_ready;
        end
        default: begin end
      endcase
    end else begin
      case (target_q)
        TARGET_TIMER: begin
          input_i.rsp_valid = timer_o.rsp_valid;
          input_i.rsp_rdata = timer_o.rsp_rdata;
          input_i.rsp_err = timer_o.rsp_err;
          timer_o.rsp_ready = input_i.rsp_ready;
        end
        TARGET_IRQ: begin
          input_i.rsp_valid = irq_o.rsp_valid;
          input_i.rsp_rdata = irq_o.rsp_rdata;
          input_i.rsp_err = irq_o.rsp_err;
          irq_o.rsp_ready = input_i.rsp_ready;
        end
        TARGET_APB: begin
          input_i.rsp_valid = apb_o.rsp_valid;
          input_i.rsp_rdata = apb_o.rsp_rdata;
          input_i.rsp_err = apb_o.rsp_err;
          apb_o.rsp_ready = input_i.rsp_ready;
        end
        TARGET_DEFAULT: begin
          input_i.rsp_valid = default_o.rsp_valid;
          input_i.rsp_rdata = default_o.rsp_rdata;
          input_i.rsp_err = default_o.rsp_err;
          default_o.rsp_ready = input_i.rsp_ready;
        end
        default: begin end
      endcase
    end
  end

  assign req_fire = input_i.req_valid && input_i.req_ready;
  assign rsp_fire = input_i.rsp_valid && input_i.rsp_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      target_q <= TARGET_DEFAULT;
      busy_q <= 1'b0;
    end else begin
      if (req_fire) begin
        target_q <= target_now;
        busy_q <= 1'b1;
      end else if (rsp_fire) begin
        busy_q <= 1'b0;
      end
    end
  end
endmodule
