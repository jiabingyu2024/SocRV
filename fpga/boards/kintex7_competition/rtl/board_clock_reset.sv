module board_clock_reset #(
  parameter real CORE_CLKOUT_DIVIDE_F = 10.0
) (
  input logic sys_clk_p_i,
  input logic sys_clk_n_i,
  output logic core_clk_o,
  output logic peripheral_clk_o,
  output logic core_rst_no,
  output logic clock_locked_o
);
  logic mmcm_locked;

  xilinx_clock_wrapper #(
    .CORE_CLKOUT_DIVIDE_F(CORE_CLKOUT_DIVIDE_F)
  ) u_clock (
    .clk_200mhz_p_i(sys_clk_p_i),
    .clk_200mhz_n_i(sys_clk_n_i),
    .reset_i(1'b0),
    .clk_core_o(core_clk_o),
    .clk_peripheral_o(peripheral_clk_o),
    .locked_o(mmcm_locked)
  );

  reset_sync u_core_reset_sync (
    .clk_i(core_clk_o),
    .arst_ni(mmcm_locked),
    .rst_ni(core_rst_no)
  );
  assign clock_locked_o = mmcm_locked;
endmodule
