module cpu_subsystem (
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
  biriscv_cpu_core #(
    .RESET_VECTOR(cpu_config_pkg::CPU_RESET_VECTOR),
    .CACHE_ADDR_MIN(memory_map_pkg::DATA_BASE),
    .CACHE_ADDR_MAX(memory_map_pkg::DATA_BASE + memory_map_pkg::DATA_SIZE - 1),
    .SUPPORT_DUAL_ISSUE(0)
  ) u_core (
    .clk_i,
    .rst_ni,
    .instr_hxi,
    .data_hxi,
    .irq_software_i,
    .irq_timer_i,
    .irq_external_i,
    .commit_o,
    .fault_o
  );
endmodule
