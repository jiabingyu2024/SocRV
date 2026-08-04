module uart_tx (
  input logic clk_i,
  input logic rst_ni,
  input logic [15:0] divisor_i,
  input logic data_valid_i,
  output logic data_ready_o,
  input logic [7:0] data_i,
  output logic tx_o
);
  logic busy_q;
  logic [9:0] shift_q;
  logic [3:0] bits_left_q;
  logic [15:0] counter_q;
  logic [15:0] divisor_safe;

  assign divisor_safe = (divisor_i < 16'd2) ? 16'd2 : divisor_i;
  assign data_ready_o = !busy_q;
  assign tx_o = busy_q ? shift_q[0] : 1'b1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q      <= 1'b0;
      shift_q     <= '1;
      bits_left_q <= '0;
      counter_q   <= '0;
    end else if (!busy_q) begin
      if (data_valid_i) begin
        busy_q      <= 1'b1;
        shift_q     <= {1'b1, data_i, 1'b0};
        bits_left_q <= 4'd10;
        counter_q   <= divisor_safe - 1'b1;
      end
    end else if (counter_q == 0) begin
      shift_q   <= {1'b1, shift_q[9:1]};
      counter_q <= divisor_safe - 1'b1;
      if (bits_left_q == 1) begin
        bits_left_q <= '0;
        busy_q      <= 1'b0;
      end else begin
        bits_left_q <= bits_left_q - 1'b1;
      end
    end else begin
      counter_q <= counter_q - 1'b1;
    end
  end
endmodule
