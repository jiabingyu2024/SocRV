// CPU-facing memory contracts for the TCM-only SoC configuration.
// I-port is deliberately independent from HXI so a dual-issue RV32 front-end
// receives two adjacent instructions without a 32-bit bus bottleneck.
interface cpu_instr_if (input logic clk_i);
  logic        req_valid;
  logic        req_ready;
  logic [31:0] req_addr;
  logic        rsp_valid;
  logic        rsp_ready;
  logic [63:0] rsp_data;
  logic        rsp_error;

  modport master (
    output req_valid, req_addr, rsp_ready,
    input  req_ready, rsp_valid, rsp_data, rsp_error
  );
  modport slave (
    input  req_valid, req_addr, rsp_ready,
    output req_ready, rsp_valid, rsp_data, rsp_error
  );
endinterface

interface cpu_data_if (input logic clk_i);
  logic        req_valid;
  logic        req_ready;
  logic [31:0] req_addr;
  logic        req_write;
  logic [31:0] req_wdata;
  logic [3:0]  req_wstrb;
  logic        rsp_valid;
  logic        rsp_ready;
  logic [31:0] rsp_rdata;
  logic        rsp_error;

  modport master (
    output req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    input  req_ready, rsp_valid, rsp_rdata, rsp_error
  );
  modport slave (
    input  req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    output req_ready, rsp_valid, rsp_rdata, rsp_error
  );
endinterface
