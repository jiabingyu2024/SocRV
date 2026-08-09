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
  output logic cpu_fault_o
);
  hxi_if cpu_i_hxi(core_clk_i);
  hxi_if cpu_d_hxi(core_clk_i);
  hxi_if mmio_hxi(core_clk_i);
  hxi_if timer_hxi(core_clk_i);
  hxi_if irq_hxi(core_clk_i);
  hxi_if periph_hxi(core_clk_i);

  logic irq_software_core;
  logic irq_timer_core;
  logic irq_external_core;
  logic uart_irq_periph;
  logic uart_irq_core;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] ext_irq_core;
  logic [soc_config_pkg::EXT_IRQ_COUNT-1:0] irq_sources_core;

  logic [31:0] paddr;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] pwdata;
  logic [3:0] pstrb;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;

  // Only physical peripheral interrupt levels cross into the core domain.
  // The architectural timer and software interrupt stay core-local so their
  // clear operations are visible before mret and cannot be re-delivered by
  // CDC deassertion latency.
  level_sync u_uart_irq_sync (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .async_i(uart_irq_periph),
    .sync_o(uart_irq_core)
  );

  level_sync #(.WIDTH(soc_config_pkg::EXT_IRQ_COUNT)) u_ext_irq_sync (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .async_i(ext_irq_i),
    .sync_o(ext_irq_core)
  );

  always_comb begin
    irq_sources_core = ext_irq_core;
    irq_sources_core[0] = ext_irq_core[0] | uart_irq_core;
  end

  cpu_subsystem u_cpu (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .instr_hxi(cpu_i_hxi),
    .data_hxi(cpu_d_hxi),
    .irq_software_i(irq_software_core),
    .irq_timer_i(irq_timer_core),
    .irq_external_i(irq_external_core),
    .commit_o,
    .fault_o(cpu_fault_o)
  );

  // Instruction traffic has a dedicated path to code BRAM.  It cannot reach
  // data memory or MMIO and therefore carries no SoC decode/arbitration cone.
  hxi_code_mem_slave u_code_path (
    .hxi(cpu_i_hxi),
    .mem(code_mem)
  );

  // The data path selects only local BRAM or the strongly ordered MMIO bridge.
  hxi_data_router u_data_router (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .cpu_hxi(cpu_d_hxi),
    .data_mem,
    .mmio_hxi
  );

  // CPU-architectural MMIO remains in the 120 MHz domain.  This is a
  // one-master router, not a general crossbar, and it is off the BRAM path.
  hxi_core_mmio_router u_core_mmio_router (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .cpu_hxi(mmio_hxi),
    .timer_hxi,
    .irq_hxi,
    .periph_hxi
  );

  machine_timer u_timer (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .hxi(timer_hxi),
    .irq_timer_o(irq_timer_core)
  );

  interrupt_controller u_irq (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .ext_irq_i(irq_sources_core),
    .hxi(irq_hxi),
    .irq_software_o(irq_software_core),
    .irq_external_o(irq_external_core)
  );

  mmio_cdc_bridge u_mmio_cdc (
    .core_clk_i,
    .core_rst_ni,
    .core_hxi(periph_hxi),
    .periph_clk_i,
    .periph_rst_ni,
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

  peripheral_subsystem #(.GPIO_WIDTH(GPIO_WIDTH)) u_peripherals (
    .clk_i(periph_clk_i),
    .rst_ni(periph_rst_ni),
    .paddr_i(paddr),
    .psel_i(psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .pstrb_i(pstrb),
    .prdata_o(prdata),
    .pready_o(pready),
    .pslverr_o(pslverr),
    .uart_rx_i,
    .uart_tx_o,
    .gpio_i,
    .gpio_o,
    .gpio_oe_o,
    .uart_irq_o(uart_irq_periph),
    .test_done_o,
    .test_pass_o,
    .test_code_o
  );
endmodule
