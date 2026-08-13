module pynq_z2_reset_sequencer #(
  // At 50 MHz the default requires MMCM LOCKED to remain asserted for 20 ms.
  parameter int unsigned LOCK_STABLE_CYCLES = 1_000_000
) (
  input  logic clk_i,
  input  logic mmcm_locked_i,
  output logic soc_rst_no,
  output logic clock_stable_o
);
  localparam int unsigned STABLE_COUNT_WIDTH =
      (LOCK_STABLE_CYCLES <= 1) ? 1 : $clog2(LOCK_STABLE_CYCLES);

  logic lock_synchronized;
  logic [STABLE_COUNT_WIDTH-1:0] stable_count_q;

  // LOCKED is not assumed synchronous to clk_i. Assertion of a reset caused
  // by loss of lock remains asynchronous, while both release paths are
  // synchronized to the generated SoC clock.
  reset_sync u_lock_synchronizer (
    .clk_i(clk_i),
    .arst_ni(mmcm_locked_i),
    .rst_ni(lock_synchronized)
  );

  // Reject a LOCKED pulse or startup chatter. Any loss of lock clears the
  // qualification immediately; only one continuous stable window releases
  // the SoC.
  always_ff @(posedge clk_i or negedge lock_synchronized) begin
    if (!lock_synchronized) begin
      stable_count_q <= '0;
      clock_stable_o <= 1'b0;
    end else if (!clock_stable_o) begin
      if ((LOCK_STABLE_CYCLES <= 1) ||
          (stable_count_q == LOCK_STABLE_CYCLES - 1)) begin
        clock_stable_o <= 1'b1;
      end else begin
        stable_count_q <= stable_count_q + 1'b1;
      end
    end
  end

  reset_sync u_soc_reset_release (
    .clk_i(clk_i),
    .arst_ni(clock_stable_o),
    .rst_ni(soc_rst_no)
  );
endmodule
