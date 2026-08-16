module uart #(
   parameter int unsigned CLOCK_HZ = 250_000_000,
   parameter int unsigned BAUD     = 115_200
) (
   input  logic        clk,
   input  logic        rst_l,
   input  logic        uart_rx,
   output logic        uart_tx,
   input  logic        req_valid,
   input  logic        req_write,
   input  logic [11:0] req_addr,
   input  logic [31:0] req_wdata,
   input  logic [3:0]  req_wstrb,
   output logic        req_ready,
   output logic [31:0] req_rdata,
   output logic        uart_irq
);
   localparam int unsigned RESET_DIV = (CLOCK_HZ / BAUD) > 1 ? CLOCK_HZ / BAUD : 2;

   logic [7:0] tx_fifo [0:3];
   logic [7:0] rx_fifo [0:3];
   logic [1:0] tx_wr_ptr, tx_rd_ptr, rx_wr_ptr, rx_rd_ptr;
   logic [2:0] tx_count, rx_count;
   logic [31:0] baud_div;
   logic [1:0] uart_ctrl;
   logic irq_pending;

   logic [9:0] tx_shift;
   logic [3:0] tx_bits_left;
   logic [31:0] tx_baud_count;
   logic tx_pop, tx_push;

   logic rx_meta, rx_sync, rx_sync_q;
   logic rx_busy;
   logic [3:0] rx_bit_index;
   logic [31:0] rx_baud_count;
   logic [7:0] rx_shift;
   logic rx_push, rx_pop;

   wire tx_full  = (tx_count == 3'd4);
   wire tx_empty = (tx_count == 3'd0);
   wire tx_idle  = tx_empty && (tx_bits_left == 0);
   wire rx_full  = (rx_count == 3'd4);
   wire rx_empty = (rx_count == 3'd0);
   wire txdata_access = (req_addr[7:2] == 6'h00);
   wire rxdata_access = (req_addr[7:2] == 6'h01);

   assign req_ready = !(req_valid && req_write && txdata_access && tx_full);
   assign tx_push = req_valid && req_ready && req_write && txdata_access &&
                    req_wstrb[0] && uart_ctrl[0];
   assign rx_pop = req_valid && req_ready && !req_write && rxdata_access && !rx_empty;
   assign tx_pop = uart_ctrl[0] && (tx_bits_left == 0) && !tx_empty;
   assign uart_tx = (tx_bits_left == 0) ? 1'b1 : tx_shift[0];
   assign uart_irq = irq_pending;

   always_comb begin
      unique case (req_addr[7:2])
         6'h01: req_rdata = rx_empty ? 32'b0 : {24'b0, rx_fifo[rx_rd_ptr]};
         6'h02: req_rdata = {28'b0, rx_full, tx_idle, !tx_full, !rx_empty};
         6'h03: req_rdata = baud_div;
         6'h04: req_rdata = {30'b0, uart_ctrl};
         6'h05: req_rdata = {31'b0, irq_pending};
         default: req_rdata = 32'b0;
      endcase
   end


   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         tx_wr_ptr     <= 2'b0;
         tx_rd_ptr     <= 2'b0;
         tx_count      <= 3'b0;
         tx_shift      <= 10'h3ff;
         tx_bits_left  <= 4'b0;
         tx_baud_count <= 32'b0;
      end else begin
         if (tx_push) begin
            tx_fifo[tx_wr_ptr] <= req_wdata[7:0];
            tx_wr_ptr <= tx_wr_ptr + 2'd1;
         end
         if (tx_pop) begin
            tx_shift <= {1'b1, tx_fifo[tx_rd_ptr], 1'b0};
            tx_bits_left <= 4'd10;
            tx_baud_count <= baud_div - 32'd1;
            tx_rd_ptr <= tx_rd_ptr + 2'd1;
         end else if (tx_bits_left != 0) begin
            if (tx_baud_count == 0) begin
               tx_shift <= {1'b1, tx_shift[9:1]};
               tx_bits_left <= tx_bits_left - 4'd1;
               tx_baud_count <= baud_div - 32'd1;
            end else begin
               tx_baud_count <= tx_baud_count - 32'd1;
            end
         end
         unique case ({tx_push, tx_pop})
            2'b10: tx_count <= tx_count + 3'd1;
            2'b01: tx_count <= tx_count - 3'd1;
            default: ;
         endcase
      end
   end


   assign rx_push = rx_busy && (rx_bit_index == 4'd9) && (rx_baud_count == 0) &&
                    rx_sync && !rx_full;
   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         rx_meta       <= 1'b1;
         rx_sync       <= 1'b1;
         rx_sync_q     <= 1'b1;
         rx_busy       <= 1'b0;
         rx_bit_index  <= 4'b0;
         rx_baud_count <= 32'b0;
         rx_shift      <= 8'b0;
         rx_wr_ptr     <= 2'b0;
         rx_rd_ptr     <= 2'b0;
         rx_count      <= 3'b0;
      end else begin
         rx_meta   <= uart_rx;
         rx_sync   <= rx_meta;
         rx_sync_q <= rx_sync;

         if (!rx_busy && uart_ctrl[1] && rx_sync_q && !rx_sync) begin
            rx_busy <= 1'b1;
            rx_bit_index <= 4'd0;
            rx_baud_count <= (baud_div >> 1);
         end else if (rx_busy) begin
            if (rx_baud_count != 0) begin
               rx_baud_count <= rx_baud_count - 32'd1;
            end else if (rx_bit_index == 4'd0) begin
               if (!rx_sync) begin
                  rx_bit_index <= 4'd1;
                  rx_baud_count <= baud_div - 32'd1;
               end else begin
                  rx_busy <= 1'b0;
               end
            end else if (rx_bit_index <= 4'd8) begin
               rx_shift[rx_bit_index-1] <= rx_sync;
               rx_bit_index <= rx_bit_index + 4'd1;
               rx_baud_count <= baud_div - 32'd1;
            end else begin
               rx_busy <= 1'b0;
               if (rx_sync && !rx_full) begin
                  rx_fifo[rx_wr_ptr] <= rx_shift;
                  rx_wr_ptr <= rx_wr_ptr + 2'd1;
               end
            end
         end

         if (rx_pop) rx_rd_ptr <= rx_rd_ptr + 2'd1;
         unique case ({rx_push, rx_pop})
            2'b10: rx_count <= rx_count + 3'd1;
            2'b01: rx_count <= rx_count - 3'd1;
            default: ;
         endcase
      end
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         baud_div   <= RESET_DIV;
         uart_ctrl  <= 2'b11;
         irq_pending <= 1'b0;
      end else begin
         if (rx_push) irq_pending <= 1'b1;
         if (req_valid && req_ready && req_write) begin
            unique case (req_addr[7:2])
               6'h03: if (&req_wstrb && (req_wdata >= 32'd2)) baud_div <= req_wdata;
               6'h04: if (req_wstrb[0]) uart_ctrl <= req_wdata[1:0];
               6'h05: if (req_wstrb[0] && req_wdata[0]) irq_pending <= 1'b0;
               default: ;
            endcase
         end
      end
   end
endmodule
