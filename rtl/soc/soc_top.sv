module soc_top #(
   parameter int unsigned CLOCK_HZ   = 250_000_000,
   parameter int unsigned UART_BAUD  = 115_200,
   parameter int unsigned GPIO_WIDTH = 16,
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
   input  logic                  core_clk,
   input  logic                  rst_n,
   input  logic                  uart_rx,
   output logic                  uart_tx,
   input  logic [GPIO_WIDTH-1:0] gpio_in,
   output logic [GPIO_WIDTH-1:0] gpio_out,
   output logic [GPIO_WIDTH-1:0] gpio_oe,
   output logic [31:0]           test_status,
   output logic [31:0]           test_code
);
   logic        mmio_valid;
   logic        mmio_write;
   logic [31:0] mmio_addr;
   logic [31:0] mmio_wdata;
   logic [3:0]  mmio_wstrb;
   logic        mmio_ready;
   logic [31:0] mmio_rdata;
   logic        mmio_error;
   logic        timer_irq;
   logic        software_irq;
   logic        uart_irq_unused;

   local_peripheral_subsystem #(
      .CLOCK_HZ(CLOCK_HZ),
      .UART_BAUD(UART_BAUD),
      .GPIO_WIDTH(GPIO_WIDTH)
   ) peripherals (
      .clk(core_clk), .rst_l(rst_n),
      .req_valid(mmio_valid), .req_write(mmio_write), .req_addr(mmio_addr),
      .req_wdata(mmio_wdata), .req_wstrb(mmio_wstrb),
      .req_ready(mmio_ready), .req_rdata(mmio_rdata), .req_error(mmio_error),
      .uart_rx, .uart_tx, .gpio_in, .gpio_out, .gpio_oe,
      .timer_irq, .software_irq, .uart_irq(uart_irq_unused),
      .test_status, .test_code
   );

   veer_wrapper #(
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
   ) core (
      .clk(core_clk),
      .rst_l(rst_n),
      .dbg_rst_l(rst_n),
      .rst_vec(31'b0),
      .nmi_int(1'b0),
      .nmi_vec(31'b0),
      .jtag_id(31'h0cafe001),
      .trace_rv_i_insn_ip(),
      .trace_rv_i_address_ip(),
      .trace_rv_i_valid_ip(),
      .trace_rv_i_exception_ip(),
      .trace_rv_i_ecause_ip(),
      .trace_rv_i_interrupt_ip(),
      .trace_rv_i_tval_ip(),
      .lsu_bus_clk_en(1'b1),
      .ifu_bus_clk_en(1'b1),
      .dbg_bus_clk_en(1'b1),
      .dma_bus_clk_en(1'b1),
      // EH1 exposes a direct machine-timer interrupt but no direct MSIP pin.
      // SYSCTRL software requests therefore share cause 7; the BSP reads the
      // pending bit first and performs either a scheduler switch or a tick.
      .timer_int(timer_irq | software_irq),
      .extintsrc_req('0),
      .lsu_mmio_valid(mmio_valid),
      .lsu_mmio_write(mmio_write),
      .lsu_mmio_addr(mmio_addr),
      .lsu_mmio_wdata(mmio_wdata),
      .lsu_mmio_wstrb(mmio_wstrb),
      .lsu_mmio_ready(mmio_ready),
      .lsu_mmio_rdata(mmio_rdata),
      .lsu_mmio_error(mmio_error),
      .dec_tlu_perfcnt0(), .dec_tlu_perfcnt1(),
      .dec_tlu_perfcnt2(), .dec_tlu_perfcnt3(),
      .jtag_tck(1'b0), .jtag_tms(1'b1), .jtag_tdi(1'b0),
      .jtag_trst_n(rst_n), .jtag_tdo(),
      .mpc_debug_halt_req(1'b0), .mpc_debug_run_req(1'b0),
      .mpc_reset_run_req(1'b1), .mpc_debug_halt_ack(),
      .mpc_debug_run_ack(), .debug_brkpt_status(),
      .i_cpu_halt_req(1'b0), .o_cpu_halt_ack(), .o_cpu_halt_status(),
      .o_debug_mode_status(), .i_cpu_run_req(1'b0), .o_cpu_run_ack(),
      .scan_mode(1'b0), .mbist_mode(1'b0)
   );
endmodule
