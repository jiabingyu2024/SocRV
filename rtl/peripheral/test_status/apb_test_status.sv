module apb_test_status (
  input logic clk_i,
  input logic rst_ni,
  input logic [31:0] paddr_i,
  input logic psel_i,
  input logic penable_i,
  input logic pwrite_i,
  input logic [31:0] pwdata_i,
  input logic [3:0] pstrb_i,
  output logic [31:0] prdata_o,
  output logic pready_o,
  output logic pslverr_o,
  output logic test_done_o,
  output logic test_pass_o,
  output logic [31:0] test_code_o
);
  localparam logic [31:0] PASS_MAGIC = 32'h5041_5353;
  localparam logic [31:0] FAIL_MAGIC = 32'h4641_494c;
  logic [31:0] status_q;
  logic [31:0] code_q;

  assign pready_o    = 1'b1;
  assign pslverr_o   = 1'b0;
  assign test_done_o = (status_q == PASS_MAGIC) || (status_q == FAIL_MAGIC);
  assign test_pass_o = (status_q == PASS_MAGIC);
  assign test_code_o = code_q;
  assign prdata_o    = (paddr_i[11:0] == 12'h004) ? code_q : status_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      status_q <= '0;
      code_q   <= '0;
    end else if (psel_i && penable_i && pwrite_i) begin
      if (paddr_i[11:0] == 12'h000 && (&pstrb_i)) status_q <= pwdata_i;
      if (paddr_i[11:0] == 12'h004 && (&pstrb_i)) code_q   <= pwdata_i;
    end
  end
endmodule
