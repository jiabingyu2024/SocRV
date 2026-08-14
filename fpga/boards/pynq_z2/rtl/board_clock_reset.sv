module board_clock_reset (
  input  logic sys_clk_i,
  output logic core_clk_o,
  output logic peripheral_clk_o,
  output logic core_rst_no,
  output logic clock_locked_o
);
  logic mmcm_locked;
  // The PYNQ-Z2 PL clock comes from the Ethernet PHY.  Reasserting reset on
  // every transient loss of MMCM lock restarts RT-Thread.  FPGA configuration
  // initializes these flops to zero; after the first stable clock arrives the
  // reset releases once and is deliberately not reasserted.  The clock wrapper
  // gates both SoC clocks while the MMCM is unlocked, preserving SoC state.
  (* SHREG_EXTRACT = "NO" *) logic [2:0] startup_release_q = 3'b000;

  pynq_z2_clock_wrapper u_clock (
    .clk_125mhz_i(sys_clk_i),
    .reset_i(1'b0),
    .clk_core_o(core_clk_o),
    .clk_peripheral_o(peripheral_clk_o),
    .locked_o(mmcm_locked)
  );

  always_ff @(posedge core_clk_o) begin
    startup_release_q <= {startup_release_q[1:0], 1'b1};
  end

  assign core_rst_no = startup_release_q[2];
  assign clock_locked_o = mmcm_locked;
endmodule
