module pynq_z2_clock_wrapper (
  input  logic clk_125mhz_i,
  input  logic reset_i,
  output logic clk_core_o,
  output logic clk_peripheral_o,
  output logic locked_o
);
  logic clk_input;
  logic clk_feedback;
  logic clk_feedback_buffered;
  logic clk_core_unbuffered;
  logic clk_peripheral_unbuffered;

  IBUF u_input_buffer (
    .I(clk_125mhz_i),
    .O(clk_input)
  );

  // 125 MHz * 8 / 20 = 50 MHz. Both SoC domains intentionally run at
  // 50 MHz on this correctness-test target.
  MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(8.000),
    .DIVCLK_DIVIDE(1),
    .CLKFBOUT_MULT_F(8.0),
    .CLKOUT0_DIVIDE_F(20.0),
    .CLKOUT1_DIVIDE(20),
    .STARTUP_WAIT("FALSE")
  ) u_mmcm (
    .CLKIN1(clk_input),
    .CLKFBIN(clk_feedback_buffered),
    .RST(reset_i),
    .PWRDWN(1'b0),
    .CLKFBOUT(clk_feedback),
    .CLKFBOUTB(),
    .CLKOUT0(clk_core_unbuffered),
    .LOCKED(locked_o),
    .CLKOUT0B(),
    .CLKOUT1(clk_peripheral_unbuffered),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6()
  );

  BUFG u_feedback_buffer (
    .I(clk_feedback),
    .O(clk_feedback_buffered)
  );

  BUFG u_core_clock_buffer (
    .I(clk_core_unbuffered),
    .O(clk_core_o)
  );

  BUFG u_peripheral_clock_buffer (
    .I(clk_peripheral_unbuffered),
    .O(clk_peripheral_o)
  );
endmodule
