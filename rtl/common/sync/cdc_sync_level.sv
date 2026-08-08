module cdc_sync_level #(
  parameter int unsigned WIDTH = 1,
  parameter logic [WIDTH-1:0] RESET_VALUE = '0
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic [WIDTH-1:0]     async_i,
  output logic [WIDTH-1:0]     sync_o
);
  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] meta_q;
  (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      meta_q <= RESET_VALUE;
      sync_q <= RESET_VALUE;
    end else begin
      meta_q <= async_i;
      sync_q <= meta_q;
    end
  end

  assign sync_o = sync_q;
endmodule
