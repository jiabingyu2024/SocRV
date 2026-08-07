module generic_rom #(
  parameter int unsigned BYTES = 65_536,
  parameter string MEM_FILE = "",
  parameter int unsigned RESPONSE_LATENCY =
      soc_config_pkg::CODE_MEM_RESPONSE_LATENCY
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
`ifndef SYNTHESIS
  string runtime_file;
`endif

  initial begin
    if (RESPONSE_LATENCY < 1)
      $fatal(1, "generic_rom RESPONSE_LATENCY must be at least 1");
    for (int unsigned i = 0; i < WORDS; i++) storage[i] = '0;
`ifndef SYNTHESIS
    if ($value$plusargs("code_mem=%s", runtime_file))
      $readmemh(runtime_file, storage);
    else
`endif
    if (MEM_FILE != "") $readmemh(MEM_FILE, storage);
  end

  // The complete fixed-latency pipe advances together.  With an accepting
  // response sink this permits one synchronous BRAM address every cycle; if
  // the sink backpressures, every stage holds and no response can be lost.
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
        pipe_err_q[0] <= mem.req_write || (mem.req_addr >= BYTES) ||
                         (mem.req_addr[1:0] != 2'b00);
      end else begin
        pipe_err_q[0] <= 1'b0;
      end
    end
  end

  // Keep the inferred ROM read and data-pipe flops out of the asynchronous
  // reset process.  Their validity is entirely governed by pipe_valid_q.
  always_ff @(posedge clk_i) begin
    if (pipe_advance) begin
      for (int unsigned stage = PIPE_STAGES - 1; stage > 0; stage--)
        pipe_rdata_q[stage] <= pipe_rdata_q[stage-1];
      if (req_fire) begin
        if (!mem.req_write && mem.req_addr < BYTES &&
            mem.req_addr[1:0] == 2'b00)
          pipe_rdata_q[0] <= storage[mem.req_addr[INDEX_WIDTH+1:2]];
        else
          pipe_rdata_q[0] <= '0;
      end
    end
  end

`ifndef SYNTHESIS
  initial assert (RESPONSE_LATENCY >= 1);
`endif
endmodule
