module peripheral_subsystem #(
  parameter int unsigned GPIO_WIDTH = 16
) (
  input logic clk_i,
  input logic rst_ni,
  input logic [31:0] paddr_i,
  input logic psel_i,
  input logic penable_i,
  input logic pwrite_i,
  input logic [31:0] pwdata_i,
  input logic [3:0] pstrb_i,
  output logic [31:0] prdata_o,
  output logic pready_o,
  output logic pslverr_o,
  input logic uart_rx_i,
  output logic uart_tx_o,
  input logic [GPIO_WIDTH-1:0] gpio_i,
  output logic [GPIO_WIDTH-1:0] gpio_o,
  output logic [GPIO_WIDTH-1:0] gpio_oe_o,
  output logic uart_irq_o,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o
);
  logic uart_psel;
  logic gpio_psel;
  logic test_psel;
  logic [31:0] uart_prdata;
  logic uart_pready;
  logic uart_pslverr;
  logic [31:0] gpio_prdata;
  logic gpio_pready;
  logic gpio_pslverr;
  logic [31:0] test_prdata;
  logic test_pready;
  logic test_pslverr;

  apb_interconnect u_apb (
    .paddr_i,
    .psel_i,
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o,
    .pready_o,
    .pslverr_o,
    .uart_psel_o(uart_psel),
    .uart_prdata_i(uart_prdata),
    .uart_pready_i(uart_pready),
    .uart_pslverr_i(uart_pslverr),
    .gpio_psel_o(gpio_psel),
    .gpio_prdata_i(gpio_prdata),
    .gpio_pready_i(gpio_pready),
    .gpio_pslverr_i(gpio_pslverr),
    .test_psel_o(test_psel),
    .test_prdata_i(test_prdata),
    .test_pready_i(test_pready),
    .test_pslverr_i(test_pslverr)
  );

  apb_uart #(
    .CLOCK_HZ(soc_config_pkg::PERIPH_CLOCK_HZ)
  ) u_uart (
    .clk_i,
    .rst_ni,
    .paddr_i,
    .psel_i(uart_psel),
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o(uart_prdata),
    .pready_o(uart_pready),
    .pslverr_o(uart_pslverr),
    .uart_rx_i,
    .uart_tx_o,
    .irq_o(uart_irq_o)
  );

  apb_gpio #(.WIDTH(GPIO_WIDTH)) u_gpio (
    .clk_i,
    .rst_ni,
    .paddr_i,
    .psel_i(gpio_psel),
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o(gpio_prdata),
    .pready_o(gpio_pready),
    .pslverr_o(gpio_pslverr),
    .gpio_i,
    .gpio_o,
    .gpio_oe_o
  );

  apb_test_status u_test_status (
    .clk_i,
    .rst_ni,
    .paddr_i,
    .psel_i(test_psel),
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o(test_prdata),
    .pready_o(test_pready),
    .pslverr_o(test_pslverr),
    .test_done_o,
    .test_pass_o,
    .test_code_o
  );
endmodule
