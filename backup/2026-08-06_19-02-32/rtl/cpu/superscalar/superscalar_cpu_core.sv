module superscalar_cpu_core (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.master instr_hxi,
  hxi_if.master data_hxi,
  input logic irq_software_i,
  input logic irq_timer_i,
  input logic irq_external_i,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic fault_o
);
  logic core_rst;
  logic [31:0] imem_addr;
  logic imem_req_valid;
  logic dmem_req_valid;
  logic dmem_req_ready;
  logic dmem_req_write;
  logic [31:0] dmem_req_addr;
  logic [31:0] dmem_req_wdata;
  logic [3:0] dmem_req_wstrb;
  logic dmem_req_uncached;
  logic [63:0] perf_cycle;
  logic [63:0] perf_commit;
  logic [63:0] perf_branch;
  logic [63:0] perf_branch_miss;
  logic [63:0] perf_load;
  logic [63:0] perf_store;
  logic [63:0] perf_dcache_access;
  logic [63:0] perf_dcache_miss;
  logic [63:0] perf_stall_front;
  logic [63:0] perf_stall_mem;
  logic [63:0] perf_stall_muldiv;
  logic [63:0] perf_stall_load_use;
  logic dbg_commit_valid;
  logic [31:0] dbg_commit_pc;
  logic [31:0] dbg_commit_inst;
  logic dbg_commit_wen;
  logic [4:0] dbg_commit_rd;
  logic [31:0] dbg_commit_wdata;
  logic dbg_commit_is_load;
  logic dbg_commit_is_store;
  logic dbg_commit_is_trap;
  logic [31:0] dbg_commit_cause;
  logic [31:0] dbg_commit_next_pc;
  logic [31:0] dbg_commit_mem_addr;
  logic [31:0] dbg_commit_mem_wdata;
  logic [3:0] dbg_commit_mem_wstrb;
  logic [63:0] order_q;
  logic data_bus_fault_q;
  logic data_pending_write_q;
  logic irq_taken;
  logic [31:0] irq_mip;

  assign core_rst = !rst_ni;

  assign instr_hxi.req_valid = imem_req_valid;
  assign instr_hxi.req_addr  = imem_addr;
  assign instr_hxi.req_write = 1'b0;
  assign instr_hxi.req_wdata = '0;
  assign instr_hxi.req_wstrb = '0;
  assign instr_hxi.rsp_ready = 1'b1;

  assign data_hxi.req_valid = dmem_req_valid;
  // The imported core expresses sub-word stores as an address offset plus an
  // unshifted byte mask.  HXI/mem_native use an aligned word address and lane-
  // aligned data/strobes, so perform the original platform's lane adaptation
  // here at the CPU boundary.
  assign data_hxi.req_addr  = {dmem_req_addr[31:2], 2'b00};
  assign data_hxi.req_write = dmem_req_write;
  assign data_hxi.req_wdata = dmem_req_wdata << {dmem_req_addr[1:0], 3'b000};
  assign data_hxi.req_wstrb = (dmem_req_wstrb << dmem_req_addr[1:0]) & 4'hf;
  assign data_hxi.rsp_ready = 1'b1;
  assign dmem_req_ready = data_hxi.req_ready;

  core_top u_core (
    .clk(clk_i),
    .rst(core_rst),
    .irom_addr_o(imem_addr),
    .irom_ena_o(imem_req_valid),
    .irom_req_ready_i(instr_hxi.req_ready),
    .irom_resp_valid_i(instr_hxi.rsp_valid),
    .irom_data_i(instr_hxi.rsp_rdata),
    .irom_resp_err_i(instr_hxi.rsp_err),
    .dmem_req_valid_o(dmem_req_valid),
    .dmem_req_ready_i(dmem_req_ready),
    .dmem_req_write_o(dmem_req_write),
    .dmem_req_addr_o(dmem_req_addr),
    .dmem_req_wdata_o(dmem_req_wdata),
    .dmem_req_wstrb_o(dmem_req_wstrb),
    .dmem_req_uncached_o(dmem_req_uncached),
    // HXI acknowledges reads and writes.  The imported core's response channel
    // is read-data-only, so never let a preceding store acknowledgement satisfy
    // a younger load waiting inside the DCache.
    .dmem_resp_valid_i(data_hxi.rsp_valid && !data_pending_write_q),
    .dmem_resp_rdata_i(data_hxi.rsp_rdata),
    .irq_software_i(irq_software_i),
    .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),
    .irq_taken_o(irq_taken),
    .irq_mip_o(irq_mip),
    .perf_cycle_o(perf_cycle),
    .perf_commit_o(perf_commit),
    .perf_branch_o(perf_branch),
    .perf_branch_miss_o(perf_branch_miss),
    .perf_load_o(perf_load),
    .perf_store_o(perf_store),
    .perf_dcache_access_o(perf_dcache_access),
    .perf_dcache_miss_o(perf_dcache_miss),
    .perf_stall_front_o(perf_stall_front),
    .perf_stall_mem_o(perf_stall_mem),
    .perf_stall_muldiv_o(perf_stall_muldiv),
    .perf_stall_load_use_o(perf_stall_load_use),
    .dbg_commit_valid_o(dbg_commit_valid),
    .dbg_commit_pc_o(dbg_commit_pc),
    .dbg_commit_inst_o(dbg_commit_inst),
    .dbg_commit_wen_o(dbg_commit_wen),
    .dbg_commit_rd_o(dbg_commit_rd),
    .dbg_commit_wdata_o(dbg_commit_wdata),
    .dbg_commit_is_load_o(dbg_commit_is_load),
    .dbg_commit_is_store_o(dbg_commit_is_store),
    .dbg_commit_is_trap_o(dbg_commit_is_trap),
    .dbg_commit_cause_o(dbg_commit_cause),
    .dbg_commit_next_pc_o(dbg_commit_next_pc),
    .dbg_commit_mem_addr_o(dbg_commit_mem_addr),
    .dbg_commit_mem_wdata_o(dbg_commit_mem_wdata),
    .dbg_commit_mem_wstrb_o(dbg_commit_mem_wstrb)
  );

  always_comb begin
    commit_o = '0;
    commit_o.valid       = dbg_commit_valid;
    commit_o.retired     = dbg_commit_valid && !dbg_commit_is_trap;
    commit_o.order       = order_q;
    commit_o.pc_rdata    = dbg_commit_pc;
    commit_o.pc_wdata    = dbg_commit_next_pc;
    commit_o.instruction = dbg_commit_inst;
    commit_o.rd_wen      = dbg_commit_wen;
    commit_o.rd_addr     = dbg_commit_rd;
    commit_o.rd_wdata    = dbg_commit_wdata;
    commit_o.sync_trap   = dbg_commit_is_trap;
    commit_o.cause       = dbg_commit_cause;
    commit_o.tval        = dbg_commit_is_trap ? dbg_commit_pc : 32'd0;
    commit_o.mode        = 2'b11;
    commit_o.mem_valid   = dbg_commit_is_load || dbg_commit_is_store;
    commit_o.mem_addr    = dbg_commit_mem_addr;
    commit_o.mem_wmask   = dbg_commit_is_store ? dbg_commit_mem_wstrb : 4'd0;
    commit_o.mem_wdata   = dbg_commit_mem_wdata;
    commit_o.csr_mcycle  = perf_cycle;
    commit_o.csr_minstret = perf_commit;
    commit_o.irq_valid = irq_taken;
    commit_o.irq_next_order = order_q;
    commit_o.irq_mip_pre = irq_mip;
    commit_o.irq_mip_post = irq_mip;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      order_q <= '0;
      data_bus_fault_q <= 1'b0;
      data_pending_write_q <= 1'b0;
    end else begin
      if (dbg_commit_valid)
        order_q <= order_q + 64'd1;
      if (data_hxi.rsp_valid && data_hxi.rsp_err)
        data_bus_fault_q <= 1'b1;
      if (data_hxi.req_valid && data_hxi.req_ready)
        data_pending_write_q <= data_hxi.req_write;
      if (data_hxi.rsp_valid && data_hxi.rsp_ready)
        data_pending_write_q <= 1'b0;
    end
  end

  assign fault_o = data_bus_fault_q;

  logic unused;
  assign unused = dmem_req_uncached ^ ^perf_branch ^ ^perf_branch_miss ^
                  ^perf_load ^ ^perf_store ^ ^perf_dcache_access ^
                  ^perf_dcache_miss ^ ^perf_stall_front ^ ^perf_stall_mem ^
                  ^perf_stall_muldiv ^ ^perf_stall_load_use;
endmodule
