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
  localparam int unsigned PIPE_STAGES =
      (RESPONSE_LATENCY < 1) ? 1 : RESPONSE_LATENCY;
  logic [PIPE_STAGES-1:0] pipe_valid_q;
  logic [31:0] pipe_rdata_q [0:PIPE_STAGES-1];
  logic [PIPE_STAGES-1:0] pipe_err_q;
  logic pipe_advance;
  logic req_fire;
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
  assign pipe_advance = !pipe_valid_q[PIPE_STAGES-1] || mem.rsp_ready;
  assign mem.req_ready = pipe_advance;
  assign req_fire = mem.req_valid && mem.req_ready;
  assign mem.rsp_valid = pipe_valid_q[PIPE_STAGES-1];
  assign mem.rsp_rdata = pipe_rdata_q[PIPE_STAGES-1];
  assign mem.rsp_err   = pipe_err_q[PIPE_STAGES-1];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pipe_valid_q <= '0;
      pipe_err_q <= '0;
    end else if (pipe_advance) begin
      for (int unsigned stage = PIPE_STAGES - 1; stage > 0; stage--) begin
        pipe_valid_q[stage] <= pipe_valid_q[stage-1];
        pipe_err_q[stage] <= pipe_err_q[stage-1];
      end
      pipe_valid_q[0] <= req_fire;
      if (req_fire) begin
        pipe_err_q[0] <= (mem.req_addr >= BYTES) ||
                         (mem.req_addr[1:0] != 2'b00);
      end else begin
        pipe_err_q[0] <= 1'b0;
      end
    end
  end


  // Vivado's BRAM inference requires the storage access process to have no
  // asynchronous reset.  pipe_valid_q ensures uninitialized data-pipe flops
  // are never observed as responses.
  always_ff @(posedge clk_i) begin
    if (pipe_advance) begin
      for (int unsigned stage = PIPE_STAGES - 1; stage > 0; stage--)
        pipe_rdata_q[stage] <= pipe_rdata_q[stage-1];
      if (req_fire) begin
        pipe_rdata_q[0] <= (mem.req_addr < BYTES &&
                            mem.req_addr[1:0] == 2'b00) ?
                           storage[word_index] : '0;
        if (mem.req_write && mem.req_addr < BYTES &&
            mem.req_addr[1:0] == 2'b00) begin
          for (int unsigned lane = 0; lane < 4; lane++) begin
            if (mem.req_wstrb[lane])
              storage[word_index][lane*8 +: 8] <=
                  mem.req_wdata[lane*8 +: 8];
          end
        end
      end
    end
  end

`ifndef SYNTHESIS
  initial assert (RESPONSE_LATENCY >= 1);
`endif
endmodule
