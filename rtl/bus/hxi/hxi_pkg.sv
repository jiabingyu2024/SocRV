package hxi_pkg;
  typedef enum logic [2:0] {
    HXI_TARGET_CODE    = 3'd0,
    HXI_TARGET_DATA    = 3'd1,
    HXI_TARGET_TIMER   = 3'd2,
    HXI_TARGET_IRQ     = 3'd3,
    HXI_TARGET_APB     = 3'd4,
    HXI_TARGET_DEFAULT = 3'd5
  } hxi_target_t;
endpackage

interface hxi_if #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
) (input logic clk_i);
  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8;

  logic                  req_valid;
  logic                  req_ready;
  logic [ADDR_WIDTH-1:0] req_addr;
  logic                  req_write;
  logic [DATA_WIDTH-1:0] req_wdata;
  logic [STRB_WIDTH-1:0] req_wstrb;
  logic                  rsp_valid;
  logic                  rsp_ready;
  logic [DATA_WIDTH-1:0] rsp_rdata;
  logic                  rsp_err;

  modport master (
    output req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    input  req_ready, rsp_valid, rsp_rdata, rsp_err
  );
  modport slave (
    input  req_valid, req_addr, req_write, req_wdata, req_wstrb, rsp_ready,
    output req_ready, rsp_valid, rsp_rdata, rsp_err
  );
endinterface
