// Adapts the biRISC-V fetch-side request contract to the 64-bit I-TCM port.
module biriscv_itcm_adapter (
  input logic clk_i,
  input logic rst_i,
  input logic req_rd_i,
  input logic req_flush_i,
  input logic req_invalidate_i,
  input logic [31:0] req_pc_i,
  output logic req_accept_o,
  output logic req_valid_o,
  output logic req_error_o,
  output logic [63:0] req_inst_o,
  cpu_instr_if.master instr
);
  // The fetch unit already tracks the one outstanding request that the
  // imported biRISC-V core permits.  Do not add a second response register
  // here: doing so turns the synchronous TCM's one-cycle response into a
  // two-cycle response and inserts a bubble between every pair of fetches.
  // `itcm_64_dp` holds a response until rsp_ready and can accept the next
  // request in the same cycle that its previous response is consumed.
  assign instr.req_valid = req_rd_i;
  assign instr.req_addr  = {req_pc_i[31:3], 3'b000};
  assign instr.rsp_ready = 1'b1;
  assign req_accept_o = instr.req_ready;
  assign req_valid_o = instr.rsp_valid && !(req_flush_i || req_invalidate_i);
  assign req_inst_o = instr.rsp_data;
  assign req_error_o = instr.rsp_error;
endmodule
