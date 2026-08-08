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
  output logic [31:0] perf_icache_misses_o,
  output logic [31:0] perf_load_misses_o,
  output logic [31:0] perf_store_misses_o,
  output logic [31:0] perf_branch_mispredicts_o,
  output logic [31:0] perf_decode_branch_mispredicts_o,
  output logic [31:0] perf_store_load_forwarding_failures_o,
  output logic [31:0] perf_memory_dependency_mispredicts_o,
  output logic perf_icache_stall_o,
  output logic perf_decode_stall_o,
  output logic perf_rename_stall_o,
  output logic perf_backend_stall_o,
  output logic perf_recovery_cycle_o,
  output logic [1:0] perf_recovery_phase_o,
  output logic perf_recovery_to_phase_o,
  output logic perf_recovery_rmt_o,
  output logic perf_recovery_iq_return_o,
  output logic perf_recovery_replay_flush_o,
  output logic perf_recovery_wakeup_flush_o,
  output logic perf_recovery_unable_start_o,
  output logic perf_recovery_commit_exception_o,
  output logic perf_recovery_rw_exception_o,
  output logic perf_recovery_flush_all_o,
  output logic perf_recovery_active_list_o,
  output logic [1:0] perf_branch_event_valid_o,
  output logic [1:0] perf_branch_event_mispred_o,
  output logic [1:0] perf_branch_event_conditional_o,
  output logic [31:0] perf_branch_event_pc0_o,
  output logic [31:0] perf_branch_event_pc1_o,
  output logic [1:0] perf_decode_flush_trigger_o,
  output logic [31:0] perf_decode_branch_pc0_o,
  output logic [31:0] perf_decode_branch_pc1_o,
  output logic perf_rename_no_physreg_o,
  output logic perf_rename_no_iq_o,
  output logic perf_rename_no_rob_o,
  output logic perf_rename_no_lsq_o,
  output logic perf_rename_serialize_o,
  output logic [1:0] perf_dispatch_count_o,
  output logic [2:0] perf_issue_count_o,
  output logic irq_event_valid_o,
  output logic [63:0] irq_event_next_order_o,
  output logic [31:0] irq_event_mip_pre_o,
  output logic [31:0] irq_event_mip_post_o
);
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq;
  cpu_types_pkg::commit_trace_t commit;

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
`ifndef RSD_DISABLE_PERFORMANCE_COUNTER
  assign perf_icache_misses_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numIC_Miss;
  assign perf_load_misses_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numLoadMiss;
  assign perf_store_misses_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numStoreMiss;
  assign perf_branch_mispredicts_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numBranchPredMiss;
  assign perf_decode_branch_mispredicts_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numBranchPredMissDetectedOnDecode;
  assign perf_store_load_forwarding_failures_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numStoreLoadForwardingFail;
  assign perf_memory_dependency_mispredicts_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.perfCounterIF.perfCounter.numMemDepPredMiss;
`else
  assign perf_icache_misses_o = '0;
  assign perf_load_misses_o = '0;
  assign perf_store_misses_o = '0;
  assign perf_branch_mispredicts_o = '0;
  assign perf_decode_branch_mispredicts_o = '0;
  assign perf_store_load_forwarding_failures_o = '0;
  assign perf_memory_dependency_mispredicts_o = '0;
`endif
  assign perf_icache_stall_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.ctrlIF.ifStageSendBubbleLower;
  assign perf_decode_stall_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.ctrlIF.idStageStallUpper;
  assign perf_rename_stall_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.ctrlIF.rnStageSendBubbleLower;
  assign perf_backend_stall_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.ctrlIF.isStageStallUpper;
  assign perf_recovery_cycle_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.phase != 2'd0;
  assign perf_recovery_phase_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.phase;
  assign perf_recovery_to_phase_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.toRecoveryPhase;
  assign perf_recovery_rmt_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.renameLogicRecoveryRMT;
  assign perf_recovery_iq_return_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.issueQueueReturnIndex;
  assign perf_recovery_replay_flush_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.replayQueueFlushedOpExist;
  assign perf_recovery_wakeup_flush_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.wakeupPipelineRegFlushedOpExist;
  assign perf_recovery_unable_start_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.unableToStartRecovery;
  assign perf_recovery_commit_exception_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.exceptionDetectedInCommitStage;
  assign perf_recovery_rw_exception_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.exceptionDetectedInRwStage;
  assign perf_recovery_flush_all_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.flushAllInsns;
  assign perf_recovery_active_list_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.recoveryManagerIF.inRecoveryAL;
  assign perf_branch_event_valid_o[0] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[0].valid;
  assign perf_branch_event_valid_o[1] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[1].valid;
  assign perf_branch_event_mispred_o[0] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[0].mispred;
  assign perf_branch_event_mispred_o[1] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[1].mispred;
  assign perf_branch_event_conditional_o[0] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[0].isCondBr;
  assign perf_branch_event_conditional_o[1] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[1].isCondBr;
  assign perf_branch_event_pc0_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[0].brAddr;
  assign perf_branch_event_pc1_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.npStageIF.brResult[1].brAddr;
  assign perf_decode_flush_trigger_o[0] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.debugIF.idReg[0].flushTriggering;
  assign perf_decode_flush_trigger_o[1] =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.debugIF.idReg[1].flushTriggering;
  assign perf_decode_branch_pc0_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.debugIF.idReg[0].pc;
  assign perf_decode_branch_pc1_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.debugIF.idReg[1].pc;
  assign perf_rename_no_physreg_o =
      !u_dut.u_soc.u_cpu.u_core.u_rsd_core.renameLogicIF.allocatable;
  assign perf_rename_no_iq_o =
      !u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.allocatable;
  assign perf_rename_no_rob_o =
      !u_dut.u_soc.u_cpu.u_core.u_rsd_core.activeListIF.allocatable;
  assign perf_rename_no_lsq_o =
      !u_dut.u_soc.u_cpu.u_core.u_rsd_core.loadStoreUnitIF.allocatable;
  assign perf_rename_serialize_o =
      u_dut.u_soc.u_cpu.u_core.u_rsd_core.rnStage.serialize;
  assign perf_dispatch_count_o =
      {1'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.write[0]} +
      {1'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.write[1]};
  always_comb begin
    perf_issue_count_o =
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.intIssue[0]} +
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.intIssue[1]} +
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.memIssue[0]} +
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.memIssue[1]};
`ifndef RSD_MARCH_UNIFIED_MULDIV_MEM_PIPE
    perf_issue_count_o +=
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.complexIssue[0]};
`endif
`ifdef RSD_MARCH_FP_PIPE
    perf_issue_count_o +=
        {2'b0, u_dut.u_soc.u_cpu.u_core.u_rsd_core.schedulerIF.fpIssue[0]};
`endif
  end
  assign irq_event_valid_o = commit.irq_valid;
  assign irq_event_next_order_o = commit.irq_next_order;
  assign irq_event_mip_pre_o = commit.irq_mip_pre;
  assign irq_event_mip_post_o = commit.irq_mip_post;

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
    .cpu_fault_o
  );

  logic unused;
  assign unused = ^gpio_o ^ ^gpio_oe;
endmodule
