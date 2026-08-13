`timescale 1ns/1ps

module pynq_z2_reset_sequencer_tb;
  localparam int unsigned TEST_STABLE_CYCLES = 8;

  logic clk = 1'b0;
  logic mmcm_locked = 1'b0;
  logic soc_rst_n;
  logic clock_stable;

  always #5 clk = ~clk;

  pynq_z2_reset_sequencer #(
    .LOCK_STABLE_CYCLES(TEST_STABLE_CYCLES)
  ) dut (
    .clk_i(clk),
    .mmcm_locked_i(mmcm_locked),
    .soc_rst_no(soc_rst_n),
    .clock_stable_o(clock_stable)
  );

  initial begin
    repeat (2) @(posedge clk);
    if (soc_rst_n !== 1'b0 || clock_stable !== 1'b0)
      $fatal(1, "reset was not asserted initially");

    // A short LOCKED pulse must not release the SoC.
    mmcm_locked = 1'b1;
    repeat (5) @(posedge clk);
    mmcm_locked = 1'b0;
    #1;
    if (soc_rst_n !== 1'b0 || clock_stable !== 1'b0)
      $fatal(1, "short LOCKED pulse released reset");

    // A continuous stable window qualifies the clock, then reset_sync adds
    // its normal synchronous release delay.
    repeat (2) @(posedge clk);
    mmcm_locked = 1'b1;
    wait (clock_stable === 1'b1);
    if (soc_rst_n !== 1'b0)
      $fatal(1, "SoC reset released before the final synchronizer");
    wait (soc_rst_n === 1'b1);

    // Loss of lock must assert reset without waiting for another clock edge.
    #2 mmcm_locked = 1'b0;
    #1;
    if (soc_rst_n !== 1'b0 || clock_stable !== 1'b0)
      $fatal(1, "loss of lock did not assert reset immediately");

    $display("PASS: PYNQ-Z2 reset sequencer");
    $finish;
  end

  initial begin
    #2000;
    $fatal(1, "timeout");
  end
endmodule
