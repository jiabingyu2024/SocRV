module reset_sync (
   input  logic clk_i,
   input  logic arst_ni,
   output logic rst_ni
);
   (* ASYNC_REG = "TRUE" *) logic [2:0] release_q;

   always_ff @(posedge clk_i or negedge arst_ni) begin
      if (!arst_ni)
         release_q <= 3'b000;
      else
         release_q <= {release_q[1:0], 1'b1};
   end

   assign rst_ni = release_q[2];
endmodule
