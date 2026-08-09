package soc_memory_map_pkg;
   localparam logic [31:0] CODE_BASE    = 32'h0000_0000;
   localparam logic [31:0] CODE_SIZE    = 32'h0002_0000;
   localparam logic [31:0] DATA_BASE    = 32'h0002_0000;
   localparam logic [31:0] DATA_SIZE    = 32'h0001_0000;
   localparam logic [31:0] TIMER_BASE   = 32'h1000_0000;
   localparam logic [31:0] TIMER_SIZE   = 32'h0000_1000;
   localparam logic [31:0] UART_BASE    = 32'h1000_1000;
   localparam logic [31:0] UART_SIZE    = 32'h0000_1000;
   localparam logic [31:0] GPIO_BASE    = 32'h1000_2000;
   localparam logic [31:0] GPIO_SIZE    = 32'h0000_1000;
   localparam logic [31:0] SYSCTRL_BASE = 32'h1000_3000;
   localparam logic [31:0] SYSCTRL_SIZE = 32'h0000_1000;
endpackage
