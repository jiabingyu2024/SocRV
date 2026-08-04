package memory_map_pkg;
  localparam logic [31:0] CODE_BASE        = 32'h0000_0000;
  localparam logic [31:0] CODE_SIZE        = 32'h0001_0000;
  localparam logic [31:0] DATA_BASE        = 32'h1000_0000;
  localparam logic [31:0] DATA_SIZE        = 32'h0001_0000;
  localparam logic [31:0] TIMER_BASE       = 32'h2000_0000;
  localparam logic [31:0] TIMER_SIZE       = 32'h0000_1000;
  localparam logic [31:0] IRQ_CTRL_BASE    = 32'h2000_1000;
  localparam logic [31:0] IRQ_CTRL_SIZE    = 32'h0000_1000;
  localparam logic [31:0] APB_BASE         = 32'h3000_0000;
  localparam logic [31:0] APB_SIZE         = 32'h0001_0000;
  localparam logic [31:0] UART_BASE        = 32'h3000_0000;
  localparam logic [31:0] UART_SIZE        = 32'h0000_1000;
  localparam logic [31:0] GPIO_BASE        = 32'h3000_1000;
  localparam logic [31:0] GPIO_SIZE        = 32'h0000_1000;
  localparam logic [31:0] TEST_STATUS_BASE = 32'h3000_2000;
  localparam logic [31:0] TEST_STATUS_SIZE = 32'h0000_1000;
  localparam logic [31:0] APB_SLOT_SIZE    = UART_SIZE;

  function automatic logic in_region(
      input logic [31:0] address,
      input logic [31:0] base,
      input logic [31:0] size);
    in_region = (address >= base) && (address < (base + size));
  endfunction
endpackage
