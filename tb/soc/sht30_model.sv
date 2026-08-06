module sht30_model #(
  parameter logic [6:0] I2C_ADDRESS  = 7'h44,
  parameter logic [15:0] TEMPERATURE_RAW = 16'h6666,
  parameter logic [15:0] HUMIDITY_RAW    = 16'h8000
) (
  inout wire scl_io,
  inout wire sda_io
);
  logic sda_drive_low;
  logic [7:0] payload [0:5];

  assign sda_io = sda_drive_low ? 1'b0 : 1'bz;

  function automatic logic [7:0] crc_word(input logic [15:0] word);
    logic [7:0] crc;
    logic [7:0] data_byte;
    integer byte_index;
    integer bit_index;
    begin
      crc = 8'hff;
      for (byte_index = 0; byte_index < 2; byte_index = byte_index + 1) begin
        data_byte = (byte_index == 0) ? word[15:8] : word[7:0];
        crc = crc ^ data_byte;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
          crc = crc[7] ? ((crc << 1) ^ 8'h31) : (crc << 1);
        end
      end
      return crc;
    end
  endfunction

  task automatic wait_for_start;
    logic found;
    begin
      found = 1'b0;
      while (!found) begin
        @(negedge sda_io);
        found = (scl_io === 1'b1);
      end
    end
  endtask

  task automatic wait_for_stop;
    logic found;
    begin
      found = 1'b0;
      while (!found) begin
        @(posedge sda_io);
        found = (scl_io === 1'b1);
      end
    end
  endtask

  task automatic receive_byte(output logic [7:0] value);
    integer bit_index;
    begin
      value = 8'b0;
      for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
        @(posedge scl_io);
        value[bit_index] = sda_io;
      end
    end
  endtask

  task automatic acknowledge;
    begin
      @(negedge scl_io);
      sda_drive_low = 1'b1;
      @(posedge scl_io);
      @(negedge scl_io);
      sda_drive_low = 1'b0;
    end
  endtask

  task automatic send_byte(
      input logic [7:0] value,
      output logic master_acknowledged
  );
    integer bit_index;
    begin
      for (bit_index = 7; bit_index >= 0; bit_index = bit_index - 1) begin
        sda_drive_low = !value[bit_index];
        @(posedge scl_io);
        @(negedge scl_io);
      end
      sda_drive_low = 1'b0;
      @(posedge scl_io);
      master_acknowledged = (sda_io === 1'b0);
      @(negedge scl_io);
    end
  endtask

  initial begin : sensor_process
    logic [7:0] address_byte;
    logic [7:0] command_msb;
    logic [7:0] command_lsb;
    logic master_acknowledged;
    integer payload_index;

    sda_drive_low = 1'b0;
    payload[0] = TEMPERATURE_RAW[15:8];
    payload[1] = TEMPERATURE_RAW[7:0];
    payload[2] = crc_word(TEMPERATURE_RAW);
    payload[3] = HUMIDITY_RAW[15:8];
    payload[4] = HUMIDITY_RAW[7:0];
    payload[5] = crc_word(HUMIDITY_RAW);

    forever begin
      wait_for_start();
      receive_byte(address_byte);
      if (address_byte != {I2C_ADDRESS, 1'b0}) begin
        wait_for_stop();
      end else begin
        acknowledge();
        receive_byte(command_msb);
        acknowledge();
        receive_byte(command_lsb);
        acknowledge();
        wait_for_stop();

        if ({command_msb, command_lsb} == 16'h2400) begin
          wait_for_start();
          receive_byte(address_byte);
          if (address_byte == {I2C_ADDRESS, 1'b1}) begin
            acknowledge();
            for (payload_index = 0; payload_index < 6;
                 payload_index = payload_index + 1) begin
              send_byte(payload[payload_index], master_acknowledged);
            end
            wait_for_stop();
          end else begin
            wait_for_stop();
          end
        end
      end
    end
  end
endmodule
