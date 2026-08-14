module axku062_clock_wrapper #(
  parameter real CLOCK_MULT_F = 5.0,
  parameter real CORE_CLKOUT_DIVIDE_F = 10.0,
  parameter int  PERIPHERAL_CLKOUT_DIVIDE = 20
) (
  input  logic clk_200mhz_p_i,
  input  logic clk_200mhz_n_i,
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

  IBUFDS u_input_buffer (
    .I(clk_200mhz_p_i),
    .IB(clk_200mhz_n_i),
    .O(clk_input)
  );

  MMCME3_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(5.000),
    .DIVCLK_DIVIDE(1),
    .CLKFBOUT_MULT_F(CLOCK_MULT_F),
    .CLKOUT0_DIVIDE_F(CORE_CLKOUT_DIVIDE_F),
    .CLKOUT1_DIVIDE(PERIPHERAL_CLKOUT_DIVIDE),
    .STARTUP_WAIT("FALSE")
  ) u_mmcm (
    .CLKIN1(clk_input),
    .CLKFBIN(clk_feedback_buffered),
    .RST(reset_i),
    .PWRDWN(1'b0),
    .CLKFBOUT(clk_feedback),
    .CLKFBOUTB(),
    .CLKOUT0(clk_core_unbuffered),
    .CLKOUT0B(),
    .CLKOUT1(clk_peripheral_unbuffered),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .LOCKED(locked_o)
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
