module soc_core #(
  parameter int unsigned GPIO_WIDTH = 16
) (
  input logic clk_i,
  input logic rst_ni,
  mem_native_if.master code_mem,
  mem_native_if.master data_mem,
  input logic uart_rx_i,
  output logic uart_tx_o,
  input logic [GPIO_WIDTH-1:0] gpio_i,
  output logic [GPIO_WIDTH-1:0] gpio_o,
  output logic [GPIO_WIDTH-1:0] gpio_oe_o,
  input logic i2c_scl_i,
  input logic i2c_sda_i,
  output logic i2c_scl_drive_low_o,
  output logic i2c_sda_drive_low_o,
  input logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_i,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic cpu_fault_o
);
  hxi_if cpu_i_hxi(clk_i);
  hxi_if cpu_d_hxi(clk_i);
  hxi_if code_hxi(clk_i);
  hxi_if data_hxi(clk_i);
  hxi_if timer_hxi(clk_i);
  hxi_if irq_hxi(clk_i);
  hxi_if apb_hxi(clk_i);
  hxi_if default_hxi(clk_i);

  logic irq_software;
  logic irq_timer;
  logic irq_external;
  logic uart_irq;
  logic i2c_irq;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] irq_sources;

  logic [31:0] paddr;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] pwdata;
  logic [3:0] pstrb;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;
  logic uart_psel;
  logic gpio_psel;
  logic test_psel;
  logic i2c_psel;
  logic [31:0] uart_prdata;
  logic uart_pready;
  logic uart_pslverr;
  logic [31:0] gpio_prdata;
  logic gpio_pready;
  logic gpio_pslverr;
  logic [31:0] test_prdata;
  logic test_pready;
  logic test_pslverr;
  logic [31:0] i2c_prdata;
  logic i2c_pready;
  logic i2c_pslverr;

  always_comb begin
    irq_sources = ext_irq_i;
    irq_sources[0] = ext_irq_i[0] | uart_irq;
    irq_sources[1] = ext_irq_i[1] | i2c_irq;
  end

  cpu_subsystem u_cpu (
    .clk_i,
    .rst_ni,
    .instr_hxi(cpu_i_hxi),
    .data_hxi(cpu_d_hxi),
    .irq_software_i(irq_software),
    .irq_timer_i(irq_timer),
    .irq_external_i(irq_external),
    .commit_o,
    .fault_o(cpu_fault_o)
  );

  hxi_crossbar u_crossbar (
    .clk_i,
    .rst_ni,
    .m0_i(cpu_i_hxi),
    .m1_i(cpu_d_hxi),
    .s0_o(code_hxi),
    .s1_o(data_hxi),
    .s2_o(timer_hxi),
    .s3_o(irq_hxi),
    .s4_o(apb_hxi),
    .s5_o(default_hxi)
  );

  memory_subsystem u_memory (
    .code_hxi,
    .data_hxi,
    .code_mem,
    .data_mem
  );

  machine_timer u_timer (
    .clk_i,
    .rst_ni,
    .hxi(timer_hxi),
    .irq_timer_o(irq_timer)
  );

  interrupt_controller u_irq (
    .clk_i,
    .rst_ni,
    .ext_irq_i(irq_sources),
    .hxi(irq_hxi),
    .irq_software_o(irq_software),
    .irq_external_o(irq_external)
  );

  hxi_default_slave u_default (
    .clk_i,
    .rst_ni,
    .hxi(default_hxi)
  );

  hxi_to_apb u_hxi_to_apb (
    .clk_i,
    .rst_ni,
    .hxi(apb_hxi),
    .paddr_o(paddr),
    .psel_o(psel),
    .penable_o(penable),
    .pwrite_o(pwrite),
    .pwdata_o(pwdata),
    .pstrb_o(pstrb),
    .prdata_i(prdata),
    .pready_i(pready),
    .pslverr_i(pslverr)
  );

  apb_interconnect u_apb (
    .paddr_i(paddr),
    .psel_i(psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
    .prdata_o(prdata),
    .pready_o(pready),
    .pslverr_o(pslverr),
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
    .test_pslverr_i(test_pslverr),
    .i2c_psel_o(i2c_psel),
    .i2c_prdata_i(i2c_prdata),
    .i2c_pready_i(i2c_pready),
    .i2c_pslverr_i(i2c_pslverr)
  );

  apb_uart u_uart (
    .clk_i,
    .rst_ni,
    .paddr_i(paddr),
    .psel_i(uart_psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
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
    .paddr_i(paddr),
    .psel_i(gpio_psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
    .prdata_o(gpio_prdata),
    .pready_o(gpio_pready),
    .pslverr_o(gpio_pslverr),
    .gpio_i,
    .gpio_o,
    .gpio_oe_o
  );

  apb_i2c_master u_i2c (
    .clk_i,
    .rst_ni,
    .paddr_i(paddr),
    .psel_i(i2c_psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
    .prdata_o(i2c_prdata),
    .pready_o(i2c_pready),
    .pslverr_o(i2c_pslverr),
    .scl_i(i2c_scl_i),
    .sda_i(i2c_sda_i),
    .scl_drive_low_o(i2c_scl_drive_low_o),
    .sda_drive_low_o(i2c_sda_drive_low_o),
    .irq_o(i2c_irq)
  );

  apb_test_status u_test_status (
    .clk_i,
    .rst_ni,
    .paddr_i(paddr),
    .psel_i(test_psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
    .prdata_o(test_prdata),
    .pready_o(test_pready),
    .pslverr_o(test_pslverr),
    .test_done_o,
    .test_pass_o,
    .test_code_o
  );
endmodule
