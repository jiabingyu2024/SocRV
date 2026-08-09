// Direct, uncached D-port adapter.  The biRISC-V core's sub-word request
// arrives with an offset address and unshifted byte mask; this adapter presents
// an aligned, lane-aligned CPU data request to the TCM router.
module biriscv_dtcm_adapter (
  input logic clk_i,
  input logic rst_i,
  input logic [31:0] mem_addr_i,
  input logic [31:0] mem_data_wr_i,
  input logic mem_rd_i,
  input logic [3:0] mem_wr_i,
  input logic [10:0] mem_req_tag_i,
  output logic [31:0] mem_data_rd_o,
  output logic mem_accept_o,
  output logic mem_ack_o,
  output logic mem_error_o,
  output logic [10:0] mem_resp_tag_o,
  cpu_data_if.master data
);
  logic busy_q;
  logic [10:0] tag_q;
  logic request;
  logic response_fire;

  assign request = mem_rd_i || (mem_wr_i != 4'b0);
  assign mem_accept_o = !busy_q;
  assign data.req_valid = request && !busy_q;
  assign data.req_addr = {mem_addr_i[31:2], 2'b00};
  assign data.req_write = (mem_wr_i != 4'b0);
  assign data.req_wdata = mem_data_wr_i << {mem_addr_i[1:0], 3'b000};
  assign data.req_wstrb = (mem_wr_i << mem_addr_i[1:0]) & 4'hf;
  assign data.rsp_ready = 1'b1;
  assign response_fire = data.rsp_valid && data.rsp_ready;

  assign mem_ack_o = response_fire;
  assign mem_data_rd_o = data.rsp_rdata;
  assign mem_error_o = response_fire && data.rsp_error;
  assign mem_resp_tag_o = tag_q;

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      busy_q <= 1'b0;
      tag_q <= '0;
    end else begin
      if (data.req_valid && data.req_ready) begin
        busy_q <= 1'b1;
        tag_q <= mem_req_tag_i;
      end
      if (response_fire) busy_q <= 1'b0;
    end
  end
endmodule
