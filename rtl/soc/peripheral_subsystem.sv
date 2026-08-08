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
  input logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_i,
  output logic irq_software_o,
  output logic irq_timer_o,
  output logic irq_external_o,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o
);
  logic timer_psel;
  logic irq_psel;
  logic uart_psel;
  logic gpio_psel;
  logic test_psel;
  logic [31:0] timer_prdata;
  logic timer_pready;
  logic timer_pslverr;
  logic [31:0] irq_prdata;
  logic irq_pready;
  logic irq_pslverr;
  logic [31:0] uart_prdata;
  logic uart_pready;
  logic uart_pslverr;
  logic [31:0] gpio_prdata;
  logic gpio_pready;
  logic gpio_pslverr;
  logic [31:0] test_prdata;
  logic test_pready;
  logic test_pslverr;
  logic uart_irq;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_sync;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] irq_sources;

  level_sync #(
    .WIDTH(soc_config_pkg::EXT_IRQ_COUNT)
  ) u_ext_irq_sync (
    .clk_i,
    .rst_ni,
    .async_i(ext_irq_i),
    .sync_o(ext_irq_sync)
  );

  always_comb begin
    irq_sources = ext_irq_sync;
    irq_sources[0] = ext_irq_sync[0] | uart_irq;
  end

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
    .timer_psel_o(timer_psel),
    .timer_prdata_i(timer_prdata),
    .timer_pready_i(timer_pready),
    .timer_pslverr_i(timer_pslverr),
    .irq_psel_o(irq_psel),
    .irq_prdata_i(irq_prdata),
    .irq_pready_i(irq_pready),
    .irq_pslverr_i(irq_pslverr),
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

  apb_machine_timer u_timer (
    .clk_i,
    .rst_ni,
    .paddr_i,
    .psel_i(timer_psel),
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o(timer_prdata),
    .pready_o(timer_pready),
    .pslverr_o(timer_pslverr),
    .irq_timer_o
  );

  apb_interrupt_controller u_irq (
    .clk_i,
    .rst_ni,
    .ext_irq_i(irq_sources),
    .paddr_i,
    .psel_i(irq_psel),
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .pstrb_i,
    .prdata_o(irq_prdata),
    .pready_o(irq_pready),
    .pslverr_o(irq_pslverr),
    .irq_software_o,
    .irq_external_o
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
    .irq_o(uart_irq)
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
