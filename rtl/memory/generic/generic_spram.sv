module generic_spram #(
  parameter int unsigned BYTES = 65_536,
  parameter string MEM_FILE = "",
  parameter int unsigned RESPONSE_LATENCY =
      soc_config_pkg::DATA_MEM_RESPONSE_LATENCY
) (
  input logic clk_i,
  input logic rst_ni,
  mem_native_if.slave mem
);
  localparam int unsigned WORDS = BYTES / 4;
  localparam int unsigned INDEX_WIDTH = $clog2(WORDS);
  logic [31:0] storage [0:WORDS-1];
  logic rsp_valid_q;
  logic [31:0] rsp_rdata_q;
  logic rsp_err_q;
  localparam int unsigned LATENCY_COUNT_WIDTH =
      (RESPONSE_LATENCY <= 1) ? 1 : $clog2(RESPONSE_LATENCY);
  logic busy_q;
  logic [LATENCY_COUNT_WIDTH-1:0] latency_count_q;
  logic [INDEX_WIDTH-1:0] word_index;
`ifndef SYNTHESIS
  string runtime_file;
`endif

  initial begin
    if (RESPONSE_LATENCY < 1)
      $fatal(1, "generic_spram RESPONSE_LATENCY must be at least 1");
    for (int unsigned i = 0; i < WORDS; i++) storage[i] = '0;
`ifndef SYNTHESIS
    if ($value$plusargs("data_mem=%s", runtime_file))
      $readmemh(runtime_file, storage);
    else
`endif
    if (MEM_FILE != "") $readmemh(MEM_FILE, storage);
  end

  assign word_index    = mem.req_addr[INDEX_WIDTH+1:2];
  assign mem.req_ready = !busy_q && !rsp_valid_q;
  assign mem.rsp_valid = rsp_valid_q;
  assign mem.rsp_rdata = rsp_rdata_q;
  assign mem.rsp_err   = rsp_err_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rsp_valid_q <= 1'b0;
      rsp_err_q   <= 1'b0;
      busy_q      <= 1'b0;
      latency_count_q <= '0;
    end else begin
      if (rsp_valid_q && mem.rsp_ready) rsp_valid_q <= 1'b0;
      if (busy_q) begin
        if (latency_count_q == 1) begin
          busy_q      <= 1'b0;
          rsp_valid_q <= 1'b1;
        end else begin
          latency_count_q <= latency_count_q - 1'b1;
        end
      end
      if (mem.req_valid && mem.req_ready) begin
        if (RESPONSE_LATENCY == 1) begin
          rsp_valid_q <= 1'b1;
        end else begin
          busy_q <= 1'b1;
          latency_count_q <=
              LATENCY_COUNT_WIDTH'(RESPONSE_LATENCY - 1);
        end
        rsp_err_q   <= (mem.req_addr >= BYTES) || (mem.req_addr[1:0] != 2'b00);
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (mem.req_valid && mem.req_ready) begin
      rsp_rdata_q <= (mem.req_addr < BYTES && mem.req_addr[1:0] == 2'b00)
                   ? storage[word_index] : '0;
      if (mem.req_write && mem.req_addr < BYTES && mem.req_addr[1:0] == 2'b00) begin
        for (int i = 0; i < 4; i++) begin
          if (mem.req_wstrb[i]) storage[word_index][i*8 +: 8] <= mem.req_wdata[i*8 +: 8];
        end
      end
    end
  end
endmodule
