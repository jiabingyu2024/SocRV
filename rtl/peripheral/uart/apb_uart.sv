module apb_uart #(
  parameter int unsigned CLOCK_HZ = soc_config_pkg::SOC_CLOCK_HZ,
  parameter int unsigned BAUD = soc_config_pkg::UART_BAUD
) (
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
  input logic uart_rx_i,
  output logic uart_tx_o,
  output logic irq_o
);
  localparam int unsigned DEFAULT_DIVISOR = CLOCK_HZ / BAUD;
  logic [15:0] divisor_q;
  logic [31:0] control_q;
  logic tx_push;
  logic tx_push_ready;
  logic [7:0] tx_pop_data;
  logic tx_pop_valid;
  logic tx_pop_ready;
  logic [4:0] tx_level;
  logic rx_byte_valid;
  logic [7:0] rx_byte;
  logic rx_framing_error;
  logic rx_push_ready;
  logic rx_pop_valid;
  logic rx_pop;
  logic [7:0] rx_pop_data;
  logic [4:0] rx_level;

  assign tx_push = psel_i && penable_i && pwrite_i &&
                   (paddr_i[11:0] == 12'h000) && pstrb_i[0];
  assign rx_pop  = psel_i && penable_i && !pwrite_i &&
                   (paddr_i[11:0] == 12'h004);
  assign pready_o  = ((paddr_i[11:0] == 12'h000) && pwrite_i) ? tx_push_ready : 1'b1;
  assign pslverr_o = 1'b0;
  assign irq_o     = control_q[0] && rx_pop_valid;

  always_comb begin
    case (paddr_i[11:0])
      12'h004: prdata_o = {24'b0, rx_pop_data};
      12'h008: prdata_o = {14'b0, rx_framing_error, rx_pop_valid, 6'b0,
                           ((tx_level == 0) && tx_pop_ready), tx_push_ready, 8'b0};
      12'h00c: prdata_o = {16'b0, divisor_q};
      12'h010: prdata_o = control_q;
      default: prdata_o = '0;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      divisor_q <= DEFAULT_DIVISOR[15:0];
      control_q <= '0;
    end else if (psel_i && penable_i && pwrite_i) begin
      if (paddr_i[11:0] == 12'h00c && pstrb_i[0]) divisor_q[7:0] <= pwdata_i[7:0];
      if (paddr_i[11:0] == 12'h00c && pstrb_i[1]) divisor_q[15:8] <= pwdata_i[15:8];
      if (paddr_i[11:0] == 12'h010) begin
        for (int i = 0; i < 4; i++) if (pstrb_i[i]) control_q[i*8 +: 8] <= pwdata_i[i*8 +: 8];
      end
    end
  end

  uart_fifo u_tx_fifo (
    .clk_i,
    .rst_ni,
    .push_valid_i(tx_push),
    .push_ready_o(tx_push_ready),
    .push_data_i(pwdata_i[7:0]),
    .pop_valid_o(tx_pop_valid),
    .pop_ready_i(tx_pop_ready),
    .pop_data_o(tx_pop_data),
    .level_o(tx_level)
  );

  uart_tx u_tx (
    .clk_i,
    .rst_ni,
    .divisor_i(divisor_q),
    .data_valid_i(tx_pop_valid),
    .data_ready_o(tx_pop_ready),
    .data_i(tx_pop_data),
    .tx_o(uart_tx_o)
  );

  uart_rx u_rx (
    .clk_i,
    .rst_ni,
    .divisor_i(divisor_q),
    .rx_i(uart_rx_i),
    .data_valid_o(rx_byte_valid),
    .data_o(rx_byte),
    .framing_error_o(rx_framing_error)
  );

  uart_fifo u_rx_fifo (
    .clk_i,
    .rst_ni,
    .push_valid_i(rx_byte_valid),
    .push_ready_o(rx_push_ready),
    .push_data_i(rx_byte),
    .pop_valid_o(rx_pop_valid),
    .pop_ready_i(rx_pop),
    .pop_data_o(rx_pop_data),
    .level_o(rx_level)
  );

  logic unused;
  assign unused = ^rx_level ^ rx_push_ready;
endmodule
