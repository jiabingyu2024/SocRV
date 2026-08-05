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

  localparam int unsigned MASTER_COUNT = 2;
  localparam int unsigned SLAVE_COUNT  = 6;

  logic [MASTER_COUNT-1:0] master_busy_q;
  hxi_target_t master_target_q [MASTER_COUNT];
  logic [SLAVE_COUNT-1:0] slave_busy_q;
  logic [SLAVE_COUNT-1:0] prefer_m1_q;

  hxi_target_t m0_target;
  hxi_target_t m1_target;
  logic m0_eligible;
  logic m1_eligible;
  logic same_target;
  logic m0_grant;
  logic m1_grant;
  logic m0_req_fire;
  logic m1_req_fire;
  logic m0_rsp_fire;
  logic m1_rsp_fire;

  logic [SLAVE_COUNT-1:0] slave_req_valid;
  logic [SLAVE_COUNT-1:0] slave_req_ready;
  logic [SLAVE_COUNT-1:0][31:0] slave_req_addr;
  logic [SLAVE_COUNT-1:0] slave_req_write;
  logic [SLAVE_COUNT-1:0][31:0] slave_req_wdata;
  logic [SLAVE_COUNT-1:0][3:0] slave_req_wstrb;
  logic [SLAVE_COUNT-1:0] slave_rsp_valid;
  logic [SLAVE_COUNT-1:0] slave_rsp_ready;
  logic [SLAVE_COUNT-1:0][31:0] slave_rsp_rdata;
  logic [SLAVE_COUNT-1:0] slave_rsp_err;

  function automatic hxi_target_t decode(input logic [31:0] address);
    if (in_region(address, CODE_BASE, CODE_SIZE))
      return HXI_TARGET_CODE;
    if (in_region(address, DATA_BASE, DATA_SIZE))
      return HXI_TARGET_DATA;
    if (in_region(address, TIMER_BASE, TIMER_SIZE))
      return HXI_TARGET_TIMER;
    if (in_region(address, IRQ_CTRL_BASE, IRQ_CTRL_SIZE))
      return HXI_TARGET_IRQ;
    if (in_region(address, APB_BASE, APB_SIZE))
      return HXI_TARGET_APB;
    return HXI_TARGET_DEFAULT;
  endfunction

  assign slave_req_ready[HXI_TARGET_CODE]    = s0_o.req_ready;
  assign slave_req_ready[HXI_TARGET_DATA]    = s1_o.req_ready;
  assign slave_req_ready[HXI_TARGET_TIMER]   = s2_o.req_ready;
  assign slave_req_ready[HXI_TARGET_IRQ]     = s3_o.req_ready;
  assign slave_req_ready[HXI_TARGET_APB]     = s4_o.req_ready;
  assign slave_req_ready[HXI_TARGET_DEFAULT] = s5_o.req_ready;

  assign slave_rsp_valid[HXI_TARGET_CODE]    = s0_o.rsp_valid;
  assign slave_rsp_valid[HXI_TARGET_DATA]    = s1_o.rsp_valid;
  assign slave_rsp_valid[HXI_TARGET_TIMER]   = s2_o.rsp_valid;
  assign slave_rsp_valid[HXI_TARGET_IRQ]     = s3_o.rsp_valid;
  assign slave_rsp_valid[HXI_TARGET_APB]     = s4_o.rsp_valid;
  assign slave_rsp_valid[HXI_TARGET_DEFAULT] = s5_o.rsp_valid;

  assign slave_rsp_rdata[HXI_TARGET_CODE]    = s0_o.rsp_rdata;
  assign slave_rsp_rdata[HXI_TARGET_DATA]    = s1_o.rsp_rdata;
  assign slave_rsp_rdata[HXI_TARGET_TIMER]   = s2_o.rsp_rdata;
  assign slave_rsp_rdata[HXI_TARGET_IRQ]     = s3_o.rsp_rdata;
  assign slave_rsp_rdata[HXI_TARGET_APB]     = s4_o.rsp_rdata;
  assign slave_rsp_rdata[HXI_TARGET_DEFAULT] = s5_o.rsp_rdata;

  assign slave_rsp_err[HXI_TARGET_CODE]    = s0_o.rsp_err;
  assign slave_rsp_err[HXI_TARGET_DATA]    = s1_o.rsp_err;
  assign slave_rsp_err[HXI_TARGET_TIMER]   = s2_o.rsp_err;
  assign slave_rsp_err[HXI_TARGET_IRQ]     = s3_o.rsp_err;
  assign slave_rsp_err[HXI_TARGET_APB]     = s4_o.rsp_err;
  assign slave_rsp_err[HXI_TARGET_DEFAULT] = s5_o.rsp_err;

  assign s0_o.req_valid = slave_req_valid[HXI_TARGET_CODE];
  assign s1_o.req_valid = slave_req_valid[HXI_TARGET_DATA];
  assign s2_o.req_valid = slave_req_valid[HXI_TARGET_TIMER];
  assign s3_o.req_valid = slave_req_valid[HXI_TARGET_IRQ];
  assign s4_o.req_valid = slave_req_valid[HXI_TARGET_APB];
  assign s5_o.req_valid = slave_req_valid[HXI_TARGET_DEFAULT];

  assign s0_o.req_addr = slave_req_addr[HXI_TARGET_CODE];
  assign s1_o.req_addr = slave_req_addr[HXI_TARGET_DATA];
  assign s2_o.req_addr = slave_req_addr[HXI_TARGET_TIMER];
  assign s3_o.req_addr = slave_req_addr[HXI_TARGET_IRQ];
  assign s4_o.req_addr = slave_req_addr[HXI_TARGET_APB];
  assign s5_o.req_addr = slave_req_addr[HXI_TARGET_DEFAULT];

  assign s0_o.req_write = slave_req_write[HXI_TARGET_CODE];
  assign s1_o.req_write = slave_req_write[HXI_TARGET_DATA];
  assign s2_o.req_write = slave_req_write[HXI_TARGET_TIMER];
  assign s3_o.req_write = slave_req_write[HXI_TARGET_IRQ];
  assign s4_o.req_write = slave_req_write[HXI_TARGET_APB];
  assign s5_o.req_write = slave_req_write[HXI_TARGET_DEFAULT];

  assign s0_o.req_wdata = slave_req_wdata[HXI_TARGET_CODE];
  assign s1_o.req_wdata = slave_req_wdata[HXI_TARGET_DATA];
  assign s2_o.req_wdata = slave_req_wdata[HXI_TARGET_TIMER];
  assign s3_o.req_wdata = slave_req_wdata[HXI_TARGET_IRQ];
  assign s4_o.req_wdata = slave_req_wdata[HXI_TARGET_APB];
  assign s5_o.req_wdata = slave_req_wdata[HXI_TARGET_DEFAULT];

  assign s0_o.req_wstrb = slave_req_wstrb[HXI_TARGET_CODE];
  assign s1_o.req_wstrb = slave_req_wstrb[HXI_TARGET_DATA];
  assign s2_o.req_wstrb = slave_req_wstrb[HXI_TARGET_TIMER];
  assign s3_o.req_wstrb = slave_req_wstrb[HXI_TARGET_IRQ];
  assign s4_o.req_wstrb = slave_req_wstrb[HXI_TARGET_APB];
  assign s5_o.req_wstrb = slave_req_wstrb[HXI_TARGET_DEFAULT];

  assign s0_o.rsp_ready = slave_rsp_ready[HXI_TARGET_CODE];
  assign s1_o.rsp_ready = slave_rsp_ready[HXI_TARGET_DATA];
  assign s2_o.rsp_ready = slave_rsp_ready[HXI_TARGET_TIMER];
  assign s3_o.rsp_ready = slave_rsp_ready[HXI_TARGET_IRQ];
  assign s4_o.rsp_ready = slave_rsp_ready[HXI_TARGET_APB];
  assign s5_o.rsp_ready = slave_rsp_ready[HXI_TARGET_DEFAULT];

  always_comb begin
    m0_target = decode(m0_i.req_addr);
    m1_target = decode(m1_i.req_addr);

    m0_eligible = m0_i.req_valid && !master_busy_q[0] &&
                  !slave_busy_q[m0_target];
    m1_eligible = m1_i.req_valid && !master_busy_q[1] &&
                  !slave_busy_q[m1_target];
    same_target = m0_eligible && m1_eligible &&
                  (m0_target == m1_target);

    m0_grant = m0_eligible &&
               (!same_target || !prefer_m1_q[m0_target]);
    m1_grant = m1_eligible &&
               (!same_target || prefer_m1_q[m1_target]);

    m0_i.req_ready = 1'b0;
    m1_i.req_ready = 1'b0;
    m0_i.rsp_valid = 1'b0;
    m1_i.rsp_valid = 1'b0;
    m0_i.rsp_rdata = '0;
    m1_i.rsp_rdata = '0;
    m0_i.rsp_err   = 1'b0;
    m1_i.rsp_err   = 1'b0;

    slave_req_valid = '0;
    slave_req_addr  = '0;
    slave_req_write = '0;
    slave_req_wdata = '0;
    slave_req_wstrb = '0;
    slave_rsp_ready = '0;

    if (m0_grant) begin
      slave_req_valid[m0_target] = m0_i.req_valid;
      slave_req_addr[m0_target]  = m0_i.req_addr;
      slave_req_write[m0_target] = m0_i.req_write;
      slave_req_wdata[m0_target] = m0_i.req_wdata;
      slave_req_wstrb[m0_target] = m0_i.req_wstrb;
      m0_i.req_ready = slave_req_ready[m0_target];
    end

    if (m1_grant) begin
      slave_req_valid[m1_target] = m1_i.req_valid;
      slave_req_addr[m1_target]  = m1_i.req_addr;
      slave_req_write[m1_target] = m1_i.req_write;
      slave_req_wdata[m1_target] = m1_i.req_wdata;
      slave_req_wstrb[m1_target] = m1_i.req_wstrb;
      m1_i.req_ready = slave_req_ready[m1_target];
    end

    if (master_busy_q[0]) begin
      m0_i.rsp_valid = slave_rsp_valid[master_target_q[0]];
      m0_i.rsp_rdata = slave_rsp_rdata[master_target_q[0]];
      m0_i.rsp_err   = slave_rsp_err[master_target_q[0]];
      slave_rsp_ready[master_target_q[0]] = m0_i.rsp_ready;
    end

    if (master_busy_q[1]) begin
      m1_i.rsp_valid = slave_rsp_valid[master_target_q[1]];
      m1_i.rsp_rdata = slave_rsp_rdata[master_target_q[1]];
      m1_i.rsp_err   = slave_rsp_err[master_target_q[1]];
      slave_rsp_ready[master_target_q[1]] = m1_i.rsp_ready;
    end

    m0_req_fire = m0_grant && m0_i.req_valid && m0_i.req_ready;
    m1_req_fire = m1_grant && m1_i.req_valid && m1_i.req_ready;
    m0_rsp_fire = master_busy_q[0] && m0_i.rsp_valid &&
                  m0_i.rsp_ready;
    m1_rsp_fire = master_busy_q[1] && m1_i.rsp_valid &&
                  m1_i.rsp_ready;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      master_busy_q      <= '0;
      master_target_q[0] <= HXI_TARGET_DEFAULT;
      master_target_q[1] <= HXI_TARGET_DEFAULT;
      slave_busy_q       <= '0;
      prefer_m1_q        <= '0;
    end else begin
      if (m0_rsp_fire)
        master_busy_q[0] <= 1'b0;
      if (m1_rsp_fire)
        master_busy_q[1] <= 1'b0;

      if (m0_req_fire) begin
        master_busy_q[0]      <= 1'b1;
        master_target_q[0]    <= m0_target;
        slave_busy_q[m0_target] <= 1'b1;
      end
      if (m1_req_fire) begin
        master_busy_q[1]      <= 1'b1;
        master_target_q[1]    <= m1_target;
        slave_busy_q[m1_target] <= 1'b1;
      end

      if (m0_rsp_fire)
        slave_busy_q[master_target_q[0]] <= 1'b0;
      if (m1_rsp_fire)
        slave_busy_q[master_target_q[1]] <= 1'b0;

      if (same_target && (m0_req_fire || m1_req_fire))
        prefer_m1_q[m0_target] <= !prefer_m1_q[m0_target];
    end
  end
endmodule
