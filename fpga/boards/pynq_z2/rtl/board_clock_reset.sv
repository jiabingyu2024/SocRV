module board_clock_reset #(
  parameter int unsigned LOCK_STABLE_CYCLES = 1_000_000
) (
  input  logic sys_clk_i,
  output logic core_clk_o,
  output logic peripheral_clk_o,
  output logic core_rst_no,
  output logic clock_locked_o
);
  logic mmcm_locked;
  logic clock_stable;

  pynq_z2_clock_wrapper u_clock (
    .clk_125mhz_i(sys_clk_i),
    .reset_i(1'b0),
    .clk_core_o(core_clk_o),
    .clk_peripheral_o(peripheral_clk_o),
    .locked_o(mmcm_locked)
  );

  pynq_z2_reset_sequencer #(
    .LOCK_STABLE_CYCLES(LOCK_STABLE_CYCLES)
  ) u_reset_sequencer (
    .clk_i(core_clk_o),
    .mmcm_locked_i(mmcm_locked),
    .soc_rst_no(core_rst_no),
    .clock_stable_o(clock_stable)
  );

  assign clock_locked_o = clock_stable;
endmodule
