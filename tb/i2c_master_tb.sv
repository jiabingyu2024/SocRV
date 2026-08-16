`timescale 1ns/1ps

module i2c_master_tb;
  localparam logic [11:0] CONTROL   = 12'h000;
  localparam logic [11:0] STATUS    = 12'h004;
  localparam logic [11:0] CLOCK_DIV = 12'h008;
  localparam logic [11:0] TXDATA    = 12'h00c;
  localparam logic [11:0] RXDATA    = 12'h010;
  localparam logic [11:0] COMMAND   = 12'h014;

  localparam logic [31:0] CTRL_ENABLE = 32'h0000_0001;
  localparam logic [31:0] CTRL_RESET  = 32'h0000_0002;
  localparam logic [31:0] CTRL_RECOVER = 32'h0000_0004;
  localparam logic [31:0] ST_BUSY = 32'h0000_0001;
  localparam logic [31:0] ST_DONE = 32'h0000_0002;
  localparam logic [31:0] ST_ADDR_NACK = 32'h0000_0004;
  localparam logic [31:0] ST_DATA_NACK = 32'h0000_0008;
  localparam logic [31:0] ST_TIMEOUT = 32'h0000_0010;
  localparam logic [31:0] ST_BUS_STUCK = 32'h0000_0040;
  localparam logic [31:0] ST_BUS_ACTIVE = 32'h0000_0200;
  localparam logic [31:0] ST_BUS_READY = 32'h0000_0400;
  localparam logic [31:0] CMD_START = 32'h0000_0001;
  localparam logic [31:0] CMD_STOP = 32'h0000_0002;
  localparam logic [31:0] CMD_WRITE = 32'h0000_0004;
  localparam logic [31:0] CMD_READ = 32'h0000_0008;
  localparam logic [31:0] CMD_READ_NACK = 32'h0000_0010;
  localparam logic [31:0] CMD_ADDRESS = 32'h0000_0020;

  logic clk = 1'b0;
  logic rst_l = 1'b0;
  logic req_valid = 1'b0;
  logic req_write = 1'b0;
  logic [11:0] req_addr = 12'b0;
  logic [31:0] req_wdata = 32'b0;
  logic [3:0] req_wstrb = 4'b0;
  logic req_ready;
  logic [31:0] req_rdata;
  logic scl_drive_low;
  logic sda_drive_low;
  logic slave_scl_low = 1'b0;
  logic slave_sda_low = 1'b0;
  tri1 scl_bus;
  tri1 sda_bus;

  always #5 clk = ~clk;

  assign scl_bus = scl_drive_low ? 1'b0 : 1'bz;
  assign sda_bus = sda_drive_low ? 1'b0 : 1'bz;
  assign scl_bus = slave_scl_low ? 1'b0 : 1'bz;
  assign sda_bus = slave_sda_low ? 1'b0 : 1'bz;

  i2c_master #(
    .RESET_CLOCK_DIV(1),
    .RESET_TIMEOUT(1000)
  ) dut (
    .clk,
    .rst_l,
    .req_valid,
    .req_write,
    .req_addr,
    .req_wdata,
    .req_wstrb,
    .req_ready,
    .req_rdata,
    .scl_i(scl_bus),
    .sda_i(sda_bus),
    .scl_drive_low,
    .sda_drive_low
  );

  task automatic mmio_write(
    input logic [11:0] address,
    input logic [31:0] value
  );
    begin
      @(negedge clk);
      req_valid = 1'b1;
      req_write = 1'b1;
      req_addr = address;
      req_wdata = value;
      req_wstrb = 4'hf;
      @(negedge clk);
      req_valid = 1'b0;
      req_write = 1'b0;
      req_addr = 12'b0;
      req_wdata = 32'b0;
      req_wstrb = 4'b0;
    end
  endtask

  task automatic mmio_read(
    input logic [11:0] address,
    output logic [31:0] value
  );
    begin
      @(negedge clk);
      req_valid = 1'b1;
      req_write = 1'b0;
      req_addr = address;
      req_wstrb = 4'b0;
      #1 value = req_rdata;
      @(negedge clk);
      req_valid = 1'b0;
      req_addr = 12'b0;
    end
  endtask

  task automatic wait_done(output logic [31:0] status);
    integer poll;
    begin : wait_loop
      status = 32'b0;
      for (poll = 0; poll < 2000; poll = poll + 1) begin
        mmio_read(STATUS, status);
        if (((status & ST_BUSY) == 0) && ((status & ST_DONE) != 0))
          disable wait_loop;
      end
      $fatal(1, "I2C command timeout in testbench, status=%08x", status);
    end
  endtask

  task automatic issue_command(
    input logic [31:0] command,
    output logic [31:0] status
  );
    begin
      mmio_write(STATUS, ST_DONE);
      mmio_write(COMMAND, command);
      wait_done(status);
    end
  endtask

  task automatic respond_to_write(input logic acknowledge);
    integer bit_number;
    begin
      for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
        @(posedge scl_bus);
        @(negedge scl_bus);
      end
      slave_sda_low = acknowledge;
      @(posedge scl_bus);
      @(negedge scl_bus);
      slave_sda_low = 1'b0;
    end
  endtask

  task automatic provide_read_byte(input logic [7:0] value);
    integer bit_number;
    begin
      for (bit_number = 7; bit_number >= 0; bit_number = bit_number - 1) begin
        wait (scl_bus === 1'b0);
        slave_sda_low = !value[bit_number];
        @(posedge scl_bus);
        @(negedge scl_bus);
      end
      slave_sda_low = 1'b0;
    end
  endtask

  task automatic check_scl_phase_timing(input realtime expected_phase_ns);
    realtime low_started;
    realtime high_started;
    realtime high_ended;
    realtime low_duration;
    realtime high_duration;
    begin
      @(negedge scl_bus);
      low_started = $realtime;
      @(posedge scl_bus);
      high_started = $realtime;
      @(negedge scl_bus);
      high_ended = $realtime;
      low_duration = high_started - low_started;
      high_duration = high_ended - high_started;
      if (low_duration < expected_phase_ns - 0.01 ||
          low_duration > expected_phase_ns + 0.01 ||
          high_duration < expected_phase_ns - 0.01 ||
          high_duration > expected_phase_ns + 0.01)
        $fatal(
          1,
          "unexpected SCL timing: low=%0.2fns high=%0.2fns expected=%0.2fns",
          low_duration,
          high_duration,
          expected_phase_ns
        );
    end
  endtask

  logic [31:0] status;
  logic [31:0] value;

  initial begin
    repeat (4) @(posedge clk);
    rst_l = 1'b1;
    repeat (3) @(posedge clk);

    mmio_read(STATUS, status);
    if ((status & ST_BUS_READY) == 0)
      $fatal(1, "bus was not ready after reset: %08x", status);

    mmio_write(CONTROL, CTRL_ENABLE | CTRL_RESET);
    mmio_write(CONTROL, CTRL_ENABLE);
    mmio_write(CLOCK_DIV, 32'd3);
    mmio_read(CLOCK_DIV, value);
    if (value != 32'd3)
      $fatal(1, "clock divider readback mismatch: %08x", value);

    issue_command(CMD_START, status);
    if ((status & ST_BUS_ACTIVE) == 0)
      $fatal(1, "START did not make the bus active: %08x", status);

    mmio_write(TXDATA, 8'h46);
    fork
      respond_to_write(1'b1);
      check_scl_phase_timing(40.0);
      issue_command(CMD_WRITE | CMD_ADDRESS, status);
    join
    if ((status & ST_ADDR_NACK) != 0)
      $fatal(1, "ACK was reported as address NACK: %08x", status);

    mmio_write(TXDATA, 8'h20);
    fork
      respond_to_write(1'b0);
      issue_command(CMD_WRITE, status);
    join
    if ((status & ST_DATA_NACK) == 0)
      $fatal(1, "data NACK was not latched: %08x", status);
    issue_command(CMD_STOP, status);
    if ((status & ST_BUS_ACTIVE) != 0 || (status & ST_BUS_READY) == 0)
      $fatal(1, "STOP did not restore an idle bus: %08x", status);

    mmio_write(STATUS, 32'h0000_007e);
    issue_command(CMD_START, status);
    mmio_write(TXDATA, 8'h78);
    fork
      respond_to_write(1'b0);
      issue_command(CMD_WRITE | CMD_ADDRESS, status);
    join
    if ((status & ST_ADDR_NACK) == 0)
      $fatal(1, "address NACK was not latched: %08x", status);
    issue_command(CMD_STOP, status);

    mmio_write(STATUS, 32'h0000_007e);
    issue_command(CMD_START, status);
    mmio_write(TXDATA, 8'h47);
    fork
      respond_to_write(1'b1);
      issue_command(CMD_WRITE | CMD_ADDRESS, status);
    join
    fork
      provide_read_byte(8'ha5);
      issue_command(CMD_READ | CMD_READ_NACK, status);
    join
    mmio_read(RXDATA, value);
    if (value[7:0] != 8'ha5)
      $fatal(1, "read byte mismatch: %02x", value[7:0]);
    issue_command(CMD_STOP, status);

    mmio_write(STATUS, 32'h0000_007e);
    issue_command(CMD_START, status);
    slave_sda_low = 1'b1;
    issue_command(CMD_STOP, status);
    if ((status & ST_BUS_STUCK) == 0 || (status & ST_BUS_ACTIVE) != 0)
      $fatal(1, "failed STOP was not reported: %08x", status);
    slave_sda_low = 1'b0;

    slave_sda_low = 1'b1;
    fork
      begin
        repeat (3) @(posedge scl_bus);
        slave_sda_low = 1'b0;
      end
      begin
        mmio_write(STATUS, 32'h0000_007e);
        mmio_write(CONTROL, CTRL_ENABLE | CTRL_RECOVER);
        wait_done(status);
      end
    join
    if ((status & ST_BUS_READY) == 0)
      $fatal(1, "bus recovery did not restore idle bus: %08x", status);

    slave_scl_low = 1'b1;
    mmio_write(STATUS, 32'h0000_007e);
    issue_command(CMD_START, status);
    if ((status & (ST_TIMEOUT | ST_BUS_STUCK)) !=
        (ST_TIMEOUT | ST_BUS_STUCK))
      $fatal(1, "stuck SCL did not time out cleanly: %08x", status);
    slave_scl_low = 1'b0;

    mmio_write(CONTROL, CTRL_ENABLE | CTRL_RESET);
    mmio_write(CONTROL, CTRL_ENABLE);
    mmio_read(STATUS, status);
    if ((status & (ST_BUSY | ST_BUS_ACTIVE)) != 0)
      $fatal(1, "software reset did not release the bus: %08x", status);

    $display("PASS: I2C MMIO master");
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "testbench watchdog timeout");
  end
endmodule
