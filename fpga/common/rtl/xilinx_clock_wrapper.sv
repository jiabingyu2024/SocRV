module xilinx_clock_wrapper (
  input logic clk_200mhz_p_i,
  input logic clk_200mhz_n_i,
  input logic reset_i,
  output logic clk_core_o,
  output logic clk_periph_o,
  output logic locked_o
);
  logic clk_input;
  logic clk_feedback;
  logic clk_feedback_buffered;
  logic clk_core_unbuffered;
  logic clk_periph_unbuffered;

  IBUFDS u_input_buffer (
    .I(clk_200mhz_p_i),
    .IB(clk_200mhz_n_i),
    .O(clk_input)
  );

  MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(5.000),
    .DIVCLK_DIVIDE(1),
    .CLKFBOUT_MULT_F(6.000),
    .CLKOUT0_DIVIDE_F(10.000),
    .CLKOUT1_DIVIDE(24),
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
    .CLKOUT1(clk_periph_unbuffered),
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

  BUFG u_periph_clock_buffer (
    .I(clk_periph_unbuffered),
    .O(clk_periph_o)
  );
endmodule
