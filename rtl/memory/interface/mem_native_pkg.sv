package mem_native_pkg;
  typedef struct packed {
    logic [31:0] addr;
    logic        write;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
  } mem_native_req_t;
endpackage

interface mem_native_if (input logic clk_i);
  logic        req_valid;
  logic        req_ready;
  logic [31:0] req_addr;
  logic        req_write;
  logic [31:0] req_wdata;
  logic [3:0]  req_wstrb;
  logic        rsp_valid;
  logic        rsp_ready;
  logic [31:0] rsp_rdata;
  logic        rsp_err;

  modport master (
    output req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    input  req_ready, rsp_valid, rsp_rdata, rsp_err
  );
  modport slave (
    input  req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    output req_ready, rsp_valid, rsp_rdata, rsp_err
  );
endinterface
