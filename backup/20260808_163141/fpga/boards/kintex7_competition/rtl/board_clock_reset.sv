module board_clock_reset (
  input logic sys_clk_p_i,
  input logic sys_clk_n_i,
  output logic soc_clk_o,
  output logic soc_rst_no,
  output logic clock_locked_o
);
  logic mmcm_locked;

  xilinx_clock_wrapper u_clock (
    .clk_200mhz_p_i(sys_clk_p_i),
    .clk_200mhz_n_i(sys_clk_n_i),
    .reset_i(1'b0),
    .clk_50mhz_o(soc_clk_o),
    .locked_o(mmcm_locked)
  );

  reset_sync u_reset_sync (
    .clk_i(soc_clk_o),
    .arst_ni(mmcm_locked),
    .rst_ni(soc_rst_no)
  );

  assign clock_locked_o = mmcm_locked;
endmodule
