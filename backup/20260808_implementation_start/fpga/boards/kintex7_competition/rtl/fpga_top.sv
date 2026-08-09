module fpga_top #(
  parameter string CODE_MEM_FILE = "",
  parameter string DATA_MEM_FILE = ""
) (
  input  logic i_sys_clk_p,
  input  logic i_sys_clk_n,
  input  logic i_uart_rx,
  output logic o_uart_tx,
  output logic [31:0] virtual_led,
  output logic [39:0] virtual_seg
);
  logic core_clk;
  logic periph_clk;
  logic core_rst_n;
  logic periph_rst_n;
  logic clock_locked;
  mem_native_if code_mem(core_clk);
  mem_native_if data_mem(core_clk);
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq;
  logic test_done;
  logic test_pass;
  logic [31:0] test_code;
  cpu_types_pkg::commit_trace_t commit;
  logic [1:0] retire_count;
  logic cpu_fault;

  assign gpio_i = '0;
  assign ext_irq = '0;

  board_clock_reset u_clock_reset (
    .sys_clk_p_i(i_sys_clk_p),
    .sys_clk_n_i(i_sys_clk_n),
    .core_clk_o(core_clk),
    .periph_clk_o(periph_clk),
    .core_rst_no(core_rst_n),
    .periph_rst_no(periph_rst_n),
    .clock_locked_o(clock_locked)
  );

  soc_core u_soc (
    .core_clk_i(core_clk),
    .core_rst_ni(core_rst_n),
    .periph_clk_i(periph_clk),
    .periph_rst_ni(periph_rst_n),
    .code_mem,
    .data_mem,
    .uart_rx_i(i_uart_rx),
    .uart_tx_o(o_uart_tx),
    .gpio_i,
    .gpio_o,
    .gpio_oe_o(gpio_oe),
    .ext_irq_i(ext_irq),
    .test_done_o(test_done),
    .test_pass_o(test_pass),
    .test_code_o(test_code),
    .commit_o(commit),
    .retire_count_o(retire_count),
    .cpu_fault_o(cpu_fault)
  );

  xilinx_code_mem_backend #(
    .BYTES(memory_map_pkg::CODE_SIZE),
    .MEM_FILE(CODE_MEM_FILE)
  ) u_code_memory (
    .clk_i(core_clk),
    .rst_ni(core_rst_n),
    .mem(code_mem)
  );

  xilinx_data_mem_backend #(
    .BYTES(memory_map_pkg::DATA_SIZE),
    .MEM_FILE(DATA_MEM_FILE)
  ) u_data_memory (
    .clk_i(core_clk),
    .rst_ni(core_rst_n),
    .mem(data_mem)
  );

  board_io_wrapper u_board_io (
    .gpio_o_i(gpio_o),
    .gpio_oe_i(gpio_oe),
    .test_done_i(test_done),
    .test_pass_i(test_pass),
    .cpu_fault_i(cpu_fault),
    .clock_locked_i(clock_locked),
    .test_code_i(test_code),
    .commit_pc_i(commit.pc),
    .virtual_led_o(virtual_led),
    .virtual_seg_o(virtual_seg)
  );

  logic unused;
  assign unused = ^retire_count;
endmodule
