package soc_config_pkg;
  parameter int unsigned SOC_ADDR_WIDTH = 32;
  parameter int unsigned SOC_DATA_WIDTH = 32;
  parameter int unsigned SOC_STRB_WIDTH = SOC_DATA_WIDTH / 8;
  parameter int unsigned SOC_CLOCK_HZ   = 120_000_000;
  parameter int unsigned UART_BAUD      = 115_200;
  parameter int unsigned CODE_MEM_RESPONSE_LATENCY = 1;
  parameter int unsigned DATA_MEM_RESPONSE_LATENCY = 1;
  parameter logic [31:0] RESET_VECTOR   = 32'h0000_0000;
  parameter int unsigned EXT_IRQ_COUNT  = 8;
endpackage
