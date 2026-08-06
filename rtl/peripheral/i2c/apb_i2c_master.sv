module apb_i2c_master #(
  parameter int unsigned CLOCK_HZ = soc_config_pkg::SOC_CLOCK_HZ,
  parameter int unsigned I2C_HZ   = 100_000
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] pwdata_i,
  input  logic [3:0]  pstrb_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,
  input  logic        scl_i,
  input  logic        sda_i,
  output logic        scl_drive_low_o,
  output logic        sda_drive_low_o,
  output logic        irq_o
);
  import common_types_pkg::apply_wstrb;

  localparam int unsigned DEFAULT_CLKDIV =
      ((CLOCK_HZ / (2 * I2C_HZ)) == 0) ? 1 : (CLOCK_HZ / (2 * I2C_HZ));

  localparam logic [31:0] CONTROL_ENABLE     = 32'h0000_0001;
  localparam logic [31:0] CONTROL_SOFT_RESET = 32'h8000_0000;
  localparam logic [31:0] COMMAND_GO         = 32'h0000_0001;
  localparam logic [31:0] COMMAND_START      = 32'h0000_0002;
  localparam logic [31:0] COMMAND_STOP       = 32'h0000_0004;
  localparam logic [31:0] COMMAND_READ       = 32'h0000_0008;
  localparam logic [31:0] COMMAND_NACK       = 32'h0000_0010;

  typedef enum logic [3:0] {
    ENG_IDLE,
    START_HIGH,
    START_HOLD,
    WRITE_LOW,
    WRITE_HIGH,
    SLAVE_ACK_LOW,
    SLAVE_ACK_HIGH,
    READ_LOW,
    READ_HIGH,
    MASTER_ACK_LOW,
    MASTER_ACK_HIGH,
    STOP_LOW,
    STOP_HIGH,
    STOP_RELEASE
  } engine_state_t;

  engine_state_t state_q;
  logic [1:0]  control_q;
  logic [31:0] clkdiv_q;
  logic [7:0]  txdata_q;
  logic [7:0]  rxdata_q;
  logic [7:0]  shift_q;
  logic [2:0]  bit_index_q;
  logic [31:0] phase_count_q;
  logic busy_q;
  logic done_q;
  logic ack_error_q;
  logic rx_valid_q;
  logic bus_active_q;
  logic cmd_stop_q;
  logic cmd_read_q;
  logic cmd_nack_q;
  logic scl_drive_low_q;
  logic sda_drive_low_q;
  logic address_valid;
  logic apb_write;
  logic control_write;
  logic command_write;

  assign address_valid =
      (paddr_i[11:0] == 12'h000) ||
      (paddr_i[11:0] == 12'h004) ||
      (paddr_i[11:0] == 12'h008) ||
      (paddr_i[11:0] == 12'h00c) ||
      (paddr_i[11:0] == 12'h010) ||
      (paddr_i[11:0] == 12'h014);
  assign apb_write = psel_i && penable_i && pwrite_i;
  assign control_write = apb_write && (paddr_i[11:0] == 12'h000);
  assign command_write = apb_write && (paddr_i[11:0] == 12'h014) &&
                         (&pstrb_i) && ((pwdata_i & COMMAND_GO) != 0);

  assign pready_o = 1'b1;
  assign pslverr_o = psel_i && penable_i && !address_valid;
  assign scl_drive_low_o = scl_drive_low_q;
  assign sda_drive_low_o = sda_drive_low_q;
  assign irq_o = control_q[1] && done_q;

  always_comb begin
    case (paddr_i[11:0])
      12'h000: prdata_o = {30'b0, control_q};
      12'h004: prdata_o = {
        27'b0,
        bus_active_q,
        rx_valid_q,
        ack_error_q,
        done_q,
        busy_q
      };
      12'h008: prdata_o = clkdiv_q;
      12'h00c: prdata_o = {24'b0, txdata_q};
      12'h010: prdata_o = {24'b0, rxdata_q};
      12'h014: prdata_o = 32'b0;
      default: prdata_o = 32'b0;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    logic [31:0] merged;
    if (!rst_ni) begin
      state_q         <= ENG_IDLE;
      control_q       <= CONTROL_ENABLE[1:0];
      clkdiv_q        <= DEFAULT_CLKDIV;
      txdata_q        <= 8'b0;
      rxdata_q        <= 8'b0;
      shift_q         <= 8'b0;
      bit_index_q     <= 3'd7;
      phase_count_q   <= 32'b0;
      busy_q          <= 1'b0;
      done_q          <= 1'b0;
      ack_error_q     <= 1'b0;
      rx_valid_q      <= 1'b0;
      bus_active_q    <= 1'b0;
      cmd_stop_q      <= 1'b0;
      cmd_read_q      <= 1'b0;
      cmd_nack_q      <= 1'b0;
      scl_drive_low_q <= 1'b0;
      sda_drive_low_q <= 1'b0;
    end else begin
      if (control_write && pstrb_i[0]) begin
        control_q <= pwdata_i[1:0];
      end
      if (apb_write && (paddr_i[11:0] == 12'h004) && pstrb_i[0]) begin
        if (pwdata_i[1]) done_q      <= 1'b0;
        if (pwdata_i[2]) ack_error_q <= 1'b0;
        if (pwdata_i[3]) rx_valid_q  <= 1'b0;
      end
      if (apb_write && (paddr_i[11:0] == 12'h008)) begin
        merged = apply_wstrb(clkdiv_q, pwdata_i, pstrb_i);
        clkdiv_q <= (merged == 0) ? 32'd1 : merged;
      end
      if (apb_write && (paddr_i[11:0] == 12'h00c) && pstrb_i[0]) begin
        txdata_q <= pwdata_i[7:0];
      end

      if ((control_write && pstrb_i[3] &&
           ((pwdata_i & CONTROL_SOFT_RESET) != 0)) ||
          !control_q[0] ||
          (control_write && pstrb_i[0] &&
           ((pwdata_i & CONTROL_ENABLE) == 0))) begin
        state_q         <= ENG_IDLE;
        busy_q          <= 1'b0;
        done_q          <= 1'b0;
        ack_error_q     <= 1'b0;
        rx_valid_q      <= 1'b0;
        bus_active_q    <= 1'b0;
        phase_count_q   <= 32'b0;
        scl_drive_low_q <= 1'b0;
        sda_drive_low_q <= 1'b0;
      end else begin
        case (state_q)
          ENG_IDLE: begin
          end

          START_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                sda_drive_low_q <= 1'b1;
                phase_count_q   <= clkdiv_q - 1'b1;
                state_q         <= START_HOLD;
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          START_HOLD: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b1;
              phase_count_q   <= clkdiv_q - 1'b1;
              if (cmd_read_q) begin
                sda_drive_low_q <= 1'b0;
                shift_q         <= 8'b0;
                bit_index_q     <= 3'd7;
                state_q         <= READ_LOW;
              end else begin
                sda_drive_low_q <= ~shift_q[7];
                bit_index_q     <= 3'd7;
                state_q         <= WRITE_LOW;
              end
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          WRITE_LOW: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b0;
              phase_count_q   <= clkdiv_q - 1'b1;
              state_q         <= WRITE_HIGH;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          WRITE_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                scl_drive_low_q <= 1'b1;
                phase_count_q   <= clkdiv_q - 1'b1;
                if (bit_index_q == 0) begin
                  sda_drive_low_q <= 1'b0;
                  state_q         <= SLAVE_ACK_LOW;
                end else begin
                  bit_index_q     <= bit_index_q - 1'b1;
                  sda_drive_low_q <= ~shift_q[bit_index_q - 1'b1];
                  state_q         <= WRITE_LOW;
                end
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          SLAVE_ACK_LOW: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b0;
              phase_count_q   <= clkdiv_q - 1'b1;
              state_q         <= SLAVE_ACK_HIGH;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          SLAVE_ACK_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                ack_error_q     <= ack_error_q | sda_i;
                scl_drive_low_q <= 1'b1;
                phase_count_q   <= clkdiv_q - 1'b1;
                if (cmd_stop_q) begin
                  sda_drive_low_q <= 1'b1;
                  state_q         <= STOP_LOW;
                end else begin
                  busy_q          <= 1'b0;
                  done_q          <= 1'b1;
                  sda_drive_low_q <= 1'b0;
                  state_q         <= ENG_IDLE;
                end
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          READ_LOW: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b0;
              phase_count_q   <= clkdiv_q - 1'b1;
              state_q         <= READ_HIGH;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          READ_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                shift_q         <= {shift_q[6:0], sda_i};
                scl_drive_low_q <= 1'b1;
                phase_count_q   <= clkdiv_q - 1'b1;
                if (bit_index_q == 0) begin
                  rxdata_q        <= {shift_q[6:0], sda_i};
                  rx_valid_q      <= 1'b1;
                  sda_drive_low_q <= !cmd_nack_q;
                  state_q         <= MASTER_ACK_LOW;
                end else begin
                  bit_index_q <= bit_index_q - 1'b1;
                  state_q     <= READ_LOW;
                end
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          MASTER_ACK_LOW: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b0;
              phase_count_q   <= clkdiv_q - 1'b1;
              state_q         <= MASTER_ACK_HIGH;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          MASTER_ACK_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                scl_drive_low_q <= 1'b1;
                phase_count_q   <= clkdiv_q - 1'b1;
                if (cmd_stop_q) begin
                  sda_drive_low_q <= 1'b1;
                  state_q         <= STOP_LOW;
                end else begin
                  busy_q          <= 1'b0;
                  done_q          <= 1'b1;
                  sda_drive_low_q <= 1'b0;
                  state_q         <= ENG_IDLE;
                end
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          STOP_LOW: begin
            if (phase_count_q == 0) begin
              scl_drive_low_q <= 1'b0;
              phase_count_q   <= clkdiv_q - 1'b1;
              state_q         <= STOP_HIGH;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          STOP_HIGH: begin
            if (scl_i) begin
              if (phase_count_q == 0) begin
                sda_drive_low_q <= 1'b0;
                phase_count_q   <= clkdiv_q - 1'b1;
                state_q         <= STOP_RELEASE;
              end else begin
                phase_count_q <= phase_count_q - 1'b1;
              end
            end
          end

          STOP_RELEASE: begin
            if (phase_count_q == 0) begin
              busy_q       <= 1'b0;
              done_q       <= 1'b1;
              bus_active_q <= 1'b0;
              state_q      <= ENG_IDLE;
            end else begin
              phase_count_q <= phase_count_q - 1'b1;
            end
          end

          default: state_q <= ENG_IDLE;
        endcase

        if (command_write && !busy_q && control_q[0]) begin
          busy_q        <= 1'b1;
          done_q        <= 1'b0;
          ack_error_q   <= 1'b0;
          rx_valid_q    <= 1'b0;
          cmd_stop_q    <= (pwdata_i & COMMAND_STOP) != 0;
          cmd_read_q    <= (pwdata_i & COMMAND_READ) != 0;
          cmd_nack_q    <= (pwdata_i & COMMAND_NACK) != 0;
          shift_q       <= txdata_q;
          bit_index_q   <= 3'd7;
          phase_count_q <= clkdiv_q - 1'b1;
          if ((pwdata_i & COMMAND_START) != 0) begin
            bus_active_q    <= 1'b1;
            scl_drive_low_q <= 1'b0;
            sda_drive_low_q <= 1'b0;
            state_q         <= START_HIGH;
          end else if ((pwdata_i & COMMAND_READ) != 0) begin
            scl_drive_low_q <= 1'b1;
            sda_drive_low_q <= 1'b0;
            shift_q         <= 8'b0;
            state_q         <= READ_LOW;
          end else begin
            scl_drive_low_q <= 1'b1;
            sda_drive_low_q <= ~txdata_q[7];
            state_q         <= WRITE_LOW;
          end
        end
      end
    end
  end
endmodule
