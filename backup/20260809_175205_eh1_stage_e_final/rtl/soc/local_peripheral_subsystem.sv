module local_peripheral_subsystem #(
   parameter int unsigned CLOCK_HZ   = 250_000_000,
   parameter int unsigned UART_BAUD  = 115_200,
   parameter int unsigned GPIO_WIDTH = 16
) (
   input  logic                  clk,
   input  logic                  rst_l,
   input  logic                  req_valid,
   input  logic                  req_write,
   input  logic [31:0]           req_addr,
   input  logic [31:0]           req_wdata,
   input  logic [3:0]            req_wstrb,
   output logic                  req_ready,
   output logic [31:0]           req_rdata,
   output logic                  req_error,
   input  logic                  uart_rx,
   output logic                  uart_tx,
   input  logic [GPIO_WIDTH-1:0] gpio_in,
   output logic [GPIO_WIDTH-1:0] gpio_out,
   output logic [GPIO_WIDTH-1:0] gpio_oe,
   output logic                  timer_irq,
   output logic                  software_irq,
   output logic                  uart_irq,
   output logic [31:0]           test_status,
   output logic [31:0]           test_code
);
   import soc_memory_map_pkg::*;

   logic timer_sel, uart_sel, gpio_sel, sysctrl_sel;
   logic timer_ready, uart_ready, gpio_ready, sysctrl_ready;
   logic [31:0] timer_rdata, uart_rdata, gpio_rdata, sysctrl_rdata;

   assign timer_sel = req_valid && (req_addr >= TIMER_BASE) &&
                      (req_addr < TIMER_BASE + TIMER_SIZE);
   assign uart_sel = req_valid && (req_addr >= UART_BASE) &&
                     (req_addr < UART_BASE + UART_SIZE);
   assign gpio_sel = req_valid && (req_addr >= GPIO_BASE) &&
                     (req_addr < GPIO_BASE + GPIO_SIZE);
   assign sysctrl_sel = req_valid && (req_addr >= SYSCTRL_BASE) &&
                        (req_addr < SYSCTRL_BASE + SYSCTRL_SIZE);

   always_comb begin
      req_ready = 1'b1;
      req_rdata = 32'b0;
      req_error = req_valid && !(timer_sel || uart_sel || gpio_sel || sysctrl_sel);
      unique case (1'b1)
         timer_sel: begin req_ready = timer_ready; req_rdata = timer_rdata; end
         uart_sel: begin req_ready = uart_ready; req_rdata = uart_rdata; end
         gpio_sel: begin req_ready = gpio_ready; req_rdata = gpio_rdata; end
         sysctrl_sel: begin req_ready = sysctrl_ready; req_rdata = sysctrl_rdata; end
         default: ;
      endcase
   end

   machine_timer timer (
      .clk, .rst_l,
      .req_valid(timer_sel), .req_write, .req_addr(req_addr[11:0]),
      .req_wdata, .req_wstrb, .req_ready(timer_ready),
      .req_rdata(timer_rdata), .timer_irq
   );

   uart #(.CLOCK_HZ(CLOCK_HZ), .BAUD(UART_BAUD)) uart0 (
      .clk, .rst_l, .uart_rx, .uart_tx,
      .req_valid(uart_sel), .req_write, .req_addr(req_addr[11:0]),
      .req_wdata, .req_wstrb, .req_ready(uart_ready),
      .req_rdata(uart_rdata), .uart_irq
   );

   gpio #(.WIDTH(GPIO_WIDTH)) gpio0 (
      .clk, .rst_l, .gpio_in, .gpio_out, .gpio_oe,
      .req_valid(gpio_sel), .req_write, .req_addr(req_addr[11:0]),
      .req_wdata, .req_wstrb, .req_ready(gpio_ready), .req_rdata(gpio_rdata)
   );

   sysctrl #(.CLOCK_HZ(CLOCK_HZ)) sysctrl0 (
      .clk, .rst_l,
      .req_valid(sysctrl_sel), .req_write, .req_addr(req_addr[11:0]),
      .req_wdata, .req_wstrb, .req_ready(sysctrl_ready),
      .req_rdata(sysctrl_rdata), .software_irq, .test_status, .test_code
   );
endmodule
