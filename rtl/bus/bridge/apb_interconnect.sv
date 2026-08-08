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

  output logic        timer_psel_o,
  input  logic [31:0] timer_prdata_i,
  input  logic        timer_pready_i,
  input  logic        timer_pslverr_i,
  output logic        irq_psel_o,
  input  logic [31:0] irq_prdata_i,
  input  logic        irq_pready_i,
  input  logic        irq_pslverr_i,
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

  assign timer_psel_o = psel_i && in_region(paddr_i, TIMER_BASE, TIMER_SIZE);
  assign irq_psel_o = psel_i && in_region(paddr_i, IRQ_CTRL_BASE, IRQ_CTRL_SIZE);
  assign uart_psel_o = psel_i && in_region(paddr_i, UART_BASE, APB_SLOT_SIZE);
  assign gpio_psel_o = psel_i && in_region(paddr_i, GPIO_BASE, APB_SLOT_SIZE);
  assign test_psel_o = psel_i &&
                       in_region(paddr_i, TEST_STATUS_BASE, APB_SLOT_SIZE);

  always_comb begin
    prdata_o    = 32'h0000_0000;
    pready_o    = 1'b1;
    pslverr_o   = psel_i;

    if (timer_psel_o) begin
      prdata_o  = timer_prdata_i;
      pready_o  = timer_pready_i;
      pslverr_o = timer_pslverr_i;
    end else if (irq_psel_o) begin
      prdata_o  = irq_prdata_i;
      pready_o  = irq_pready_i;
      pslverr_o = irq_pslverr_i;
    end else if (uart_psel_o) begin
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
