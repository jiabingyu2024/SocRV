module reset_sync (
   input  logic clk_i,
   input  logic arst_ni,
   output logic rst_ni
);
   // Keep only the metastability-catching stages in one ASYNC_REG chain.
   // The former three-bit ASYNC_REG vector also made its final bit the sole
   // high-fanout reset source, which prevented Vivado from replicating that
   // distributor close to the core registers.  A separate, ordinary final
   // stage preserves the three-cycle synchronous release while allowing
   // physical replication of the reset tree on FPGA.
   (* ASYNC_REG = "TRUE" *) logic [1:0] release_meta_q;
   (* max_fanout = 64 *) logic release_q;

   always_ff @(posedge clk_i or negedge arst_ni) begin
      if (!arst_ni) begin
         release_meta_q <= 2'b00;
         release_q      <= 1'b0;
      end else begin
         release_meta_q <= {release_meta_q[0], 1'b1};
         release_q      <= release_meta_q[1];
      end
   end

   assign rst_ni = release_q;
endmodule
