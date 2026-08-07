module hxi_crossbar #(
  parameter int unsigned MEMORY_MAX_OUTSTANDING = 8
) (
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
  localparam int unsigned SLAVE_COUNT = 6;
  localparam int unsigned PTR_W = $clog2(MEMORY_MAX_OUTSTANDING);
  localparam int unsigned COUNT_W = $clog2(MEMORY_MAX_OUTSTANDING + 1);

  typedef logic [PTR_W-1:0] fifo_ptr_t;
  typedef logic [COUNT_W-1:0] fifo_count_t;

  // A master route FIFO preserves request order across differently-latent
  // slaves.  Each slave owner FIFO identifies which master receives its next
  // response.  CODE and DATA may hold several requests; side-effecting slaves
  // deliberately retain their original single-outstanding contract.
  hxi_target_t master_route_q [0:MASTER_COUNT-1]
                                  [0:MEMORY_MAX_OUTSTANDING-1];
  fifo_ptr_t master_head_q [0:MASTER_COUNT-1];
  fifo_ptr_t master_tail_q [0:MASTER_COUNT-1];
  fifo_count_t master_count_q [0:MASTER_COUNT-1];

  logic slave_owner_q [0:SLAVE_COUNT-1]
                       [0:MEMORY_MAX_OUTSTANDING-1];
  fifo_ptr_t slave_head_q [0:SLAVE_COUNT-1];
  fifo_ptr_t slave_tail_q [0:SLAVE_COUNT-1];
  fifo_count_t slave_count_q [0:SLAVE_COUNT-1];
  logic [SLAVE_COUNT-1:0] prefer_m1_q;

  hxi_target_t m0_target;
  hxi_target_t m1_target;
  hxi_target_t m0_rsp_target;
  hxi_target_t m1_rsp_target;
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
  logic [SLAVE_COUNT-1:0] slave_push;
  logic [SLAVE_COUNT-1:0] slave_push_owner;
  logic [SLAVE_COUNT-1:0] slave_pop;

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

  function automatic logic slave_has_credit(
      input hxi_target_t target,
      input fifo_count_t count
  );
    if (target == HXI_TARGET_CODE || target == HXI_TARGET_DATA)
      return count < fifo_count_t'(MEMORY_MAX_OUTSTANDING);
    return count == 0;
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

  // Request routing is independent of response backpressure.  Keeping the two
  // cones in separate processes avoids a false combinational loop through an
  // elastic memory slave's req_ready/rsp_ready relationship.
  always_comb begin
    m0_target = decode(m0_i.req_addr);
    m1_target = decode(m1_i.req_addr);
    m0_eligible = m0_i.req_valid &&
                  master_count_q[0] < fifo_count_t'(MEMORY_MAX_OUTSTANDING) &&
                  slave_has_credit(m0_target, slave_count_q[m0_target]);
    m1_eligible = m1_i.req_valid &&
                  master_count_q[1] < fifo_count_t'(MEMORY_MAX_OUTSTANDING) &&
                  slave_has_credit(m1_target, slave_count_q[m1_target]);
    same_target = m0_eligible && m1_eligible &&
                  (m0_target == m1_target);
    m0_grant = m0_eligible &&
               (!same_target || !prefer_m1_q[m0_target]);
    m1_grant = m1_eligible &&
               (!same_target || prefer_m1_q[m1_target]);

    m0_i.req_ready = 1'b0;
    m1_i.req_ready = 1'b0;

    slave_req_valid = '0;
    slave_req_addr = '0;
    slave_req_write = '0;
    slave_req_wdata = '0;
    slave_req_wstrb = '0;
    slave_push = '0;
    slave_push_owner = '0;

    if (m0_grant) begin
      slave_req_valid[m0_target] = m0_i.req_valid;
      slave_req_addr[m0_target] = m0_i.req_addr;
      slave_req_write[m0_target] = m0_i.req_write;
      slave_req_wdata[m0_target] = m0_i.req_wdata;
      slave_req_wstrb[m0_target] = m0_i.req_wstrb;
      m0_i.req_ready = slave_req_ready[m0_target];
    end
    if (m1_grant) begin
      slave_req_valid[m1_target] = m1_i.req_valid;
      slave_req_addr[m1_target] = m1_i.req_addr;
      slave_req_write[m1_target] = m1_i.req_write;
      slave_req_wdata[m1_target] = m1_i.req_wdata;
      slave_req_wstrb[m1_target] = m1_i.req_wstrb;
      m1_i.req_ready = slave_req_ready[m1_target];
    end

    m0_req_fire = m0_grant && m0_i.req_valid && m0_i.req_ready;
    m1_req_fire = m1_grant && m1_i.req_valid && m1_i.req_ready;
    if (m0_req_fire) begin
      slave_push[m0_target] = 1'b1;
      slave_push_owner[m0_target] = 1'b0;
    end
    if (m1_req_fire) begin
      slave_push[m1_target] = 1'b1;
      slave_push_owner[m1_target] = 1'b1;
    end
  end

  // A response may leave a slave only when it is both that slave's oldest
  // owner and the corresponding master's oldest target.
  always_comb begin
    m0_rsp_target = HXI_TARGET_DEFAULT;
    m1_rsp_target = HXI_TARGET_DEFAULT;
    m0_i.rsp_valid = 1'b0;
    m1_i.rsp_valid = 1'b0;
    m0_i.rsp_rdata = '0;
    m1_i.rsp_rdata = '0;
    m0_i.rsp_err = 1'b0;
    m1_i.rsp_err = 1'b0;
    slave_rsp_ready = '0;
    slave_pop = '0;

    if (master_count_q[0] != 0) begin
      m0_rsp_target = master_route_q[0][master_head_q[0]];
      if (slave_count_q[m0_rsp_target] != 0 &&
          slave_owner_q[m0_rsp_target][slave_head_q[m0_rsp_target]] == 1'b0) begin
        m0_i.rsp_valid = slave_rsp_valid[m0_rsp_target];
        m0_i.rsp_rdata = slave_rsp_rdata[m0_rsp_target];
        m0_i.rsp_err = slave_rsp_err[m0_rsp_target];
        slave_rsp_ready[m0_rsp_target] = m0_i.rsp_ready;
      end
    end
    if (master_count_q[1] != 0) begin
      m1_rsp_target = master_route_q[1][master_head_q[1]];
      if (slave_count_q[m1_rsp_target] != 0 &&
          slave_owner_q[m1_rsp_target][slave_head_q[m1_rsp_target]] == 1'b1) begin
        m1_i.rsp_valid = slave_rsp_valid[m1_rsp_target];
        m1_i.rsp_rdata = slave_rsp_rdata[m1_rsp_target];
        m1_i.rsp_err = slave_rsp_err[m1_rsp_target];
        slave_rsp_ready[m1_rsp_target] = m1_i.rsp_ready;
      end
    end

    m0_rsp_fire = m0_i.rsp_valid && m0_i.rsp_ready;
    m1_rsp_fire = m1_i.rsp_valid && m1_i.rsp_ready;
    if (m0_rsp_fire) slave_pop[m0_rsp_target] = 1'b1;
    if (m1_rsp_fire) slave_pop[m1_rsp_target] = 1'b1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prefer_m1_q <= '0;
      for (int unsigned master = 0; master < MASTER_COUNT; master++) begin
        master_head_q[master] <= '0;
        master_tail_q[master] <= '0;
        master_count_q[master] <= '0;
      end
      for (int unsigned slave = 0; slave < SLAVE_COUNT; slave++) begin
        slave_head_q[slave] <= '0;
        slave_tail_q[slave] <= '0;
        slave_count_q[slave] <= '0;
      end
    end else begin
      if (m0_req_fire) begin
        master_tail_q[0] <= master_tail_q[0] + 1'b1;
      end
      if (m1_req_fire) begin
        master_tail_q[1] <= master_tail_q[1] + 1'b1;
      end
      if (m0_rsp_fire) master_head_q[0] <= master_head_q[0] + 1'b1;
      if (m1_rsp_fire) master_head_q[1] <= master_head_q[1] + 1'b1;

      unique case ({m0_req_fire, m0_rsp_fire})
        2'b10: master_count_q[0] <= master_count_q[0] + 1'b1;
        2'b01: master_count_q[0] <= master_count_q[0] - 1'b1;
        default: begin end
      endcase
      unique case ({m1_req_fire, m1_rsp_fire})
        2'b10: master_count_q[1] <= master_count_q[1] + 1'b1;
        2'b01: master_count_q[1] <= master_count_q[1] - 1'b1;
        default: begin end
      endcase

      for (int unsigned slave = 0; slave < SLAVE_COUNT; slave++) begin
        if (slave_push[slave]) begin
          slave_tail_q[slave] <= slave_tail_q[slave] + 1'b1;
        end
        if (slave_pop[slave])
          slave_head_q[slave] <= slave_head_q[slave] + 1'b1;
        unique case ({slave_push[slave], slave_pop[slave]})
          2'b10: slave_count_q[slave] <= slave_count_q[slave] + 1'b1;
          2'b01: slave_count_q[slave] <= slave_count_q[slave] - 1'b1;
          default: begin end
        endcase
      end

      if (same_target && (m0_req_fire || m1_req_fire))
        prefer_m1_q[m0_target] <= !prefer_m1_q[m0_target];
    end
  end

  // FIFO payloads do not require reset; the reset counts make every entry
  // invalid.  Isolating these writes from the asynchronous-reset process keeps
  // Vivado from inferring reset behavior on the payload arrays.
  always_ff @(posedge clk_i) begin
    if (m0_req_fire)
      master_route_q[0][master_tail_q[0]] <= m0_target;
    if (m1_req_fire)
      master_route_q[1][master_tail_q[1]] <= m1_target;
    for (int unsigned slave = 0; slave < SLAVE_COUNT; slave++) begin
      if (slave_push[slave])
        slave_owner_q[slave][slave_tail_q[slave]] <=
            slave_push_owner[slave];
    end
  end

`ifndef SYNTHESIS
  initial begin
    assert (MEMORY_MAX_OUTSTANDING >= 2);
    assert ((MEMORY_MAX_OUTSTANDING & (MEMORY_MAX_OUTSTANDING - 1)) == 0);
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert (master_count_q[0] <= fifo_count_t'(MEMORY_MAX_OUTSTANDING));
      assert (master_count_q[1] <= fifo_count_t'(MEMORY_MAX_OUTSTANDING));
      if (m0_i.rsp_valid) assert (master_count_q[0] != 0);
      if (m1_i.rsp_valid) assert (master_count_q[1] != 0);
      for (int unsigned slave = 0; slave < SLAVE_COUNT; slave++) begin
        assert (slave_count_q[slave] <=
                fifo_count_t'(MEMORY_MAX_OUTSTANDING));
      end
    end
  end
`endif
endmodule
