module fpga_top #(
  parameter real CLOCK_MULT_F = 5.0,
  parameter real CORE_CLKOUT_DIVIDE_F = 10.0,
  parameter int unsigned PERIPHERAL_CLKOUT_DIVIDE = 20,
  parameter int unsigned CORE_CLOCK_HZ = 100_000_000,
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
  input  logic       i_sys_clk_p,
  input  logic       i_sys_clk_n,
  input  logic       i_uart_rx,
  output logic       o_uart_tx,
  output logic [3:0] o_led,
  inout  wire        sensor_i2c_scl_io,
  inout  wire        sensor_i2c_sda_io
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
  logic i2c_scl_i;
  logic i2c_sda_i;
  logic i2c_scl_drive_low;
  logic i2c_sda_drive_low;

  assign gpio_i = '0;
  assign test_done = (test_status == 32'h5041_5353) ||
                     (test_status == 32'h4641_494c);
  assign test_pass = test_status == 32'h5041_5353;
  assign cpu_fault = test_status == 32'h4641_494c;
  assign sensor_i2c_scl_io = i2c_scl_drive_low ? 1'b0 : 1'bz;
  assign sensor_i2c_sda_io = i2c_sda_drive_low ? 1'b0 : 1'bz;
  assign i2c_scl_i = sensor_i2c_scl_io;
  assign i2c_sda_i = sensor_i2c_sda_io;

  board_clock_reset #(
    .CLOCK_MULT_F(CLOCK_MULT_F),
    .CORE_CLKOUT_DIVIDE_F(CORE_CLKOUT_DIVIDE_F),
    .PERIPHERAL_CLKOUT_DIVIDE(PERIPHERAL_CLKOUT_DIVIDE)
  ) u_clock_reset (
    .sys_clk_p_i(i_sys_clk_p),
    .sys_clk_n_i(i_sys_clk_n),
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
    .i2c_scl_i(i2c_scl_i),
    .i2c_sda_i(i2c_sda_i),
    .i2c_scl_drive_low(i2c_scl_drive_low),
    .i2c_sda_drive_low(i2c_sda_drive_low),
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
