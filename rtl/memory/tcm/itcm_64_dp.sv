// 64 KiB I-TCM implemented as two 32-bit banks. Port A of both banks forms
// the 64-bit instruction fetch; port B supplies concurrent read-only .rodata.
// FPGA builds use explicit XPM true-dual-port BRAMs. Generic simulation keeps
// a portable array model and consumes the original 32-bit code.mem image.
module itcm_64_dp #(
  parameter int unsigned BYTES = memory_map_pkg::CODE_SIZE,
  parameter string MEM_FILE = "",
  parameter string MEM_FILE_LO = "",
  parameter string MEM_FILE_HI = ""
) (
  input logic clk_i,
  input logic rst_ni,
  cpu_instr_if.slave instr,
  cpu_data_if.slave data
);
  localparam int unsigned WORDS = BYTES / 4;
  localparam int unsigned PAIRS = BYTES / 8;
  localparam int unsigned PAIR_INDEX_W = $clog2(PAIRS);

  logic i_valid_q, i_error_q;
  logic d_valid_q, d_error_q;
  // Capture the D-side bank selection with the request.  The BRAM output is
  // synchronous; using data.req_addr directly while a response is stalled
  // would violate the interface guarantee that rsp_rdata remains stable.
  logic d_bank_q;
  logic i_advance, d_advance, i_fire, d_fire;
  logic [31:0] i_lo_rdata, i_hi_rdata, d_lo_rdata, d_hi_rdata;

  assign i_advance = !i_valid_q || instr.rsp_ready;
  assign instr.req_ready = i_advance;
  assign i_fire = instr.req_valid && instr.req_ready;
  assign instr.rsp_valid = i_valid_q;
  assign instr.rsp_error = i_error_q;

  assign d_advance = !d_valid_q || data.rsp_ready;
  assign data.req_ready = d_advance;
  assign d_fire = data.req_valid && data.req_ready;
  assign data.rsp_valid = d_valid_q;
  assign data.rsp_error = d_error_q;

`ifdef SYNTHESIS
  // The low and high files contain one word per 64-bit fetch pair. Port B is
  // read-only by contract; keeping it enabled for both banks makes the mux
  // after the registered BRAM output trivial and preserves a true dual-port
  // implementation for the two physical banks.
  xpm_memory_tdpram #(
    .ADDR_WIDTH_A(PAIR_INDEX_W), .ADDR_WIDTH_B(PAIR_INDEX_W),
    .AUTO_SLEEP_TIME(0), .BYTE_WRITE_WIDTH_A(8), .BYTE_WRITE_WIDTH_B(8),
    .CLOCKING_MODE("common_clock"), .MEMORY_INIT_FILE(MEM_FILE_LO),
    .MEMORY_INIT_PARAM(""), .MEMORY_OPTIMIZATION("true"),
    .MEMORY_PRIMITIVE("block"), .MEMORY_SIZE(PAIRS * 32),
    .MESSAGE_CONTROL(0), .READ_DATA_WIDTH_A(32), .READ_DATA_WIDTH_B(32),
    .READ_LATENCY_A(1), .READ_LATENCY_B(1), .READ_RESET_VALUE_A("0"),
    .READ_RESET_VALUE_B("0"), .RST_MODE_A("SYNC"), .RST_MODE_B("SYNC"),
    .SIM_ASSERT_CHK(0), .USE_EMBEDDED_CONSTRAINT(0), .USE_MEM_INIT(1),
    .USE_MEM_INIT_MMI(0), .WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(32), .WRITE_DATA_WIDTH_B(32),
    .WRITE_MODE_A("read_first"), .WRITE_MODE_B("read_first")
  ) u_bank_lo (
    .clka(clk_i), .ena(i_fire), .wea(4'b0),
    .addra(instr.req_addr[PAIR_INDEX_W+2:3]), .dina(32'b0), .douta(i_lo_rdata),
    .rsta(1'b0), .regcea(1'b1), .clkb(clk_i), .enb(d_fire), .web(4'b0),
    .addrb(data.req_addr[PAIR_INDEX_W+2:3]), .dinb(32'b0), .doutb(d_lo_rdata),
    .rstb(1'b0), .regceb(1'b1), .sleep(1'b0), .injectsbiterra(1'b0),
    .injectdbiterra(1'b0), .injectsbiterrb(1'b0), .injectdbiterrb(1'b0),
    .sbiterra(), .dbiterra(), .sbiterrb(), .dbiterrb()
  );
  xpm_memory_tdpram #(
    .ADDR_WIDTH_A(PAIR_INDEX_W), .ADDR_WIDTH_B(PAIR_INDEX_W),
    .AUTO_SLEEP_TIME(0), .BYTE_WRITE_WIDTH_A(8), .BYTE_WRITE_WIDTH_B(8),
    .CLOCKING_MODE("common_clock"), .MEMORY_INIT_FILE(MEM_FILE_HI),
    .MEMORY_INIT_PARAM(""), .MEMORY_OPTIMIZATION("true"),
    .MEMORY_PRIMITIVE("block"), .MEMORY_SIZE(PAIRS * 32),
    .MESSAGE_CONTROL(0), .READ_DATA_WIDTH_A(32), .READ_DATA_WIDTH_B(32),
    .READ_LATENCY_A(1), .READ_LATENCY_B(1), .READ_RESET_VALUE_A("0"),
    .READ_RESET_VALUE_B("0"), .RST_MODE_A("SYNC"), .RST_MODE_B("SYNC"),
    .SIM_ASSERT_CHK(0), .USE_EMBEDDED_CONSTRAINT(0), .USE_MEM_INIT(1),
    .USE_MEM_INIT_MMI(0), .WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(32), .WRITE_DATA_WIDTH_B(32),
    .WRITE_MODE_A("read_first"), .WRITE_MODE_B("read_first")
  ) u_bank_hi (
    .clka(clk_i), .ena(i_fire), .wea(4'b0),
    .addra(instr.req_addr[PAIR_INDEX_W+2:3]), .dina(32'b0), .douta(i_hi_rdata),
    .rsta(1'b0), .regcea(1'b1), .clkb(clk_i), .enb(d_fire), .web(4'b0),
    .addrb(data.req_addr[PAIR_INDEX_W+2:3]), .dinb(32'b0), .doutb(d_hi_rdata),
    .rstb(1'b0), .regceb(1'b1), .sleep(1'b0), .injectsbiterra(1'b0),
    .injectdbiterra(1'b0), .injectsbiterrb(1'b0), .injectdbiterrb(1'b0),
    .sbiterra(), .dbiterra(), .sbiterrb(), .dbiterrb()
  );
  assign instr.rsp_data = {i_hi_rdata, i_lo_rdata};
  assign data.rsp_rdata = d_bank_q ? d_hi_rdata : d_lo_rdata;
`else
  logic [31:0] bank_lo [0:PAIRS-1];
  logic [31:0] bank_hi [0:PAIRS-1];
  logic [31:0] image_words [0:WORDS-1];
  logic [63:0] i_data_q;
  logic [31:0] d_data_q;
  string runtime_file;
  integer idx;

  initial begin
    for (idx = 0; idx < PAIRS; idx = idx + 1) begin
      bank_lo[idx] = '0;
      bank_hi[idx] = '0;
    end
    for (idx = 0; idx < WORDS; idx = idx + 1) image_words[idx] = '0;
    if ($value$plusargs("code_mem=%s", runtime_file))
      $readmemh(runtime_file, image_words);
    else if (MEM_FILE != "")
      $readmemh(MEM_FILE, image_words);
    for (idx = 0; idx < PAIRS; idx = idx + 1) begin
      bank_lo[idx] = image_words[idx * 2];
      bank_hi[idx] = image_words[idx * 2 + 1];
    end
  end
  assign instr.rsp_data = i_data_q;
  assign data.rsp_rdata = d_data_q;
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      i_valid_q <= 1'b0;
      i_error_q <= 1'b0;
      d_valid_q <= 1'b0;
      d_error_q <= 1'b0;
      d_bank_q <= 1'b0;
    end else begin
      if (i_advance) begin
        i_valid_q <= i_fire;
        i_error_q <= i_fire &&
                     ((instr.req_addr >= BYTES) || (instr.req_addr[2:0] != 3'b000));
`ifndef SYNTHESIS
        if (i_fire) begin
          if ((instr.req_addr < BYTES) && (instr.req_addr[2:0] == 3'b000))
            i_data_q <= {bank_hi[instr.req_addr[PAIR_INDEX_W+2:3]],
                         bank_lo[instr.req_addr[PAIR_INDEX_W+2:3]]};
          else
            i_data_q <= '0;
        end
`endif
      end
      if (d_advance) begin
        d_valid_q <= d_fire;
        if (d_fire)
          d_bank_q <= data.req_addr[2];
        d_error_q <= d_fire &&
                     (data.req_write || (data.req_addr >= BYTES) ||
                      (data.req_addr[1:0] != 2'b00));
`ifndef SYNTHESIS
        if (d_fire) begin
          if (!data.req_write && data.req_addr < BYTES && data.req_addr[1:0] == 2'b00)
            d_data_q <= data.req_addr[2] ?
                        bank_hi[data.req_addr[PAIR_INDEX_W+2:3]] :
                        bank_lo[data.req_addr[PAIR_INDEX_W+2:3]];
          else
            d_data_q <= '0;
        end
`endif
      end
    end
  end
endmodule
