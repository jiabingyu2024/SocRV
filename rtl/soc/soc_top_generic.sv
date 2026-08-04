module soc_top_generic #(
  parameter int unsigned GPIO_WIDTH = 16,
  parameter string CODE_MEM_FILE = "",
  parameter string DATA_MEM_FILE = ""
) (
  input logic clk_i,
  input logic rst_ni,
  input logic uart_rx_i,
  output logic uart_tx_o,
  input logic [GPIO_WIDTH-1:0] gpio_i,
  output logic [GPIO_WIDTH-1:0] gpio_o,
  output logic [GPIO_WIDTH-1:0] gpio_oe_o,
  input logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_i,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic cpu_fault_o
);
  mem_native_if code_mem(clk_i);
  mem_native_if data_mem(clk_i);

  soc_core #(.GPIO_WIDTH(GPIO_WIDTH)) u_soc (
    .clk_i,
    .rst_ni,
    .code_mem,
    .data_mem,
    .uart_rx_i,
    .uart_tx_o,
    .gpio_i,
    .gpio_o,
    .gpio_oe_o,
    .ext_irq_i,
    .test_done_o,
    .test_pass_o,
    .test_code_o,
    .commit_o,
    .cpu_fault_o
  );

  generic_rom #(
    .BYTES(memory_map_pkg::CODE_SIZE),
    .MEM_FILE(CODE_MEM_FILE)
  ) u_code_memory (
    .clk_i,
    .rst_ni,
    .mem(code_mem)
  );

  generic_spram #(
    .BYTES(memory_map_pkg::DATA_SIZE),
    .MEM_FILE(DATA_MEM_FILE)
  ) u_data_memory (
    .clk_i,
    .rst_ni,
    .mem(data_mem)
  );
endmodule
