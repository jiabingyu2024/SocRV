module soc_core #(
  parameter int unsigned GPIO_WIDTH = 16
) (
  input logic core_clk_i,
  input logic core_rst_ni,
  input logic periph_clk_i,
  input logic periph_rst_ni,
  mem_native_if.master code_mem,
  mem_native_if.master data_mem,
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
  output logic [1:0] retire_count_o,
  output logic cpu_fault_o
);
  // core_clk domain: CPU tile, caches and both local BRAM paths.
  hxi_if cpu_i_hxi(core_clk_i);
  hxi_if cpu_d_hxi(core_clk_i);
  hxi_if code_hxi(core_clk_i);
  hxi_if data_hxi(core_clk_i);
  hxi_if mmio_core_hxi(core_clk_i);

  // periph_clk domain: all side-effecting slaves sit behind one CDC bridge.
  hxi_if mmio_periph_hxi(periph_clk_i);
  hxi_if timer_hxi(periph_clk_i);
  hxi_if irq_hxi(periph_clk_i);
  hxi_if apb_hxi(periph_clk_i);
  hxi_if default_hxi(periph_clk_i);

  logic irq_software_periph;
  logic irq_timer_periph;
  logic irq_external_periph;
  logic irq_software_core;
  logic irq_timer_core;
  logic irq_external_core;
  logic uart_irq;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_periph;
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
  logic [31:0] uart_prdata;
  logic uart_pready;
  logic uart_pslverr;
  logic [31:0] gpio_prdata;
  logic gpio_pready;
  logic gpio_pslverr;
  logic [31:0] test_prdata;
  logic test_pready;
  logic test_pslverr;

  cdc_sync_level #(
    .WIDTH(soc_config_pkg::EXT_IRQ_COUNT)
  ) u_ext_irq_sync (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .async_i(ext_irq_i),
    .sync_o(ext_irq_periph)
  );

  always_comb begin
    irq_sources = ext_irq_periph;
    irq_sources[0] = ext_irq_periph[0] | uart_irq;
  end

  cdc_sync_level #(.WIDTH(3)) u_irq_to_core_sync (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .async_i({irq_software_periph, irq_timer_periph, irq_external_periph}),
    .sync_o({irq_software_core, irq_timer_core, irq_external_core})
  );

  cpu_subsystem u_cpu (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .instr_hxi(cpu_i_hxi),
    .data_hxi(cpu_d_hxi),
    .irq_software_i(irq_software_core),
    .irq_timer_i(irq_timer_core),
    .irq_external_i(irq_external_core),
    .commit_o,
    .retire_count_o,
    .fault_o(cpu_fault_o)
  );

  // I-cache refill and D-cache local RAM accesses bypass the old six-slave
  // crossbar.  Only D-port requests outside CODE/DATA enter the CDC bridge.
  hxi_cpu_local_router u_local_router (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .instr_i(cpu_i_hxi),
    .data_i(cpu_d_hxi),
    .code_o(code_hxi),
    .data_o(data_hxi),
    .peripheral_o(mmio_core_hxi)
  );

  memory_subsystem u_memory (
    .code_hxi,
    .data_hxi,
    .code_mem,
    .data_mem
  );

  // The bridge permits one strongly ordered MMIO request.  Slow-ready logic
  // is contained here and cannot form a combinational path back into core.
  hxi_async_bridge u_mmio_bridge (
    .src_clk_i(core_clk_i),
    .src_rst_ni(core_rst_ni),
    .dst_clk_i(periph_clk_i),
    .dst_rst_ni(periph_rst_ni),
    .src_hxi(mmio_core_hxi),
    .dst_hxi(mmio_periph_hxi)
  );

  hxi_peripheral_router u_peripheral_router (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .input_i(mmio_periph_hxi),
    .timer_o(timer_hxi),
    .irq_o(irq_hxi),
    .apb_o(apb_hxi),
    .default_o(default_hxi)
  );

  machine_timer u_timer (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .hxi(timer_hxi),
    .irq_timer_o(irq_timer_periph)
  );

  interrupt_controller u_irq (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .ext_irq_i(irq_sources),
    .hxi(irq_hxi),
    .irq_software_o(irq_software_periph),
    .irq_external_o(irq_external_periph)
  );

  hxi_default_slave u_default (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .hxi(default_hxi)
  );

  hxi_to_apb u_hxi_to_apb (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
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
    .test_pslverr_i(test_pslverr)
  );

  apb_uart u_uart (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
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
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
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

  apb_test_status u_test_status (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
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
