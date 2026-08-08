`timescale 1ns/1ps

// SocRV-facing biRISC-V wrapper.  The imported core remains active-high-reset
// and cache-facing; this wrapper adapts reset, HXI, interrupts and the first
// single-slot commit event without changing soc_core or the HXI crossbar.
module biriscv_cpu_core #(
  parameter logic [31:0] RESET_VECTOR = 32'h0000_0000,
  parameter logic [31:0] CACHE_ADDR_MIN = 32'h1000_0000,
  parameter logic [31:0] CACHE_ADDR_MAX = 32'h1000_FFFF,
  parameter int SUPPORT_DUAL_ISSUE = 0
) (
  input  logic clk_i,
  input  logic rst_ni,
  hxi_if.master instr_hxi,
  hxi_if.master data_hxi,
  input  logic irq_software_i,
  input  logic irq_timer_i,
  input  logic irq_external_i,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic fault_o
);
  logic core_rst;
  assign core_rst = !rst_ni;

  logic ic_req_valid, ic_req_ready;
  logic [31:0] ic_req_addr;
  logic ic_rsp_valid, ic_rsp_ready, ic_rsp_err;
  logic [31:0] ic_rsp_rdata;

  logic dc_req_valid, dc_req_ready, dc_req_write;
  logic [31:0] dc_req_addr, dc_req_wdata;
  logic [3:0] dc_req_wstrb;
  logic dc_rsp_valid, dc_rsp_ready, dc_rsp_err;
  logic [31:0] dc_rsp_rdata;

  logic [31:0] dcache_data_rd;
  logic dcache_accept, dcache_ack, dcache_error;
  logic [10:0] dcache_resp_tag;
  logic [31:0] dcache_addr, dcache_data_wr;
  logic dcache_rd;
  logic [3:0] dcache_wr;
  logic dcache_cacheable;
  logic [10:0] dcache_req_tag;
  logic dcache_invalidate, dcache_writeback, dcache_flush;

  logic icache_valid, icache_accept, icache_error;
  logic [63:0] icache_inst;
  logic icache_rd, icache_flush, icache_invalidate;
  logic [31:0] icache_pc;

  logic core_commit_valid;
  logic [31:0] core_commit_pc, core_commit_opcode, core_commit_result;
  logic [31:0] core_commit_next_pc;
  logic [4:0] core_commit_rd;
  logic [31:0] core_commit_ra, core_commit_rb;
  logic [5:0] core_commit_exception;
  logic core_commit_slot1_valid;
  logic core_interrupt_taken;
  logic [63:0] order_q;
  logic data_fault_q;

  assign instr_hxi.req_valid = ic_req_valid;
  assign instr_hxi.req_addr  = ic_req_addr;
  assign instr_hxi.req_write = 1'b0;
  assign instr_hxi.req_wdata = '0;
  assign instr_hxi.req_wstrb = '0;
  assign instr_hxi.rsp_ready = ic_rsp_ready;
  assign ic_req_ready       = instr_hxi.req_ready;
  assign ic_rsp_valid       = instr_hxi.rsp_valid;
  assign ic_rsp_rdata       = instr_hxi.rsp_rdata;
  assign ic_rsp_err         = instr_hxi.rsp_err;

  assign data_hxi.req_valid = dc_req_valid;
  assign data_hxi.req_addr  = {dc_req_addr[31:2], 2'b00};
  assign data_hxi.req_write = dc_req_write;
  assign data_hxi.req_wdata = dc_req_wdata << {dc_req_addr[1:0], 3'b000};
  assign data_hxi.req_wstrb = (dc_req_wstrb << dc_req_addr[1:0]) & 4'hf;
  assign data_hxi.rsp_ready = dc_rsp_ready;
  assign dc_req_ready       = data_hxi.req_ready;
  assign dc_rsp_valid       = data_hxi.rsp_valid;
  assign dc_rsp_rdata       = data_hxi.rsp_rdata;
  assign dc_rsp_err         = data_hxi.rsp_err;

  biriscv_icache u_icache (
    .clk_i(clk_i), .rst_i(core_rst),
    .req_rd_i(icache_rd), .req_flush_i(icache_flush),
    .req_invalidate_i(icache_invalidate), .req_pc_i(icache_pc),
    .hxi_req_ready_i(ic_req_ready), .hxi_rsp_valid_i(ic_rsp_valid),
    .hxi_rsp_rdata_i(ic_rsp_rdata), .hxi_rsp_err_i(ic_rsp_err),
    .req_accept_o(icache_accept), .req_valid_o(icache_valid),
    .req_error_o(icache_error), .req_inst_o(icache_inst),
    .hxi_req_valid_o(ic_req_valid), .hxi_req_addr_o(ic_req_addr),
    .hxi_rsp_ready_o(ic_rsp_ready)
  );

  biriscv_dcache u_dcache (
    .clk_i(clk_i), .rst_i(core_rst),
    .mem_addr_i(dcache_addr), .mem_data_wr_i(dcache_data_wr),
    .mem_rd_i(dcache_rd), .mem_wr_i(dcache_wr),
    .mem_cacheable_i(dcache_cacheable), .mem_req_tag_i(dcache_req_tag),
    .mem_invalidate_i(dcache_invalidate),
    .mem_writeback_i(dcache_writeback), .mem_flush_i(dcache_flush),
    .hxi_req_ready_i(dc_req_ready), .hxi_rsp_valid_i(dc_rsp_valid),
    .hxi_rsp_rdata_i(dc_rsp_rdata), .hxi_rsp_err_i(dc_rsp_err),
    .mem_data_rd_o(dcache_data_rd), .mem_accept_o(dcache_accept),
    .mem_ack_o(dcache_ack), .mem_error_o(dcache_error),
    .mem_resp_tag_o(dcache_resp_tag), .hxi_req_valid_o(dc_req_valid),
    .hxi_req_addr_o(dc_req_addr), .hxi_req_write_o(dc_req_write),
    .hxi_req_wdata_o(dc_req_wdata), .hxi_req_wstrb_o(dc_req_wstrb),
    .hxi_rsp_ready_o(dc_rsp_ready)
  );

  riscv_core #(
    .MEM_CACHE_ADDR_MIN(CACHE_ADDR_MIN),
    .MEM_CACHE_ADDR_MAX(CACHE_ADDR_MAX),
    .SUPPORT_BRANCH_PREDICTION(1),
    .SUPPORT_MULDIV(1),
    .SUPPORT_SUPER(0),
    .SUPPORT_MMU(0),
    .SUPPORT_DUAL_ISSUE(SUPPORT_DUAL_ISSUE),
    .SUPPORT_LOAD_BYPASS(1),
    .SUPPORT_MUL_BYPASS(1),
    .SUPPORT_REGFILE_XILINX(0),
    .EXTRA_DECODE_STAGE(0)
  ) u_core (
    .clk_i(clk_i), .rst_i(core_rst),
    .mem_d_data_rd_i(dcache_data_rd), .mem_d_accept_i(dcache_accept),
    .mem_d_ack_i(dcache_ack), .mem_d_error_i(dcache_error),
    .mem_d_resp_tag_i(dcache_resp_tag),
    .mem_i_accept_i(icache_accept), .mem_i_valid_i(icache_valid),
    .mem_i_error_i(icache_error), .mem_i_inst_i(icache_inst),
    .irq_software_i(irq_software_i), .irq_timer_i(irq_timer_i),
    .irq_external_i(irq_external_i),
    .reset_vector_i(RESET_VECTOR), .cpu_id_i(32'd0),
    .mem_d_addr_o(dcache_addr), .mem_d_data_wr_o(dcache_data_wr),
    .mem_d_rd_o(dcache_rd), .mem_d_wr_o(dcache_wr),
    .mem_d_cacheable_o(dcache_cacheable),
    .mem_d_req_tag_o(dcache_req_tag),
    .mem_d_invalidate_o(dcache_invalidate),
    .mem_d_writeback_o(dcache_writeback), .mem_d_flush_o(dcache_flush),
    .mem_i_rd_o(icache_rd), .mem_i_flush_o(icache_flush),
    .mem_i_invalidate_o(icache_invalidate), .mem_i_pc_o(icache_pc),
    .commit_valid_o(core_commit_valid), .commit_pc_o(core_commit_pc),
    .commit_next_pc_o(core_commit_next_pc),
    .commit_opcode_o(core_commit_opcode), .commit_rd_o(core_commit_rd),
    .commit_result_o(core_commit_result),
    .commit_ra_value_o(core_commit_ra), .commit_rb_value_o(core_commit_rb),
    .commit_exception_o(core_commit_exception),
    .commit_slot1_valid_o(core_commit_slot1_valid),
    .interrupt_taken_o(core_interrupt_taken)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      order_q <= '0;
      data_fault_q <= 1'b0;
    end else begin
      if (core_commit_valid)
        order_q <= order_q + 64'd1;
      if (dc_rsp_valid && dc_rsp_err)
        data_fault_q <= 1'b1;
    end
  end

  always_comb begin
    commit_o = '0;
    commit_o.valid       = core_commit_valid;
    commit_o.retired     = core_commit_valid && (core_commit_exception == 0);
    commit_o.order       = order_q;
    commit_o.pc          = core_commit_pc;
    commit_o.pc_rdata    = core_commit_pc;
    commit_o.pc_wdata    = core_commit_next_pc;
    commit_o.instruction = core_commit_opcode;
    commit_o.rs1_addr    = core_commit_opcode[19:15];
    commit_o.rs1_rdata   = core_commit_ra;
    commit_o.rs2_addr    = core_commit_opcode[24:20];
    commit_o.rs2_rdata   = core_commit_rb;
    commit_o.rd_wen      = (core_commit_rd != 0) && commit_o.retired;
    commit_o.rd_addr     = core_commit_rd;
    commit_o.rd_wdata    = core_commit_result;
    commit_o.sync_trap   = (core_commit_exception != 0);
    // biRISC-V encodes exception class in bits [5:4] and the RISC-V cause
    // subtype in [3:0].  CSR logic uses the same subtype for synchronous
    // traps; interrupt causes are supplied as architectural mcause values by
    // the CSR file and are not yet exported from this wrapper.
    commit_o.cause       = {28'b0, core_commit_exception[3:0]};
    commit_o.tval        = 32'b0;
    commit_o.mode        = 2'b11;
    commit_o.csr_mcycle  = '0;
    commit_o.csr_minstret = '0;
    commit_o.irq_valid   = core_interrupt_taken;
    commit_o.irq_next_order = order_q;
  end

  assign fault_o = data_fault_q | core_commit_slot1_valid;
endmodule
