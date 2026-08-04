module board_io_wrapper (
  input logic [15:0] gpio_o_i,
  input logic [15:0] gpio_oe_i,
  input logic test_done_i,
  input logic test_pass_i,
  input logic cpu_fault_i,
  input logic clock_locked_i,
  input logic [31:0] test_code_i,
  input logic [31:0] commit_pc_i,
  output logic [31:0] virtual_led_o,
  output logic [39:0] virtual_seg_o
);
  always_comb begin
    virtual_led_o = '0;
    virtual_led_o[15:0] = gpio_o_i & gpio_oe_i;
    virtual_led_o[28] = clock_locked_i;
    virtual_led_o[29] = cpu_fault_i;
    virtual_led_o[30] = test_done_i && !test_pass_i;
    virtual_led_o[31] = test_done_i && test_pass_i;
    virtual_seg_o = {test_code_i[7:0], commit_pc_i};
  end
endmodule
