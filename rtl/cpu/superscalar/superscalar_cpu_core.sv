module superscalar_cpu_core (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.master instr_hxi,
  hxi_if.master data_hxi,
  input logic irq_software_i,
  input logic irq_timer_i,
  input logic irq_external_i,
  output cpu_types_pkg::commit_trace_t commit_o,
  output cpu_types_pkg::perf_counters_t perf_o,
  output logic fault_o
);
  localparam int unsigned DATA_OUTSTANDING_DEPTH = 8;
  localparam int unsigned DATA_PENDING_PTR_W =
      $clog2(DATA_OUTSTANDING_DEPTH);
  localparam int unsigned DATA_PENDING_COUNT_W =
      $clog2(DATA_OUTSTANDING_DEPTH + 1);

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
  logic [3:0] dbg_commit_mem_rmask;
  logic [31:0] dbg_commit_mem_rdata;
  logic [31:0] dbg_commit_mem_wdata;
  logic [3:0] dbg_commit_mem_wstrb;
  logic [4:0] dbg_commit_rs1;
  logic [31:0] dbg_commit_rs1_rdata;
  logic [4:0] dbg_commit_rs2;
  logic [31:0] dbg_commit_rs2_rdata;
  logic [31:0] dbg_commit_tval;
  logic [1:0] dbg_commit_mode;
  logic [31:0] dbg_commit_csr_mstatus;
  logic [31:0] dbg_commit_csr_mie;
  logic [31:0] dbg_commit_csr_mip;
  logic [31:0] dbg_commit_csr_mtvec;
  logic [31:0] dbg_commit_csr_mscratch;
  logic [31:0] dbg_commit_csr_mepc;
  logic [31:0] dbg_commit_csr_mcause;
  logic [31:0] dbg_commit_csr_mtval;
  logic [63:0] dbg_commit_csr_mcycle;
  logic [63:0] dbg_commit_csr_minstret;
  logic [63:0] order_q;
  logic data_bus_fault_q;
  logic data_pending_write_q [0:DATA_OUTSTANDING_DEPTH-1];
  logic [DATA_PENDING_PTR_W-1:0] data_pending_head_q;
  logic [DATA_PENDING_PTR_W-1:0] data_pending_tail_q;
  logic [DATA_PENDING_COUNT_W-1:0] data_pending_count_q;
  logic data_request_credit;
  logic data_request_fire;
  logic data_response_fire;
  logic irq_taken;
  logic [31:0] irq_mip;
  logic irq_event_valid_q;
  logic [31:0] irq_event_mip_q;

  assign core_rst = !rst_ni;

  assign perf_o.cycles = perf_cycle;
  assign perf_o.commits = perf_commit;
  assign perf_o.branches = perf_branch;
  assign perf_o.branch_misses = perf_branch_miss;
  assign perf_o.loads = perf_load;
  assign perf_o.stores = perf_store;
  assign perf_o.dcache_accesses = perf_dcache_access;
  assign perf_o.dcache_misses = perf_dcache_miss;
  assign perf_o.stall_front = perf_stall_front;
  assign perf_o.stall_memory = perf_stall_mem;
  assign perf_o.stall_muldiv = perf_stall_muldiv;
  assign perf_o.stall_raw = perf_stall_load_use;

  assign instr_hxi.req_valid = imem_req_valid;
  assign instr_hxi.req_addr  = imem_addr;
  assign instr_hxi.req_write = 1'b0;
  assign instr_hxi.req_wdata = '0;
  assign instr_hxi.req_wstrb = '0;
  assign instr_hxi.rsp_ready = 1'b1;

  assign data_request_credit =
      data_pending_count_q < DATA_PENDING_COUNT_W'(DATA_OUTSTANDING_DEPTH);
  assign data_hxi.req_valid = dmem_req_valid && data_request_credit;
  // The imported core expresses sub-word stores as an address offset plus an
  // unshifted byte mask.  HXI/mem_native use an aligned word address and lane-
  // aligned data/strobes, so perform the original platform's lane adaptation
  // here at the CPU boundary.
  assign data_hxi.req_addr  = {dmem_req_addr[31:2], 2'b00};
  assign data_hxi.req_write = dmem_req_write;
  assign data_hxi.req_wdata = dmem_req_wdata << {dmem_req_addr[1:0], 3'b000};
  assign data_hxi.req_wstrb = (dmem_req_wstrb << dmem_req_addr[1:0]) & 4'hf;
  assign data_hxi.rsp_ready = 1'b1;
  assign dmem_req_ready = data_hxi.req_ready && data_request_credit;
  assign data_request_fire = data_hxi.req_valid && data_hxi.req_ready;
  assign data_response_fire = data_hxi.rsp_valid && data_hxi.rsp_ready;

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
    .dmem_resp_valid_i(data_hxi.rsp_valid && data_pending_count_q != 0 &&
                       !data_pending_write_q[data_pending_head_q]),
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
    .dbg_commit_mem_rmask_o(dbg_commit_mem_rmask),
    .dbg_commit_mem_rdata_o(dbg_commit_mem_rdata),
    .dbg_commit_mem_wdata_o(dbg_commit_mem_wdata),
    .dbg_commit_mem_wstrb_o(dbg_commit_mem_wstrb),
    .dbg_commit_rs1_o(dbg_commit_rs1),
    .dbg_commit_rs1_rdata_o(dbg_commit_rs1_rdata),
    .dbg_commit_rs2_o(dbg_commit_rs2),
    .dbg_commit_rs2_rdata_o(dbg_commit_rs2_rdata),
    .dbg_commit_tval_o(dbg_commit_tval),
    .dbg_commit_mode_o(dbg_commit_mode),
    .dbg_commit_csr_mstatus_o(dbg_commit_csr_mstatus),
    .dbg_commit_csr_mie_o(dbg_commit_csr_mie),
    .dbg_commit_csr_mip_o(dbg_commit_csr_mip),
    .dbg_commit_csr_mtvec_o(dbg_commit_csr_mtvec),
    .dbg_commit_csr_mscratch_o(dbg_commit_csr_mscratch),
    .dbg_commit_csr_mepc_o(dbg_commit_csr_mepc),
    .dbg_commit_csr_mcause_o(dbg_commit_csr_mcause),
    .dbg_commit_csr_mtval_o(dbg_commit_csr_mtval),
    .dbg_commit_csr_mcycle_o(dbg_commit_csr_mcycle),
    .dbg_commit_csr_minstret_o(dbg_commit_csr_minstret)
  );

  always_comb begin
    commit_o = '0;
    commit_o.valid       = dbg_commit_valid;
    commit_o.retired     = dbg_commit_valid && !dbg_commit_is_trap;
    commit_o.order       = order_q;
    commit_o.pc          = dbg_commit_pc;
    commit_o.pc_rdata    = dbg_commit_pc;
    commit_o.pc_wdata    = dbg_commit_next_pc;
    commit_o.instruction = dbg_commit_inst;
    commit_o.rs1_addr    = dbg_commit_rs1;
    commit_o.rs1_rdata   = dbg_commit_rs1_rdata;
    commit_o.rs2_addr    = dbg_commit_rs2;
    commit_o.rs2_rdata   = dbg_commit_rs2_rdata;
    commit_o.rd_wen      = dbg_commit_wen;
    commit_o.rd_addr     = dbg_commit_rd;
    commit_o.rd_wdata    = dbg_commit_wdata;
    commit_o.sync_trap   = dbg_commit_is_trap;
    commit_o.cause       = dbg_commit_cause;
    commit_o.tval        = dbg_commit_tval;
    commit_o.mode        = dbg_commit_mode;
    commit_o.mem_valid   = dbg_commit_is_load || dbg_commit_is_store;
    commit_o.mem_addr    = dbg_commit_mem_addr;
    commit_o.mem_rmask   = dbg_commit_is_load ? dbg_commit_mem_rmask : 4'd0;
    commit_o.mem_rdata   = dbg_commit_mem_rdata;
    commit_o.mem_wmask   = dbg_commit_is_store ? dbg_commit_mem_wstrb : 4'd0;
    commit_o.mem_wdata   = dbg_commit_mem_wdata;
    commit_o.csr_mstatus = dbg_commit_csr_mstatus;
    commit_o.csr_mie = dbg_commit_csr_mie;
    commit_o.csr_mip = dbg_commit_csr_mip;
    commit_o.csr_mtvec = dbg_commit_csr_mtvec;
    commit_o.csr_mscratch = dbg_commit_csr_mscratch;
    commit_o.csr_mepc = dbg_commit_csr_mepc;
    commit_o.csr_mcause = dbg_commit_csr_mcause;
    commit_o.csr_mtval = dbg_commit_csr_mtval;
    commit_o.csr_mcycle = dbg_commit_csr_mcycle;
    commit_o.csr_minstret = dbg_commit_csr_minstret;
    commit_o.irq_valid = irq_event_valid_q;
    commit_o.irq_next_order = order_q;
    commit_o.irq_mip_pre = irq_event_mip_q;
    commit_o.irq_mip_post = irq_event_mip_q;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      order_q <= '0;
      data_bus_fault_q <= 1'b0;
      data_pending_head_q <= '0;
      data_pending_tail_q <= '0;
      data_pending_count_q <= '0;
      irq_event_valid_q <= 1'b0;
      irq_event_mip_q <= '0;
    end else begin
      irq_event_valid_q <= irq_taken;
      if (irq_taken)
        irq_event_mip_q <= irq_mip;
      if (dbg_commit_valid)
        order_q <= order_q + 64'd1;
      if (data_hxi.rsp_valid && data_hxi.rsp_err)
        data_bus_fault_q <= 1'b1;
      if (data_request_fire) begin
        data_pending_tail_q <= data_pending_tail_q + 1'b1;
      end
      if (data_response_fire)
        data_pending_head_q <= data_pending_head_q + 1'b1;
      unique case ({data_request_fire, data_response_fire})
        2'b10: data_pending_count_q <= data_pending_count_q + 1'b1;
        2'b01: data_pending_count_q <= data_pending_count_q - 1'b1;
        default: begin end
      endcase
    end
  end


  // The valid range is owned by data_pending_count_q, so FIFO payload bits do
  // not need reset and remain outside the asynchronous-reset control process.
  always_ff @(posedge clk_i) begin
    if (data_request_fire)
      data_pending_write_q[data_pending_tail_q] <= data_hxi.req_write;
  end

  assign fault_o = data_bus_fault_q;

  logic unused;
  assign unused = dmem_req_uncached;

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert (data_pending_count_q <=
              DATA_PENDING_COUNT_W'(DATA_OUTSTANDING_DEPTH));
      if (data_hxi.rsp_valid) assert (data_pending_count_q != 0);
    end
  end
`endif
endmodule
