module soc_top #(
   parameter int unsigned CORE_CLOCK_HZ       = 100_000_000,
   parameter int unsigned PERIPHERAL_CLOCK_HZ = 50_000_000,
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
   input  logic                  peripheral_clk,
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
   logic        periph_mmio_valid;
   logic        periph_mmio_write;
   logic [31:0] periph_mmio_addr;
   logic [31:0] periph_mmio_wdata;
   logic [3:0]  periph_mmio_wstrb;
   logic        periph_mmio_ready;
   logic [31:0] periph_mmio_rdata;
   logic        periph_mmio_error;
   logic        timer_irq_peripheral;
   logic        software_irq_peripheral;
   logic        uart_irq_unused;
   logic        peripheral_rst_n;
   logic [1:0]  peripheral_reset_release_q;
   (* ASYNC_REG = "TRUE" *) logic timer_irq_meta_q, timer_irq_sync_q;
   (* ASYNC_REG = "TRUE" *) logic software_irq_meta_q, software_irq_sync_q;
   logic [31:0] test_status_peripheral, test_code_peripheral;
   logic [31:0] test_status_meta_q, test_code_meta_q;

   // Reset is asserted globally and released synchronously in the slower
   // peripheral domain.  The incoming core reset is already synchronous to
   // core_clk in both the board and simulation wrappers.
   always_ff @(posedge peripheral_clk or negedge rst_n) begin
      if (!rst_n)
         peripheral_reset_release_q <= 2'b00;
      else
         peripheral_reset_release_q <= {peripheral_reset_release_q[0], 1'b1};
   end
   assign peripheral_rst_n = peripheral_reset_release_q[1];

   soc_clock_bridge u_mmio_cdc (
      .core_clk,
      .core_rst_n(rst_n),
      .core_req_valid(mmio_valid),
      .core_req_write(mmio_write),
      .core_req_addr(mmio_addr),
      .core_req_wdata(mmio_wdata),
      .core_req_wstrb(mmio_wstrb),
      .core_req_ready(mmio_ready),
      .core_req_rdata(mmio_rdata),
      .core_req_error(mmio_error),
      .periph_clk(peripheral_clk),
      .periph_rst_n(peripheral_rst_n),
      .periph_req_valid(periph_mmio_valid),
      .periph_req_write(periph_mmio_write),
      .periph_req_addr(periph_mmio_addr),
      .periph_req_wdata(periph_mmio_wdata),
      .periph_req_wstrb(periph_mmio_wstrb),
      .periph_req_ready(periph_mmio_ready),
      .periph_req_rdata(periph_mmio_rdata),
      .periph_req_error(periph_mmio_error)
   );

   local_peripheral_subsystem #(
      .CORE_CLOCK_HZ(CORE_CLOCK_HZ),
      .PERIPHERAL_CLOCK_HZ(PERIPHERAL_CLOCK_HZ),
      .UART_BAUD(UART_BAUD),
      .GPIO_WIDTH(GPIO_WIDTH)
   ) peripherals (
      .clk(peripheral_clk), .rst_l(peripheral_rst_n),
      .req_valid(periph_mmio_valid), .req_write(periph_mmio_write),
      .req_addr(periph_mmio_addr), .req_wdata(periph_mmio_wdata),
      .req_wstrb(periph_mmio_wstrb), .req_ready(periph_mmio_ready),
      .req_rdata(periph_mmio_rdata), .req_error(periph_mmio_error),
      .uart_rx, .uart_tx, .gpio_in, .gpio_out, .gpio_oe,
      .timer_irq(timer_irq_peripheral),
      .software_irq(software_irq_peripheral), .uart_irq(uart_irq_unused),
      .test_status(test_status_peripheral), .test_code(test_code_peripheral)
   );

   // Peripheral interrupts are level signals.  Two-stage synchronizers make
   // them safe for the core domain; the shared EH1 cause remains unchanged.
   // Test status/code are software-held level buses and are similarly sampled
   // twice before they leave soc_top for the simulation/board status logic.
   always_ff @(posedge core_clk or negedge rst_n) begin
      if (!rst_n) begin
         timer_irq_meta_q    <= 1'b0;
         timer_irq_sync_q    <= 1'b0;
         software_irq_meta_q <= 1'b0;
         software_irq_sync_q <= 1'b0;
         test_status_meta_q  <= 32'b0;
         test_status         <= 32'b0;
         test_code_meta_q    <= 32'b0;
         test_code           <= 32'b0;
      end else begin
         timer_irq_meta_q    <= timer_irq_peripheral;
         timer_irq_sync_q    <= timer_irq_meta_q;
         software_irq_meta_q <= software_irq_peripheral;
         software_irq_sync_q <= software_irq_meta_q;
         test_status_meta_q  <= test_status_peripheral;
         test_status         <= test_status_meta_q;
         test_code_meta_q    <= test_code_peripheral;
         test_code           <= test_code_meta_q;
      end
   end

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
      .timer_int(timer_irq_sync_q | software_irq_sync_q),
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
