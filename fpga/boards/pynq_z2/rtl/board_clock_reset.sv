module board_clock_reset (
  input  logic sys_clk_i,
  output logic core_clk_o,
  output logic peripheral_clk_o,
  output logic core_rst_no,
  output logic clock_locked_o
);
  logic mmcm_locked;

  pynq_z2_clock_wrapper u_clock (
    .clk_125mhz_i(sys_clk_i),
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
