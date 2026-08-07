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
  rsd_cpu_core_adapter u_core (
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
