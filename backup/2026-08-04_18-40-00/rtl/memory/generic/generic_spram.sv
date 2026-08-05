module generic_spram #(
  parameter int unsigned BYTES = 65_536,
  parameter string MEM_FILE = ""
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
  logic [INDEX_WIDTH-1:0] word_index;
`ifndef SYNTHESIS
  string runtime_file;
`endif

  initial begin
    for (int unsigned i = 0; i < WORDS; i++) storage[i] = '0;
`ifndef SYNTHESIS
    if ($value$plusargs("data_mem=%s", runtime_file))
      $readmemh(runtime_file, storage);
    else
`endif
    if (MEM_FILE != "") $readmemh(MEM_FILE, storage);
  end

  assign word_index    = mem.req_addr[INDEX_WIDTH+1:2];
  assign mem.req_ready = !rsp_valid_q;
  assign mem.rsp_valid = rsp_valid_q;
  assign mem.rsp_rdata = rsp_rdata_q;
  assign mem.rsp_err   = rsp_err_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rsp_valid_q <= 1'b0;
      rsp_err_q   <= 1'b0;
    end else begin
      if (rsp_valid_q && mem.rsp_ready) rsp_valid_q <= 1'b0;
      if (mem.req_valid && mem.req_ready) begin
        rsp_valid_q <= 1'b1;
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
