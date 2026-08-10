module soc_sim_top (
   input  logic        clk_i,
   input  logic        rst_ni,
   input  logic        uart_rx_i,
   output logic        uart_tx_o,
   output logic        test_done_o,
   output logic        test_pass_o,
   output logic [31:0] test_code_o,
   output logic [2:0]  trace_valid_o,
   output logic [63:0] trace_address_o,
   output logic [63:0] trace_instruction_o,
   output logic [31:0] debug_mepc_o,
   output logic [31:0] debug_mcause_o,
   output logic [31:0] debug_mtval_o,
   output logic [31:0] debug_lsu_start_o,
   output logic [31:0] debug_lsu_end_o,
   output logic [3:0]  debug_lsu_flags_o,
   output logic [7:0]  debug_inst_flags_o,
   output logic [31:0] debug_inst_pc_o,
   output logic [31:0] debug_inst_target_o
);
   localparam logic [31:0] TEST_PASS_MAGIC = 32'h5041_5353;
   localparam logic [31:0] TEST_FAIL_MAGIC = 32'h4641_494c;

   logic [15:0] gpio_in;
   logic [15:0] gpio_out;
   logic [15:0] gpio_oe;
   logic [31:0] test_status;
   logic        peripheral_clk;

   // The simulation contract fixes the core at 100 MHz and the peripherals
   // at 50 MHz.  clk_i is one core cycle per harness step, so this divider is
   // confined to the non-synthesizable simulation wrapper.
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
         peripheral_clk <= 1'b0;
      else
         peripheral_clk <= ~peripheral_clk;
   end

   assign gpio_in     = '0;
   assign test_done_o = (test_status == TEST_PASS_MAGIC) ||
                        (test_status == TEST_FAIL_MAGIC);
   assign test_pass_o = test_status == TEST_PASS_MAGIC;
   assign trace_valid_o = dut.core.trace_rv_i_valid_ip;
   assign trace_address_o = dut.core.trace_rv_i_address_ip;
   assign trace_instruction_o = dut.core.trace_rv_i_insn_ip;
   assign debug_mepc_o = {dut.core.veer.dec.tlu.mepc, 1'b0};
   assign debug_mcause_o = dut.core.veer.dec.tlu.mcause;
   assign debug_mtval_o = dut.core.veer.dec.tlu.mtval;
   assign debug_lsu_start_o = dut.core.veer.lsu.lsu_lsc_ctl.full_addr_dc1;
   assign debug_lsu_end_o = dut.core.veer.lsu.lsu_lsc_ctl.full_end_addr_dc1;
   assign debug_lsu_flags_o = {
      dut.core.veer.lsu.lsu_lsc_ctl.misaligned_fault_dc1,
      dut.core.veer.lsu.lsu_lsc_ctl.access_fault_dc1,
      dut.core.veer.lsu.lsu_lsc_ctl.addr_in_dccm_dc1,
      dut.core.veer.lsu.lsu_lsc_ctl.lsu_pkt_dc1.valid
   };
   assign debug_inst_flags_o = {
      dut.core.veer.dec.tlu.inst_acc_e4,
      dut.core.veer.dec.tlu.exu_i0_br_mp_e4,
      dut.core.veer.dec.tlu.dec_tlu_flush_lower_wb,
      dut.core.veer.dec.tlu.rfpc_i0_e4,
      dut.core.veer.dec.tlu.dec_tlu_i0_valid_e4,
      dut.core.veer.dec.tlu.inst_misaligned_i0_e4,
      dut.core.veer.dec.tlu.exu_i0_inst_misaligned_e4,
      dut.core.veer.exu.i0_flush_path_e4_eff[1]
   };
   assign debug_inst_pc_o = {dut.core.veer.dec.tlu.dec_tlu_i0_pc_e4, 1'b0};
   assign debug_inst_target_o = {
      dut.core.veer.dec.tlu.exu_i0_inst_misaligned_addr_e4, 1'b0
   };

   soc_top #(
      .CORE_CLOCK_HZ(100_000_000),
      .PERIPHERAL_CLOCK_HZ(50_000_000),
      .UART_BAUD(115_200),
      .GPIO_WIDTH(16)
   ) dut (
      .core_clk(clk_i),
      .peripheral_clk(peripheral_clk),
      .rst_n(rst_ni),
      .uart_rx(uart_rx_i),
      .uart_tx(uart_tx_o),
      .gpio_in(gpio_in),
      .gpio_out(gpio_out),
      .gpio_oe(gpio_oe),
      .test_status(test_status),
      .test_code(test_code_o)
   );

   logic unused;
   assign unused = ^gpio_out ^ ^gpio_oe;
endmodule
