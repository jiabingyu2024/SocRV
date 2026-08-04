package common_types_pkg;
  typedef enum logic [1:0] {
    TEST_RUNNING = 2'b00,
    TEST_PASS    = 2'b01,
    TEST_FAIL    = 2'b10
  } test_state_t;

  function automatic logic [31:0] apply_wstrb(
      input logic [31:0] old_value,
      input logic [31:0] new_value,
      input logic [3:0]  wstrb);
    logic [31:0] result;
    result = old_value;
    for (int i = 0; i < 4; i++) begin
      if (wstrb[i]) result[i*8 +: 8] = new_value[i*8 +: 8];
    end
    return result;
  endfunction
endpackage
