module uart_rx (
  input logic clk_i,
  input logic rst_ni,
  input logic [15:0] divisor_i,
  input logic rx_i,
  output logic data_valid_o,
  output logic [7:0] data_o,
  output logic framing_error_o
);
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} state_t;
  state_t state_q;
  logic rx_meta_q;
  logic rx_sync_q;
  logic [15:0] counter_q;
  logic [2:0] bit_q;
  logic [7:0] data_q;
  logic [15:0] divisor_safe;

  assign divisor_safe = (divisor_i < 16'd2) ? 16'd2 : divisor_i;
  assign data_o = data_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_meta_q <= 1'b1;
      rx_sync_q <= 1'b1;
    end else begin
      rx_meta_q <= rx_i;
      rx_sync_q <= rx_meta_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q         <= RX_IDLE;
      counter_q       <= '0;
      bit_q           <= '0;
      data_q          <= '0;
      data_valid_o    <= 1'b0;
      framing_error_o <= 1'b0;
    end else begin
      data_valid_o <= 1'b0;
      case (state_q)
        RX_IDLE: if (!rx_sync_q) begin
          counter_q <= divisor_safe >> 1;
          state_q   <= RX_START;
        end
        RX_START: if (counter_q == 0) begin
          if (!rx_sync_q) begin
            counter_q <= divisor_safe - 1'b1;
            bit_q     <= '0;
            state_q   <= RX_DATA;
          end else state_q <= RX_IDLE;
        end else counter_q <= counter_q - 1'b1;
        RX_DATA: if (counter_q == 0) begin
          data_q[bit_q] <= rx_sync_q;
          counter_q <= divisor_safe - 1'b1;
          if (bit_q == 3'd7) state_q <= RX_STOP;
          else bit_q <= bit_q + 1'b1;
        end else counter_q <= counter_q - 1'b1;
        RX_STOP: if (counter_q == 0) begin
          data_valid_o    <= 1'b1;
          framing_error_o <= !rx_sync_q;
          state_q         <= RX_IDLE;
        end else counter_q <= counter_q - 1'b1;
        default: state_q <= RX_IDLE;
      endcase
    end
  end
endmodule
