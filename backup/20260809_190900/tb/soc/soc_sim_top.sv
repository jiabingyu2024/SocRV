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
   output logic [31:0] debug_mtval_o
);
   localparam logic [31:0] TEST_PASS_MAGIC = 32'h5041_5353;
   localparam logic [31:0] TEST_FAIL_MAGIC = 32'h4641_494c;

   logic [15:0] gpio_in;
   logic [15:0] gpio_out;
   logic [15:0] gpio_oe;
   logic [31:0] test_status;

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

   soc_top #(
      .CLOCK_HZ(250_000_000),
      .UART_BAUD(115_200),
      .GPIO_WIDTH(16)
   ) dut (
      .core_clk(clk_i),
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
