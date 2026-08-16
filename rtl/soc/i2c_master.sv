module i2c_master #(
   parameter int unsigned RESET_CLOCK_DIV = 249,
   parameter int unsigned RESET_TIMEOUT   = 500_000
) (
   input  logic        clk,
   input  logic        rst_l,
   input  logic        req_valid,
   input  logic        req_write,
   input  logic [11:0] req_addr,
   input  logic [31:0] req_wdata,
   input  logic [3:0]  req_wstrb,
   output logic        req_ready,
   output logic [31:0] req_rdata,
   input  logic        scl_i,
   input  logic        sda_i,
   output logic        scl_drive_low,
   output logic        sda_drive_low
);
   localparam logic [11:0] CONTROL_OFFSET   = 12'h000;
   localparam logic [11:0] STATUS_OFFSET    = 12'h004;
   localparam logic [11:0] CLOCK_DIV_OFFSET = 12'h008;
   localparam logic [11:0] TXDATA_OFFSET    = 12'h00c;
   localparam logic [11:0] RXDATA_OFFSET    = 12'h010;
   localparam logic [11:0] COMMAND_OFFSET   = 12'h014;
   localparam logic [11:0] TIMEOUT_OFFSET   = 12'h018;

   typedef enum logic [4:0] {
      ST_IDLE,
      ST_START_RELEASE,
      ST_START_SDA_LOW,
      ST_START_SCL_LOW,
      ST_STOP_SDA_LOW,
      ST_STOP_SCL_HIGH,
      ST_STOP_RELEASE,
      ST_WRITE_BIT_LOW,
      ST_WRITE_BIT_HIGH,
      ST_WRITE_ACK_LOW,
      ST_WRITE_ACK_HIGH,
      ST_WRITE_ACK_FINISH,
      ST_READ_BIT_LOW,
      ST_READ_BIT_HIGH,
      ST_READ_ACK_LOW,
      ST_READ_ACK_HIGH,
      ST_READ_ACK_FINISH,
      ST_RECOVER_LOW,
      ST_RECOVER_HIGH
   } state_t;

   state_t state_q;
   logic controller_enable_q;
   logic busy_q;
   logic done_q;
   logic addr_nack_q;
   logic data_nack_q;
   logic timeout_error_q;
   logic arbitration_lost_q;
   logic bus_stuck_q;
   logic bus_active_q;
   logic rx_valid_q;
   logic command_address_q;
   logic read_nack_q;
   logic [2:0] bit_index_q;
   logic [3:0] recovery_count_q;
   logic [7:0] tx_data_q;
   logic [7:0] tx_shift_q;
   logic [7:0] rx_data_q;
   logic [7:0] rx_shift_q;
   logic [31:0] clock_div_q;
   logic [31:0] timeout_q;
   logic [31:0] phase_count_q;
   logic [31:0] command_timer_q;
   logic [31:0] status_value;

   function automatic logic [31:0] apply_wstrb(
      input logic [31:0] old_value,
      input logic [31:0] new_value,
      input logic [3:0]  write_strobe
   );
      logic [31:0] result;
      begin
         result = old_value;
         for (int byte_index = 0; byte_index < 4; byte_index++) begin
            if (write_strobe[byte_index])
               result[byte_index*8 +: 8] = new_value[byte_index*8 +: 8];
         end
         return result;
      end
   endfunction

   assign req_ready = 1'b1;

   always_comb begin
      status_value = 32'b0;
      status_value[0]  = busy_q;
      status_value[1]  = done_q;
      status_value[2]  = addr_nack_q;
      status_value[3]  = data_nack_q;
      status_value[4]  = timeout_error_q;
      status_value[5]  = arbitration_lost_q;
      status_value[6]  = bus_stuck_q;
      status_value[7]  = scl_i;
      status_value[8]  = sda_i;
      status_value[9]  = bus_active_q;
      status_value[10] = !busy_q && !bus_active_q && scl_i && sda_i;
      status_value[11] = rx_valid_q;

      unique case (req_addr)
         CONTROL_OFFSET:   req_rdata = {31'b0, controller_enable_q};
         STATUS_OFFSET:    req_rdata = status_value;
         CLOCK_DIV_OFFSET: req_rdata = clock_div_q;
         TXDATA_OFFSET:    req_rdata = {24'b0, tx_data_q};
         RXDATA_OFFSET:    req_rdata = {24'b0, rx_data_q};
         TIMEOUT_OFFSET:   req_rdata = timeout_q;
         default:          req_rdata = 32'b0;
      endcase
   end


   always_comb begin
      scl_drive_low = 1'b0;
      sda_drive_low = 1'b0;

      unique case (state_q)
         ST_IDLE: begin
            scl_drive_low = bus_active_q;
         end
         ST_START_RELEASE: begin
         end
         ST_START_SDA_LOW: begin
            sda_drive_low = 1'b1;
         end
         ST_START_SCL_LOW: begin
            scl_drive_low = 1'b1;
            sda_drive_low = 1'b1;
         end
         ST_STOP_SDA_LOW: begin
            scl_drive_low = 1'b1;
            sda_drive_low = 1'b1;
         end
         ST_STOP_SCL_HIGH: begin
            sda_drive_low = 1'b1;
         end
         ST_STOP_RELEASE: begin
         end
         ST_WRITE_BIT_LOW: begin
            scl_drive_low = 1'b1;
            sda_drive_low = !tx_shift_q[bit_index_q];
         end
         ST_WRITE_BIT_HIGH: begin
            sda_drive_low = !tx_shift_q[bit_index_q];
         end
         ST_WRITE_ACK_LOW: begin
            scl_drive_low = 1'b1;
         end
         ST_WRITE_ACK_HIGH: begin
         end
         ST_WRITE_ACK_FINISH: begin
            scl_drive_low = 1'b1;
         end
         ST_READ_BIT_LOW: begin
            scl_drive_low = 1'b1;
         end
         ST_READ_BIT_HIGH: begin
         end
         ST_READ_ACK_LOW: begin
            scl_drive_low = 1'b1;
            sda_drive_low = !read_nack_q;
         end
         ST_READ_ACK_HIGH: begin
            sda_drive_low = !read_nack_q;
         end
         ST_READ_ACK_FINISH: begin
            scl_drive_low = 1'b1;
         end
         ST_RECOVER_LOW: begin
            scl_drive_low = 1'b1;
         end
         ST_RECOVER_HIGH: begin
         end
         default: begin
         end
      endcase
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         state_q              <= ST_IDLE;
         controller_enable_q  <= 1'b0;
         busy_q               <= 1'b0;
         done_q               <= 1'b0;
         addr_nack_q          <= 1'b0;
         data_nack_q          <= 1'b0;
         timeout_error_q      <= 1'b0;
         arbitration_lost_q   <= 1'b0;
         bus_stuck_q          <= 1'b0;
         bus_active_q         <= 1'b0;
         rx_valid_q           <= 1'b0;
         command_address_q    <= 1'b0;
         read_nack_q          <= 1'b0;
         bit_index_q          <= 3'd7;
         recovery_count_q     <= 4'd0;
         tx_data_q            <= 8'b0;
         tx_shift_q           <= 8'b0;
         rx_data_q            <= 8'b0;
         rx_shift_q           <= 8'b0;
         clock_div_q          <= RESET_CLOCK_DIV;
         timeout_q            <= RESET_TIMEOUT;
         phase_count_q        <= 32'b0;
         command_timer_q      <= 32'b0;
      end else begin

         if (req_valid && req_write && (req_addr == STATUS_OFFSET) &&
             req_wstrb[0]) begin
            if (req_wdata[1]) done_q             <= 1'b0;
            if (req_wdata[2]) addr_nack_q        <= 1'b0;
            if (req_wdata[3]) data_nack_q        <= 1'b0;
            if (req_wdata[4]) timeout_error_q    <= 1'b0;
            if (req_wdata[5]) arbitration_lost_q <= 1'b0;
            if (req_wdata[6]) bus_stuck_q        <= 1'b0;
         end

         if (req_valid && req_write && (req_addr == CLOCK_DIV_OFFSET))
            clock_div_q <= apply_wstrb(clock_div_q, req_wdata, req_wstrb);
         if (req_valid && req_write && (req_addr == TIMEOUT_OFFSET))
            timeout_q <= apply_wstrb(timeout_q, req_wdata, req_wstrb);
         if (req_valid && req_write && (req_addr == TXDATA_OFFSET) &&
             req_wstrb[0])
            tx_data_q <= req_wdata[7:0];

         if (req_valid && req_write && (req_addr == CONTROL_OFFSET) &&
             req_wstrb[0]) begin
            controller_enable_q <= req_wdata[0];

            if (req_wdata[1]) begin
               state_q            <= ST_IDLE;
               busy_q             <= 1'b0;
               done_q             <= 1'b0;
               addr_nack_q        <= 1'b0;
               data_nack_q        <= 1'b0;
               timeout_error_q    <= 1'b0;
               arbitration_lost_q <= 1'b0;
               bus_stuck_q        <= 1'b0;
               bus_active_q       <= 1'b0;
               rx_valid_q         <= 1'b0;
               phase_count_q      <= 32'b0;
               command_timer_q    <= 32'b0;
            end else if (req_wdata[2] && req_wdata[0] && !busy_q) begin
               state_q          <= ST_RECOVER_LOW;
               busy_q           <= 1'b1;
               done_q           <= 1'b0;
               bus_active_q     <= 1'b0;
               recovery_count_q <= 4'd0;
               phase_count_q    <= 32'b0;
               command_timer_q  <= 32'b0;
            end
         end else if (req_valid && req_write &&
                      (req_addr == COMMAND_OFFSET) && req_wstrb[0] &&
                      controller_enable_q && !busy_q) begin
            done_q            <= 1'b0;
            command_timer_q   <= 32'b0;
            phase_count_q     <= 32'b0;
            command_address_q <= req_wdata[5];
            read_nack_q       <= req_wdata[4];

            unique case (req_wdata[3:0])
               4'b0001: begin
                  state_q <= ST_START_RELEASE;
                  busy_q  <= 1'b1;
               end
               4'b0010: begin
                  state_q <= ST_STOP_SDA_LOW;
                  busy_q  <= 1'b1;
               end
               4'b0100: begin
                  if (bus_active_q) begin
                     state_q     <= ST_WRITE_BIT_LOW;
                     busy_q      <= 1'b1;
                     bit_index_q <= 3'd7;
                     tx_shift_q  <= tx_data_q;
                  end else begin
                     done_q        <= 1'b1;
                     bus_stuck_q   <= 1'b1;
                  end
               end
               4'b1000: begin
                  if (bus_active_q) begin
                     state_q     <= ST_READ_BIT_LOW;
                     busy_q      <= 1'b1;
                     bit_index_q <= 3'd7;
                     rx_shift_q  <= 8'b0;
                     rx_valid_q  <= 1'b0;
                  end else begin
                     done_q      <= 1'b1;
                     bus_stuck_q <= 1'b1;
                  end
               end
               default: begin
                  done_q      <= 1'b1;
                  bus_stuck_q <= 1'b1;
               end
            endcase
         end else if (busy_q) begin
            command_timer_q <= command_timer_q + 1'b1;

            if ((timeout_q != 0) &&
                (command_timer_q == timeout_q - 1'b1)) begin
               state_q          <= ST_IDLE;
               busy_q           <= 1'b0;
               done_q           <= 1'b1;
               timeout_error_q  <= 1'b1;
               bus_stuck_q      <= !scl_i || !sda_i;
               bus_active_q     <= 1'b0;
               phase_count_q    <= 32'b0;
               command_timer_q  <= 32'b0;
            end else begin
               unique case (state_q)
                  ST_START_RELEASE: begin
                     if (scl_i && sda_i) begin
                        if (phase_count_q == clock_div_q) begin
                           state_q       <= ST_START_SDA_LOW;
                           phase_count_q <= 32'b0;
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_START_SDA_LOW: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           state_q       <= ST_START_SCL_LOW;
                           phase_count_q <= 32'b0;
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_START_SCL_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q          <= ST_IDLE;
                        busy_q           <= 1'b0;
                        done_q           <= 1'b1;
                        bus_active_q     <= 1'b1;
                        phase_count_q    <= 32'b0;
                        command_timer_q  <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_STOP_SDA_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_STOP_SCL_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_STOP_SCL_HIGH: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           state_q       <= ST_STOP_RELEASE;
                           phase_count_q <= 32'b0;
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_STOP_RELEASE: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q          <= ST_IDLE;
                        busy_q           <= 1'b0;
                        done_q           <= 1'b1;
                        bus_active_q     <= 1'b0;
                        bus_stuck_q      <= !scl_i || !sda_i;
                        phase_count_q    <= 32'b0;
                        command_timer_q  <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_WRITE_BIT_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_WRITE_BIT_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_WRITE_BIT_HIGH: begin
                     if (scl_i) begin
                        if (tx_shift_q[bit_index_q] && !sda_i) begin
                           state_q            <= ST_IDLE;
                           busy_q             <= 1'b0;
                           done_q             <= 1'b1;
                           arbitration_lost_q <= 1'b1;
                           bus_active_q       <= 1'b0;
                           phase_count_q      <= 32'b0;
                           command_timer_q    <= 32'b0;
                        end else if (phase_count_q == clock_div_q) begin
                           phase_count_q <= 32'b0;
                           if (bit_index_q == 0) begin
                              state_q <= ST_WRITE_ACK_LOW;
                           end else begin
                              bit_index_q <= bit_index_q - 1'b1;
                              state_q     <= ST_WRITE_BIT_LOW;
                           end
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_WRITE_ACK_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_WRITE_ACK_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_WRITE_ACK_HIGH: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           if (sda_i) begin
                              if (command_address_q)
                                 addr_nack_q <= 1'b1;
                              else
                                 data_nack_q <= 1'b1;
                           end
                           state_q       <= ST_WRITE_ACK_FINISH;
                           phase_count_q <= 32'b0;
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_WRITE_ACK_FINISH: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q          <= ST_IDLE;
                        busy_q           <= 1'b0;
                        done_q           <= 1'b1;
                        phase_count_q    <= 32'b0;
                        command_timer_q  <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_READ_BIT_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_READ_BIT_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_READ_BIT_HIGH: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           rx_shift_q[bit_index_q] <= sda_i;
                           phase_count_q           <= 32'b0;
                           if (bit_index_q == 0) begin
                              state_q <= ST_READ_ACK_LOW;
                           end else begin
                              bit_index_q <= bit_index_q - 1'b1;
                              state_q     <= ST_READ_BIT_LOW;
                           end
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_READ_ACK_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_READ_ACK_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_READ_ACK_HIGH: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           state_q       <= ST_READ_ACK_FINISH;
                           phase_count_q <= 32'b0;
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  ST_READ_ACK_FINISH: begin
                     if (phase_count_q == clock_div_q) begin
                        rx_data_q        <= rx_shift_q;
                        rx_valid_q       <= 1'b1;
                        state_q          <= ST_IDLE;
                        busy_q           <= 1'b0;
                        done_q           <= 1'b1;
                        phase_count_q    <= 32'b0;
                        command_timer_q  <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_RECOVER_LOW: begin
                     if (phase_count_q == clock_div_q) begin
                        state_q       <= ST_RECOVER_HIGH;
                        phase_count_q <= 32'b0;
                     end else begin
                        phase_count_q <= phase_count_q + 1'b1;
                     end
                  end
                  ST_RECOVER_HIGH: begin
                     if (scl_i) begin
                        if (phase_count_q == clock_div_q) begin
                           phase_count_q <= 32'b0;
                           if ((recovery_count_q == 4'd8) || sda_i) begin
                              state_q          <= ST_STOP_SDA_LOW;
                              bus_active_q     <= 1'b1;
                              recovery_count_q <= 4'd0;
                           end else begin
                              recovery_count_q <= recovery_count_q + 1'b1;
                              state_q          <= ST_RECOVER_LOW;
                           end
                        end else begin
                           phase_count_q <= phase_count_q + 1'b1;
                        end
                     end else begin
                        phase_count_q <= 32'b0;
                     end
                  end
                  default: begin
                     state_q          <= ST_IDLE;
                     busy_q           <= 1'b0;
                     done_q           <= 1'b1;
                     bus_stuck_q      <= 1'b1;
                     bus_active_q     <= 1'b0;
                     phase_count_q    <= 32'b0;
                     command_timer_q  <= 32'b0;
                  end
               endcase
            end
         end
      end
   end
endmodule
