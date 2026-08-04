module uart_fifo #(
  parameter int unsigned WIDTH = 8,
  parameter int unsigned DEPTH = 16
) (
  input logic clk_i,
  input logic rst_ni,
  input logic push_valid_i,
  output logic push_ready_o,
  input logic [WIDTH-1:0] push_data_i,
  output logic pop_valid_o,
  input logic pop_ready_i,
  output logic [WIDTH-1:0] pop_data_o,
  output logic [$clog2(DEPTH+1)-1:0] level_o
);
  localparam int unsigned PTR_WIDTH = $clog2(DEPTH);
  localparam int unsigned COUNT_WIDTH = $clog2(DEPTH + 1);
  logic [WIDTH-1:0] storage [0:DEPTH-1];
  logic [PTR_WIDTH-1:0] write_ptr_q;
  logic [PTR_WIDTH-1:0] read_ptr_q;
  logic [$clog2(DEPTH+1)-1:0] count_q;
  logic do_push;
  logic do_pop;

  assign push_ready_o = (count_q != COUNT_WIDTH'(DEPTH));
  assign pop_valid_o  = (count_q != 0);
  assign pop_data_o   = storage[read_ptr_q];
  assign level_o      = count_q;
  assign do_push      = push_valid_i && push_ready_o;
  assign do_pop       = pop_valid_o && pop_ready_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      write_ptr_q <= '0;
      read_ptr_q  <= '0;
      count_q     <= '0;
    end else begin
      if (do_push) begin
        write_ptr_q <= write_ptr_q + 1'b1;
      end
      if (do_pop) read_ptr_q <= read_ptr_q + 1'b1;
      case ({do_push, do_pop})
        2'b10: count_q <= count_q + 1'b1;
        2'b01: count_q <= count_q - 1'b1;
        default: count_q <= count_q;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (do_push) storage[write_ptr_q] <= push_data_i;
  end
endmodule
