module cpu_subsystem (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.master instr_hxi,
  hxi_if.master data_hxi,
  input logic irq_software_i,
  input logic irq_timer_i,
  input logic irq_external_i,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic fault_o
);
  logic [31:0] irom_addr;
  logic [31:0] irom_data;
  logic irom_enable;
  logic irom_valid;
  logic irom_ready;

  logic dmem_req_valid;
  logic dmem_req_ready;
  logic dmem_req_write;
  logic [31:0] dmem_req_addr;
  logic [31:0] dmem_req_wdata;
  logic [3:0] dmem_req_wstrb;
  logic dmem_req_uncached;
  logic dmem_rsp_valid;
  logic [31:0] dmem_rsp_rdata;
  logic instruction_fault;
  logic data_fault;

  myCPU u_core (
    .cpu_rst(~rst_ni),
    .cpu_clk(clk_i),
    .irq_software(irq_software_i),
    .irq_timer(irq_timer_i),
    .irq_external(irq_external_i),
    .irom_addr,
    .irom_data,
    .irom_valid,
    .irom_ena(irom_enable),
    .irom_ready,
    .dmem_req_valid,
    .dmem_req_ready,
    .dmem_req_write,
    .dmem_req_addr,
    .dmem_req_wdata,
    .dmem_req_wstrb,
    .dmem_req_uncached,
    .dmem_resp_valid(dmem_rsp_valid),
    .dmem_resp_rdata(dmem_rsp_rdata),
    .commit_o
  );

  hxi_instruction_adapter u_instruction_adapter (
    .clk_i,
    .rst_ni,
    .core_req_valid_i(irom_enable),
    .core_req_addr_i(irom_addr),
    .core_rsp_valid_o(irom_valid),
    .core_rsp_ready_i(irom_ready),
    .core_rsp_data_o(irom_data),
    .hxi(instr_hxi),
    .fault_o(instruction_fault)
  );

  hxi_data_adapter u_data_adapter (
    .clk_i,
    .rst_ni,
    .core_req_valid_i(dmem_req_valid),
    .core_req_ready_o(dmem_req_ready),
    .core_req_write_i(dmem_req_write),
    .core_req_addr_i(dmem_req_addr),
    .core_req_wdata_i(dmem_req_wdata),
    .core_req_wstrb_i(dmem_req_wstrb),
    .core_req_uncached_i(dmem_req_uncached),
    .core_rsp_valid_o(dmem_rsp_valid),
    .core_rsp_rdata_o(dmem_rsp_rdata),
    .hxi(data_hxi),
    .fault_o(data_fault)
  );

  assign fault_o = instruction_fault | data_fault;
endmodule
