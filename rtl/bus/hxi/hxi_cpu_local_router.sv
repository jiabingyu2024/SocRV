module hxi_cpu_local_router (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave  instr_i,
  hxi_if.slave  data_i,
  hxi_if.master code_o,
  hxi_if.master data_o,
  hxi_if.master peripheral_o
);
  import memory_map_pkg::*;

  typedef enum logic [1:0] {D_ROUTE_CODE, D_ROUTE_DATA, D_ROUTE_PERIPHERAL} d_route_t;
  d_route_t d_route_now;
  d_route_t d_route_q;
  logic d_busy_q;
  logic code_busy_q;
  logic code_owner_data_q;
  logic select_i_code;
  logic select_d_code;
  logic d_req_fire;
  logic d_rsp_fire;
  logic i_req_fire;
  logic i_rsp_fire;

  always_comb begin
    if (in_region(data_i.req_addr, CODE_BASE, CODE_SIZE))
      d_route_now = D_ROUTE_CODE;
    else if (in_region(data_i.req_addr, DATA_BASE, DATA_SIZE))
      d_route_now = D_ROUTE_DATA;
    else
      d_route_now = D_ROUTE_PERIPHERAL;
  end

  assign select_i_code = !code_busy_q && instr_i.req_valid;
  assign select_d_code = !code_busy_q && !select_i_code && !d_busy_q &&
                         data_i.req_valid && (d_route_now == D_ROUTE_CODE);

  always_comb begin
    code_o.req_valid = 1'b0;
    code_o.req_addr  = '0;
    code_o.req_write = 1'b0;
    code_o.req_wdata = '0;
    code_o.req_wstrb = '0;
    code_o.rsp_ready = 1'b0;

    data_o.req_valid = 1'b0;
    data_o.req_addr  = data_i.req_addr;
    data_o.req_write = data_i.req_write;
    data_o.req_wdata = data_i.req_wdata;
    data_o.req_wstrb = data_i.req_wstrb;
    data_o.rsp_ready = 1'b0;

    peripheral_o.req_valid = 1'b0;
    peripheral_o.req_addr  = data_i.req_addr;
    peripheral_o.req_write = data_i.req_write;
    peripheral_o.req_wdata = data_i.req_wdata;
    peripheral_o.req_wstrb = data_i.req_wstrb;
    peripheral_o.rsp_ready = 1'b0;

    instr_i.req_ready = 1'b0;
    instr_i.rsp_valid = 1'b0;
    instr_i.rsp_rdata = '0;
    instr_i.rsp_err   = 1'b0;
    data_i.req_ready  = 1'b0;
    data_i.rsp_valid  = 1'b0;
    data_i.rsp_rdata  = '0;
    data_i.rsp_err    = 1'b0;

    if (select_i_code) begin
      code_o.req_valid = instr_i.req_valid;
      code_o.req_addr  = instr_i.req_addr;
      code_o.req_write = 1'b0;
      instr_i.req_ready = code_o.req_ready;
    end else if (select_d_code) begin
      code_o.req_valid = data_i.req_valid;
      code_o.req_addr  = data_i.req_addr;
      code_o.req_write = data_i.req_write;
      code_o.req_wdata = data_i.req_wdata;
      code_o.req_wstrb = data_i.req_wstrb;
      data_i.req_ready = code_o.req_ready;
    end

    if (!d_busy_q && data_i.req_valid && (d_route_now == D_ROUTE_DATA)) begin
      data_o.req_valid = data_i.req_valid;
      data_i.req_ready = data_o.req_ready;
    end else if (!d_busy_q && data_i.req_valid &&
                 (d_route_now == D_ROUTE_PERIPHERAL)) begin
      peripheral_o.req_valid = data_i.req_valid;
      data_i.req_ready = peripheral_o.req_ready;
    end

    if (code_busy_q && !code_owner_data_q) begin
      instr_i.rsp_valid = code_o.rsp_valid;
      instr_i.rsp_rdata = code_o.rsp_rdata;
      instr_i.rsp_err   = code_o.rsp_err;
      code_o.rsp_ready  = instr_i.rsp_ready;
    end

    if (d_busy_q) begin
      case (d_route_q)
        D_ROUTE_CODE: begin
          data_i.rsp_valid = code_o.rsp_valid;
          data_i.rsp_rdata = code_o.rsp_rdata;
          data_i.rsp_err   = code_o.rsp_err;
          code_o.rsp_ready = data_i.rsp_ready;
        end
        D_ROUTE_DATA: begin
          data_i.rsp_valid = data_o.rsp_valid;
          data_i.rsp_rdata = data_o.rsp_rdata;
          data_i.rsp_err   = data_o.rsp_err;
          data_o.rsp_ready = data_i.rsp_ready;
        end
        D_ROUTE_PERIPHERAL: begin
          data_i.rsp_valid = peripheral_o.rsp_valid;
          data_i.rsp_rdata = peripheral_o.rsp_rdata;
          data_i.rsp_err   = peripheral_o.rsp_err;
          peripheral_o.rsp_ready = data_i.rsp_ready;
        end
        default: begin end
      endcase
    end
  end

  assign i_req_fire = instr_i.req_valid && instr_i.req_ready;
  assign d_req_fire = data_i.req_valid && data_i.req_ready;
  assign i_rsp_fire = instr_i.rsp_valid && instr_i.rsp_ready;
  assign d_rsp_fire = data_i.rsp_valid && data_i.rsp_ready;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      d_route_q          <= D_ROUTE_DATA;
      d_busy_q           <= 1'b0;
      code_busy_q        <= 1'b0;
      code_owner_data_q  <= 1'b0;
    end else begin
      if (i_req_fire) begin
        code_busy_q       <= 1'b1;
        code_owner_data_q <= 1'b0;
      end else if (i_rsp_fire) begin
        code_busy_q       <= 1'b0;
      end

      if (d_req_fire) begin
        d_route_q <= d_route_now;
        d_busy_q  <= 1'b1;
        if (d_route_now == D_ROUTE_CODE) begin
          code_busy_q       <= 1'b1;
          code_owner_data_q <= 1'b1;
        end
      end else if (d_rsp_fire) begin
        d_busy_q <= 1'b0;
        if (d_route_q == D_ROUTE_CODE)
          code_busy_q <= 1'b0;
      end
    end
  end
endmodule
