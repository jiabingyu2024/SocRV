module apb_interconnect (
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] pwdata_i,
  input  logic [3:0]  pstrb_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,

  output logic        uart_psel_o,
  input  logic [31:0] uart_prdata_i,
  input  logic        uart_pready_i,
  input  logic        uart_pslverr_i,
  output logic        gpio_psel_o,
  input  logic [31:0] gpio_prdata_i,
  input  logic        gpio_pready_i,
  input  logic        gpio_pslverr_i,
  output logic        test_psel_o,
  input  logic [31:0] test_prdata_i,
  input  logic        test_pready_i,
  input  logic        test_pslverr_i
);
  import memory_map_pkg::*;

  assign uart_psel_o = psel_i && in_region(paddr_i, UART_BASE, APB_SLOT_SIZE);
  assign gpio_psel_o = psel_i && in_region(paddr_i, GPIO_BASE, APB_SLOT_SIZE);
  assign test_psel_o = psel_i &&
                       in_region(paddr_i, TEST_STATUS_BASE, APB_SLOT_SIZE);

  always_comb begin
    prdata_o    = 32'h0000_0000;
    pready_o    = 1'b1;
    pslverr_o   = psel_i;

    if (uart_psel_o) begin
      prdata_o  = uart_prdata_i;
      pready_o  = uart_pready_i;
      pslverr_o = uart_pslverr_i;
    end else if (gpio_psel_o) begin
      prdata_o  = gpio_prdata_i;
      pready_o  = gpio_pready_i;
      pslverr_o = gpio_pslverr_i;
    end else if (test_psel_o) begin
      prdata_o  = test_prdata_i;
      pready_o  = test_pready_i;
      pslverr_o = test_pslverr_i;
    end
  end

  logic unused;
  assign unused = penable_i ^ pwrite_i ^ ^pwdata_i ^ ^pstrb_i;
endmodule
