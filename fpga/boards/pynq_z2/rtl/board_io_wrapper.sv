module board_io_wrapper (
  input  logic [15:0] gpio_o_i,
  input  logic [15:0] gpio_oe_i,
  input  logic        test_done_i,
  input  logic        test_pass_i,
  input  logic        cpu_fault_i,
  input  logic        clock_locked_i,
  output logic [3:0]  led_o
);
  always_comb begin
    led_o = '0;
    led_o[0] = gpio_o_i[0] & gpio_oe_i[0];
    led_o[1] = clock_locked_i;
    led_o[2] = cpu_fault_i || (test_done_i && !test_pass_i);
    led_o[3] = test_done_i && test_pass_i;
  end
endmodule
