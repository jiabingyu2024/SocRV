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
  output logic [31:0] commit_pc_o
);
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq;
  cpu_types_pkg::commit_trace_t commit;

  assign gpio_i = '0;
  assign ext_irq = '0;
  assign commit_valid_o = commit.valid;
  assign commit_pc_o = commit.pc;

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
