module hxi_crossbar (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave  m0_i,
  hxi_if.slave  m1_i,
  hxi_if.master s0_o,
  hxi_if.master s1_o,
  hxi_if.master s2_o,
  hxi_if.master s3_o,
  hxi_if.master s4_o,
  hxi_if.master s5_o
);
  import hxi_pkg::*;
  import memory_map_pkg::*;

  logic busy_q;
  logic owner_q;
  logic selected_owner;
  hxi_target_t target_q;
  hxi_target_t selected_target;

  logic selected_req_valid;
  logic [31:0] selected_req_addr;
  logic selected_req_write;
  logic [31:0] selected_req_wdata;
  logic [3:0] selected_req_wstrb;
  logic selected_req_ready;
  logic selected_rsp_valid;
  logic [31:0] selected_rsp_rdata;
  logic selected_rsp_err;
  logic selected_rsp_ready;

  function automatic hxi_target_t decode(input logic [31:0] address);
    if (in_region(address, CODE_BASE, CODE_SIZE))       return HXI_TARGET_CODE;
    if (in_region(address, DATA_BASE, DATA_SIZE))       return HXI_TARGET_DATA;
    if (in_region(address, TIMER_BASE, TIMER_SIZE))     return HXI_TARGET_TIMER;
    if (in_region(address, IRQ_CTRL_BASE, IRQ_CTRL_SIZE)) return HXI_TARGET_IRQ;
    if (in_region(address, APB_BASE, APB_SIZE))         return HXI_TARGET_APB;
    return HXI_TARGET_DEFAULT;
  endfunction

  always_comb begin
    selected_owner     = m1_i.req_valid;
    selected_req_valid = selected_owner ? m1_i.req_valid : m0_i.req_valid;
    selected_req_addr  = selected_owner ? m1_i.req_addr  : m0_i.req_addr;
    selected_req_write = selected_owner ? m1_i.req_write : m0_i.req_write;
    selected_req_wdata = selected_owner ? m1_i.req_wdata : m0_i.req_wdata;
    selected_req_wstrb = selected_owner ? m1_i.req_wstrb : m0_i.req_wstrb;
    selected_target    = decode(selected_req_addr);

    m0_i.req_ready = 1'b0;
    m1_i.req_ready = 1'b0;
    m0_i.rsp_valid = 1'b0;
    m1_i.rsp_valid = 1'b0;
    m0_i.rsp_rdata = '0;
    m1_i.rsp_rdata = '0;
    m0_i.rsp_err   = 1'b0;
    m1_i.rsp_err   = 1'b0;

    s0_o.req_valid = 1'b0;
    s1_o.req_valid = 1'b0;
    s2_o.req_valid = 1'b0;
    s3_o.req_valid = 1'b0;
    s4_o.req_valid = 1'b0;
    s5_o.req_valid = 1'b0;
    s0_o.req_addr  = selected_req_addr;
    s1_o.req_addr  = selected_req_addr;
    s2_o.req_addr  = selected_req_addr;
    s3_o.req_addr  = selected_req_addr;
    s4_o.req_addr  = selected_req_addr;
    s5_o.req_addr  = selected_req_addr;
    s0_o.req_write = selected_req_write;
    s1_o.req_write = selected_req_write;
    s2_o.req_write = selected_req_write;
    s3_o.req_write = selected_req_write;
    s4_o.req_write = selected_req_write;
    s5_o.req_write = selected_req_write;
    s0_o.req_wdata = selected_req_wdata;
    s1_o.req_wdata = selected_req_wdata;
    s2_o.req_wdata = selected_req_wdata;
    s3_o.req_wdata = selected_req_wdata;
    s4_o.req_wdata = selected_req_wdata;
    s5_o.req_wdata = selected_req_wdata;
    s0_o.req_wstrb = selected_req_wstrb;
    s1_o.req_wstrb = selected_req_wstrb;
    s2_o.req_wstrb = selected_req_wstrb;
    s3_o.req_wstrb = selected_req_wstrb;
    s4_o.req_wstrb = selected_req_wstrb;
    s5_o.req_wstrb = selected_req_wstrb;
    s0_o.rsp_ready = 1'b0;
    s1_o.rsp_ready = 1'b0;
    s2_o.rsp_ready = 1'b0;
    s3_o.rsp_ready = 1'b0;
    s4_o.rsp_ready = 1'b0;
    s5_o.rsp_ready = 1'b0;

    selected_req_ready = 1'b0;
    if (!busy_q && selected_req_valid) begin
      case (selected_target)
        HXI_TARGET_CODE: begin
          s0_o.req_valid = 1'b1;
          selected_req_ready = s0_o.req_ready;
        end
        HXI_TARGET_DATA: begin
          s1_o.req_valid = 1'b1;
          selected_req_ready = s1_o.req_ready;
        end
        HXI_TARGET_TIMER: begin
          s2_o.req_valid = 1'b1;
          selected_req_ready = s2_o.req_ready;
        end
        HXI_TARGET_IRQ: begin
          s3_o.req_valid = 1'b1;
          selected_req_ready = s3_o.req_ready;
        end
        HXI_TARGET_APB: begin
          s4_o.req_valid = 1'b1;
          selected_req_ready = s4_o.req_ready;
        end
        default: begin
          s5_o.req_valid = 1'b1;
          selected_req_ready = s5_o.req_ready;
        end
      endcase
      if (selected_owner) m1_i.req_ready = selected_req_ready;
      else                m0_i.req_ready = selected_req_ready;
    end

    selected_rsp_valid = 1'b0;
    selected_rsp_rdata = '0;
    selected_rsp_err   = 1'b0;
    selected_rsp_ready = owner_q ? m1_i.rsp_ready : m0_i.rsp_ready;
    if (busy_q) begin
      case (target_q)
        HXI_TARGET_CODE: begin
          selected_rsp_valid = s0_o.rsp_valid;
          selected_rsp_rdata = s0_o.rsp_rdata;
          selected_rsp_err   = s0_o.rsp_err;
          s0_o.rsp_ready     = selected_rsp_ready;
        end
        HXI_TARGET_DATA: begin
          selected_rsp_valid = s1_o.rsp_valid;
          selected_rsp_rdata = s1_o.rsp_rdata;
          selected_rsp_err   = s1_o.rsp_err;
          s1_o.rsp_ready     = selected_rsp_ready;
        end
        HXI_TARGET_TIMER: begin
          selected_rsp_valid = s2_o.rsp_valid;
          selected_rsp_rdata = s2_o.rsp_rdata;
          selected_rsp_err   = s2_o.rsp_err;
          s2_o.rsp_ready     = selected_rsp_ready;
        end
        HXI_TARGET_IRQ: begin
          selected_rsp_valid = s3_o.rsp_valid;
          selected_rsp_rdata = s3_o.rsp_rdata;
          selected_rsp_err   = s3_o.rsp_err;
          s3_o.rsp_ready     = selected_rsp_ready;
        end
        HXI_TARGET_APB: begin
          selected_rsp_valid = s4_o.rsp_valid;
          selected_rsp_rdata = s4_o.rsp_rdata;
          selected_rsp_err   = s4_o.rsp_err;
          s4_o.rsp_ready     = selected_rsp_ready;
        end
        default: begin
          selected_rsp_valid = s5_o.rsp_valid;
          selected_rsp_rdata = s5_o.rsp_rdata;
          selected_rsp_err   = s5_o.rsp_err;
          s5_o.rsp_ready     = selected_rsp_ready;
        end
      endcase
      if (owner_q) begin
        m1_i.rsp_valid = selected_rsp_valid;
        m1_i.rsp_rdata = selected_rsp_rdata;
        m1_i.rsp_err   = selected_rsp_err;
      end else begin
        m0_i.rsp_valid = selected_rsp_valid;
        m0_i.rsp_rdata = selected_rsp_rdata;
        m0_i.rsp_err   = selected_rsp_err;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q   <= 1'b0;
      owner_q  <= 1'b0;
      target_q <= HXI_TARGET_DEFAULT;
    end else begin
      if (!busy_q && selected_req_valid && selected_req_ready) begin
        busy_q   <= 1'b1;
        owner_q  <= selected_owner;
        target_q <= selected_target;
      end else if (busy_q && selected_rsp_valid && selected_rsp_ready) begin
        busy_q <= 1'b0;
      end
    end
  end
endmodule
