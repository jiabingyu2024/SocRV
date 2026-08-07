module soc_sim_top (
  input logic clk_i,
  input logic rst_ni,
  input logic uart_rx_i,
  output logic uart_tx_o,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o,
  output logic cpu_fault_o,
  output logic commit_valid_o,
  output logic commit_retired_o,
  output logic [63:0] commit_order_o,
  output logic [31:0] commit_pc_o,
  output logic [31:0] commit_next_pc_o,
  output logic [31:0] commit_instruction_o,
  output logic [4:0] commit_rs1_addr_o,
  output logic [31:0] commit_rs1_rdata_o,
  output logic [4:0] commit_rs2_addr_o,
  output logic [31:0] commit_rs2_rdata_o,
  output logic commit_rd_wen_o,
  output logic [4:0] commit_rd_addr_o,
  output logic [31:0] commit_rd_wdata_o,
  output logic commit_sync_trap_o,
  output logic [31:0] commit_cause_o,
  output logic [31:0] commit_tval_o,
  output logic [1:0] commit_mode_o,
  output logic commit_mem_valid_o,
  output logic [31:0] commit_mem_addr_o,
  output logic [3:0] commit_mem_rmask_o,
  output logic [3:0] commit_mem_wmask_o,
  output logic [31:0] commit_mem_rdata_o,
  output logic [31:0] commit_mem_wdata_o,
  output logic [31:0] commit_csr_mstatus_o,
  output logic [31:0] commit_csr_mie_o,
  output logic [31:0] commit_csr_mip_o,
  output logic [31:0] commit_csr_mtvec_o,
  output logic [31:0] commit_csr_mscratch_o,
  output logic [31:0] commit_csr_mepc_o,
  output logic [31:0] commit_csr_mcause_o,
  output logic [31:0] commit_csr_mtval_o,
  output logic [63:0] commit_csr_mcycle_o,
  output logic [63:0] commit_csr_minstret_o,
  output logic irq_event_valid_o,
  output logic [63:0] irq_event_next_order_o,
  output logic [31:0] irq_event_mip_pre_o,
  output logic [31:0] irq_event_mip_post_o,
  output logic [63:0] perf_cycles_o,
  output logic [63:0] perf_commits_o,
  output logic [63:0] perf_branches_o,
  output logic [63:0] perf_branch_misses_o,
  output logic [63:0] perf_loads_o,
  output logic [63:0] perf_stores_o,
  output logic [63:0] perf_dcache_accesses_o,
  output logic [63:0] perf_dcache_misses_o,
  output logic [63:0] perf_stall_front_o,
  output logic [63:0] perf_stall_memory_o,
  output logic [63:0] perf_stall_muldiv_o,
  output logic [63:0] perf_stall_raw_o
);
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq;
  cpu_types_pkg::commit_trace_t commit;
  cpu_types_pkg::perf_counters_t perf;

  assign gpio_i = '0;
  assign ext_irq = '0;
  assign commit_valid_o = commit.valid;
  assign commit_retired_o = commit.retired;
  assign commit_order_o = commit.order;
  assign commit_pc_o = commit.pc_rdata;
  assign commit_next_pc_o = commit.pc_wdata;
  assign commit_instruction_o = commit.instruction;
  assign commit_rs1_addr_o = commit.rs1_addr;
  assign commit_rs1_rdata_o = commit.rs1_rdata;
  assign commit_rs2_addr_o = commit.rs2_addr;
  assign commit_rs2_rdata_o = commit.rs2_rdata;
  assign commit_rd_wen_o = commit.rd_wen;
  assign commit_rd_addr_o = commit.rd_addr;
  assign commit_rd_wdata_o = commit.rd_wdata;
  assign commit_sync_trap_o = commit.sync_trap;
  assign commit_cause_o = commit.cause;
  assign commit_tval_o = commit.tval;
  assign commit_mode_o = commit.mode;
  assign commit_mem_valid_o = commit.mem_valid;
  assign commit_mem_addr_o = commit.mem_addr;
  assign commit_mem_rmask_o = commit.mem_rmask;
  assign commit_mem_wmask_o = commit.mem_wmask;
  assign commit_mem_rdata_o = commit.mem_rdata;
  assign commit_mem_wdata_o = commit.mem_wdata;
  assign commit_csr_mstatus_o = commit.csr_mstatus;
  assign commit_csr_mie_o = commit.csr_mie;
  assign commit_csr_mip_o = commit.csr_mip;
  assign commit_csr_mtvec_o = commit.csr_mtvec;
  assign commit_csr_mscratch_o = commit.csr_mscratch;
  assign commit_csr_mepc_o = commit.csr_mepc;
  assign commit_csr_mcause_o = commit.csr_mcause;
  assign commit_csr_mtval_o = commit.csr_mtval;
  assign commit_csr_mcycle_o = commit.csr_mcycle;
  assign commit_csr_minstret_o = commit.csr_minstret;
  assign irq_event_valid_o = commit.irq_valid;
  assign irq_event_next_order_o = commit.irq_next_order;
  assign irq_event_mip_pre_o = commit.irq_mip_pre;
  assign irq_event_mip_post_o = commit.irq_mip_post;
  assign perf_cycles_o = perf.cycles;
  assign perf_commits_o = perf.commits;
  assign perf_branches_o = perf.branches;
  assign perf_branch_misses_o = perf.branch_misses;
  assign perf_loads_o = perf.loads;
  assign perf_stores_o = perf.stores;
  assign perf_dcache_accesses_o = perf.dcache_accesses;
  assign perf_dcache_misses_o = perf.dcache_misses;
  assign perf_stall_front_o = perf.stall_front;
  assign perf_stall_memory_o = perf.stall_memory;
  assign perf_stall_muldiv_o = perf.stall_muldiv;
  assign perf_stall_raw_o = perf.stall_raw;

  soc_top_generic u_dut (
    .clk_i,
    .rst_ni,
    .uart_rx_i,
    .uart_tx_o,
    .gpio_i,
    .gpio_o,
    .gpio_oe_o(gpio_oe),
    .ext_irq_i(ext_irq),
    .test_done_o,
    .test_pass_o,
    .test_code_o,
    .commit_o(commit),
    .perf_o(perf),
    .cpu_fault_o
  );

  logic unused;
  assign unused = ^gpio_o ^ ^gpio_oe;
endmodule
