module hxi_data_mem_slave #(
  parameter logic [31:0] BASE_ADDR = memory_map_pkg::DATA_BASE
) (
  hxi_if.slave hxi,
  mem_native_if.master mem
);
  assign mem.req_valid = hxi.req_valid;
  assign mem.req_addr  = hxi.req_addr - BASE_ADDR;
  assign mem.req_write = hxi.req_write;
  assign mem.req_wdata = hxi.req_wdata;
  assign mem.req_wstrb = hxi.req_wstrb;
  assign hxi.req_ready = mem.req_ready;
  assign hxi.rsp_valid = mem.rsp_valid;
  assign hxi.rsp_rdata = mem.rsp_rdata;
  assign hxi.rsp_err   = mem.rsp_err;
  assign mem.rsp_ready = hxi.rsp_ready;
endmodule
