module fpga_top #(
  parameter int unsigned CORE_CLOCK_HZ = 50_000_000,
  parameter int unsigned PERIPHERAL_CLOCK_HZ = 50_000_000,
  parameter string ICCM_LANE0_INIT_FILE = "",
  parameter string ICCM_LANE1_INIT_FILE = "",
  parameter string ICCM_LANE2_INIT_FILE = "",
  parameter string ICCM_LANE3_INIT_FILE = "",
  parameter string DCCM_BANK0_INIT_FILE = "",
  parameter string DCCM_BANK1_INIT_FILE = "",
  parameter string DCCM_BANK2_INIT_FILE = "",
  parameter string DCCM_BANK3_INIT_FILE = "",
  parameter string DCCM_BANK4_INIT_FILE = "",
  parameter string DCCM_BANK5_INIT_FILE = "",
  parameter string DCCM_BANK6_INIT_FILE = "",
  parameter string DCCM_BANK7_INIT_FILE = ""
) (
  input  logic       i_sys_clk,
  input  logic       i_uart_rx,
  output logic       o_uart_tx,
  output logic [3:0] o_led
);
  logic core_clk;
  logic peripheral_clk;
  logic core_rst_n;
  logic clock_locked;
  logic [15:0] gpio_i;
  logic [15:0] gpio_o;
  logic [15:0] gpio_oe;
  logic test_done;
  logic test_pass;
  logic [31:0] test_code;
  logic cpu_fault;
  logic [31:0] test_status;

  assign gpio_i = '0;
  assign test_done = (test_status == 32'h5041_5353) ||
                     (test_status == 32'h4641_494c);
  assign test_pass = test_status == 32'h5041_5353;
  assign cpu_fault = test_status == 32'h4641_494c;

  board_clock_reset u_clock_reset (
    .sys_clk_i(i_sys_clk),
    .core_clk_o(core_clk),
    .peripheral_clk_o(peripheral_clk),
    .core_rst_no(core_rst_n),
    .clock_locked_o(clock_locked)
  );

  soc_top #(
    .CORE_CLOCK_HZ(CORE_CLOCK_HZ),
    .PERIPHERAL_CLOCK_HZ(PERIPHERAL_CLOCK_HZ),
    .ICCM_LANE0_INIT_FILE(ICCM_LANE0_INIT_FILE),
    .ICCM_LANE1_INIT_FILE(ICCM_LANE1_INIT_FILE),
    .ICCM_LANE2_INIT_FILE(ICCM_LANE2_INIT_FILE),
    .ICCM_LANE3_INIT_FILE(ICCM_LANE3_INIT_FILE),
    .DCCM_BANK0_INIT_FILE(DCCM_BANK0_INIT_FILE),
    .DCCM_BANK1_INIT_FILE(DCCM_BANK1_INIT_FILE),
    .DCCM_BANK2_INIT_FILE(DCCM_BANK2_INIT_FILE),
    .DCCM_BANK3_INIT_FILE(DCCM_BANK3_INIT_FILE),
    .DCCM_BANK4_INIT_FILE(DCCM_BANK4_INIT_FILE),
    .DCCM_BANK5_INIT_FILE(DCCM_BANK5_INIT_FILE),
    .DCCM_BANK6_INIT_FILE(DCCM_BANK6_INIT_FILE),
    .DCCM_BANK7_INIT_FILE(DCCM_BANK7_INIT_FILE)
  ) u_soc (
    .core_clk(core_clk),
    .peripheral_clk(peripheral_clk),
    .rst_n(core_rst_n),
    .uart_rx(i_uart_rx),
    .uart_tx(o_uart_tx),
    .gpio_in(gpio_i),
    .gpio_out(gpio_o),
    .gpio_oe(gpio_oe),
    .test_status(test_status),
    .test_code(test_code)
  );

  board_io_wrapper u_board_io (
    .gpio_o_i(gpio_o),
    .gpio_oe_i(gpio_oe),
    .test_done_i(test_done),
    .test_pass_i(test_pass),
    .cpu_fault_i(cpu_fault),
    .clock_locked_i(clock_locked),
    .led_o(o_led)
  );
endmodule
