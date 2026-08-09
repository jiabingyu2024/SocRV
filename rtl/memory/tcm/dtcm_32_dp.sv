// 64 KiB byte-writeable D-TCM. The CPU port is synchronous and returns one
// response for every accepted load or store. A second physical port is reserved
// by the architecture for debug/loader use and is not exposed in this phase.
module dtcm_32_dp #(
  parameter int unsigned BYTES = memory_map_pkg::DATA_SIZE,
  parameter string MEM_FILE = ""
) (
  input logic clk_i,
  input logic rst_ni,
  cpu_data_if.slave data
);
  localparam int unsigned WORDS = BYTES / 4;
  localparam int unsigned INDEX_W = $clog2(WORDS);
  logic valid_q, error_q, advance, req_fire;

  assign advance = !valid_q || data.rsp_ready;
  assign data.req_ready = advance;
  assign req_fire = data.req_valid && data.req_ready;
  assign data.rsp_valid = valid_q;
  assign data.rsp_error = error_q;

`ifdef SYNTHESIS
  logic [31:0] bram_rdata;
  xpm_memory_spram #(
    .ADDR_WIDTH_A(INDEX_W), .AUTO_SLEEP_TIME(0), .BYTE_WRITE_WIDTH_A(8),
    .ECC_MODE("no_ecc"), .MEMORY_INIT_FILE(MEM_FILE), .MEMORY_INIT_PARAM(""),
    .MEMORY_OPTIMIZATION("true"), .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(BYTES * 8), .MESSAGE_CONTROL(0), .READ_DATA_WIDTH_A(32),
    .READ_LATENCY_A(1), .READ_RESET_VALUE_A("0"), .RST_MODE_A("SYNC"),
    .SIM_ASSERT_CHK(0), .USE_MEM_INIT(1), .USE_MEM_INIT_MMI(0),
    .WAKEUP_TIME("disable_sleep"), .WRITE_DATA_WIDTH_A(32),
    .WRITE_MODE_A("read_first")
  ) u_dtcm_bram (
    .clka(clk_i), .ena(req_fire), .wea(data.req_write ? data.req_wstrb : 4'b0),
    .addra(data.req_addr[INDEX_W+1:2]), .dina(data.req_wdata), .douta(bram_rdata),
    .rsta(1'b0), .regcea(1'b1), .sleep(1'b0), .injectsbiterra(1'b0),
    .injectdbiterra(1'b0), .sbiterra(), .dbiterra()
  );
  assign data.rsp_rdata = bram_rdata;
`else
  logic [31:0] storage [0:WORDS-1];
  logic [31:0] rdata_q;
  integer idx;
  string runtime_file;
  initial begin
    for (idx = 0; idx < WORDS; idx = idx + 1) storage[idx] = '0;
    if ($value$plusargs("data_mem=%s", runtime_file))
      $readmemh(runtime_file, storage);
    else if (MEM_FILE != "")
      $readmemh(MEM_FILE, storage);
  end
  assign data.rsp_rdata = rdata_q;
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= 1'b0;
      error_q <= 1'b0;
    end else if (advance) begin
      valid_q <= req_fire;
      error_q <= req_fire &&
                 ((data.req_addr >= BYTES) || (data.req_addr[1:0] != 2'b00));
`ifndef SYNTHESIS
      if (req_fire) begin
        if (data.req_addr < BYTES && data.req_addr[1:0] == 2'b00) begin
          rdata_q <= storage[data.req_addr[INDEX_W+1:2]];
          if (data.req_write) begin
            for (int unsigned lane = 0; lane < 4; lane++)
              if (data.req_wstrb[lane])
                storage[data.req_addr[INDEX_W+1:2]][lane*8 +: 8] <=
                    data.req_wdata[lane*8 +: 8];
          end
        end else begin
          rdata_q <= '0;
        end
      end
`endif
    end
  end
endmodule
