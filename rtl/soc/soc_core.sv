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

  logic irq_software_periph;
  logic irq_timer_periph;
  logic irq_external_periph;
  logic [2:0] irq_periph_q;
  logic [2:0] irq_core;

  logic [31:0] paddr;
  logic psel;
  logic penable;
  logic pwrite;
  logic [31:0] pwdata;
  logic [3:0] pstrb;
  logic [31:0] prdata;
  logic pready;
  logic pslverr;

  // Do not feed combinational interrupt reductions directly into a CDC
  // synchronizer.  Register the complete level vector in the peripheral
  // domain so each crossing has a single, auditable source register.
  always_ff @(posedge periph_clk_i) begin
    if (!periph_rst_ni)
      irq_periph_q <= '0;
    else
      irq_periph_q <= {
        irq_external_periph,
        irq_timer_periph,
        irq_software_periph
      };
  end

  level_sync #(.WIDTH(3)) u_irq_sync (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .async_i(irq_periph_q),
    .sync_o(irq_core)
  );

  cpu_subsystem u_cpu (
    .clk_i(core_clk_i),
    .rst_ni(core_rst_ni),
    .instr_hxi(cpu_i_hxi),
    .data_hxi(cpu_d_hxi),
    .irq_software_i(irq_core[0]),
    .irq_timer_i(irq_core[1]),
    .irq_external_i(irq_core[2]),
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

  mmio_cdc_bridge u_mmio_cdc (
    .core_clk_i,
    .core_rst_ni,
    .core_hxi(mmio_hxi),
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
    .ext_irq_i,
    .irq_software_o(irq_software_periph),
    .irq_timer_o(irq_timer_periph),
    .irq_external_o(irq_external_periph),
    .test_done_o,
    .test_pass_o,
    .test_code_o
  );
endmodule
