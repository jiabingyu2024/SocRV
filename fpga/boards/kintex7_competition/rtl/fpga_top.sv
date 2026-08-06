module fpga_top #(
  parameter string CODE_MEM_FILE = "",
  parameter string DATA_MEM_FILE = ""
) (
  input  logic i_sys_clk_p,
  input  logic i_sys_clk_n,
  input  logic i_uart_rx,
  output logic o_uart_tx,
  inout  wire  io_i2c_scl,
  inout  wire  io_i2c_sda,
  output logic [31:0] virtual_led,
  output logic [39:0] virtual_seg
);
  logic soc_clk;
  logic soc_rst_n;
  logic clock_locked;
  mem_native_if code_mem(soc_clk);
  mem_native_if data_mem(soc_clk);
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic i2c_scl_i;
  logic i2c_sda_i;
  logic i2c_scl_drive_low;
  logic i2c_sda_drive_low;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq;
  logic test_done;
  logic test_pass;
  logic [31:0] test_code;
  cpu_types_pkg::commit_trace_t commit;
  logic cpu_fault;

  assign gpio_i = '0;
  assign ext_irq = '0;

  IOBUF u_i2c_scl_iobuf (
    .I(1'b0),
    .T(!i2c_scl_drive_low),
    .O(i2c_scl_i),
    .IO(io_i2c_scl)
  );

  IOBUF u_i2c_sda_iobuf (
    .I(1'b0),
    .T(!i2c_sda_drive_low),
    .O(i2c_sda_i),
    .IO(io_i2c_sda)
  );

  board_clock_reset u_clock_reset (
    .sys_clk_p_i(i_sys_clk_p),
    .sys_clk_n_i(i_sys_clk_n),
    .soc_clk_o(soc_clk),
    .soc_rst_no(soc_rst_n),
    .clock_locked_o(clock_locked)
  );

  soc_core u_soc (
    .clk_i(soc_clk),
    .rst_ni(soc_rst_n),
    .code_mem,
    .data_mem,
    .uart_rx_i(i_uart_rx),
    .uart_tx_o(o_uart_tx),
    .gpio_i,
    .gpio_o,
    .gpio_oe_o(gpio_oe),
    .i2c_scl_i,
    .i2c_sda_i,
    .i2c_scl_drive_low_o(i2c_scl_drive_low),
    .i2c_sda_drive_low_o(i2c_sda_drive_low),
    .ext_irq_i(ext_irq),
    .test_done_o(test_done),
    .test_pass_o(test_pass),
    .test_code_o(test_code),
    .commit_o(commit),
    .cpu_fault_o(cpu_fault)
  );

  xilinx_code_mem_backend #(
    .BYTES(memory_map_pkg::CODE_SIZE),
    .MEM_FILE(CODE_MEM_FILE)
  ) u_code_memory (
    .clk_i(soc_clk),
    .rst_ni(soc_rst_n),
    .mem(code_mem)
  );

  xilinx_data_mem_backend #(
    .BYTES(memory_map_pkg::DATA_SIZE),
    .MEM_FILE(DATA_MEM_FILE)
  ) u_data_memory (
    .clk_i(soc_clk),
    .rst_ni(soc_rst_n),
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
endmodule
