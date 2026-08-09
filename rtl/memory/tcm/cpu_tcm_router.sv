// Registered MMIO router with a zero-overhead local TCM request path.  Local
// ready may depend on the BRAM adapter, but no peripheral-domain signal is
// allowed to feed the local fast path.
module cpu_tcm_router (
  input logic clk_i,
  input logic rst_ni,
  cpu_data_if.slave cpu,
  cpu_data_if.master code,
  cpu_data_if.master data,
  hxi_if.master mmio
);
  import memory_map_pkg::*;
  typedef enum logic [2:0] {IDLE, ISSUE_MMIO, WAIT_CODE, WAIT_DATA,
                            WAIT_MMIO, ERROR} state_t;
  state_t state_q;
  logic [31:0] addr_q, wdata_q;
  logic [3:0] wstrb_q;
  logic write_q;
  logic is_code_c, is_data_c, is_mmio_c;

  always_comb begin
    is_code_c = in_region(cpu.req_addr, CODE_BASE, CODE_SIZE);
    is_data_c = in_region(cpu.req_addr, DATA_BASE, DATA_SIZE);
    is_mmio_c = in_region(cpu.req_addr, TIMER_BASE, TIMER_SIZE) ||
                in_region(cpu.req_addr, IRQ_CTRL_BASE, IRQ_CTRL_SIZE) ||
                in_region(cpu.req_addr, APB_BASE, APB_SIZE);

    code.req_valid = 1'b0; code.req_addr = addr_q - CODE_BASE;
    code.req_write = write_q; code.req_wdata = wdata_q; code.req_wstrb = wstrb_q;
    code.rsp_ready = 1'b0;
    data.req_valid = 1'b0; data.req_addr = addr_q - DATA_BASE;
    data.req_write = write_q; data.req_wdata = wdata_q; data.req_wstrb = wstrb_q;
    data.rsp_ready = 1'b0;
    mmio.req_valid = 1'b0; mmio.req_addr = addr_q; mmio.req_write = write_q;
    mmio.req_wdata = wdata_q; mmio.req_wstrb = wstrb_q; mmio.rsp_ready = 1'b0;

    cpu.req_ready = 1'b0;
    cpu.rsp_valid = 1'b0; cpu.rsp_rdata = '0; cpu.rsp_error = 1'b0;

    if (state_q == IDLE) begin
      // Direct local path: request and BRAM handshake occur in the same cycle.
      if (is_code_c) begin
        code.req_valid = cpu.req_valid;
        code.req_addr = cpu.req_addr - CODE_BASE;
        code.req_write = cpu.req_write;
        code.req_wdata = cpu.req_wdata;
        code.req_wstrb = cpu.req_wstrb;
        cpu.req_ready = code.req_ready;
      end else if (is_data_c) begin
        data.req_valid = cpu.req_valid;
        data.req_addr = cpu.req_addr - DATA_BASE;
        data.req_write = cpu.req_write;
        data.req_wdata = cpu.req_wdata;
        data.req_wstrb = cpu.req_wstrb;
        cpu.req_ready = data.req_ready;
      end else if (is_mmio_c) begin
        // MMIO is captured before entering HXI, so periph ready never reaches
        // the CPU combinationally.
        cpu.req_ready = 1'b1;
      end else begin
        cpu.req_ready = 1'b1;
      end
    end

    if (state_q == ISSUE_MMIO) mmio.req_valid = 1'b1;
    if (state_q == WAIT_CODE) begin
      cpu.rsp_valid = code.rsp_valid; cpu.rsp_rdata = code.rsp_rdata;
      cpu.rsp_error = code.rsp_error; code.rsp_ready = cpu.rsp_ready;
    end else if (state_q == WAIT_DATA) begin
      cpu.rsp_valid = data.rsp_valid; cpu.rsp_rdata = data.rsp_rdata;
      cpu.rsp_error = data.rsp_error; data.rsp_ready = cpu.rsp_ready;
    end else if (state_q == WAIT_MMIO) begin
      cpu.rsp_valid = mmio.rsp_valid; cpu.rsp_rdata = mmio.rsp_rdata;
      cpu.rsp_error = mmio.rsp_err; mmio.rsp_ready = cpu.rsp_ready;
    end else if (state_q == ERROR) begin
      cpu.rsp_valid = 1'b1; cpu.rsp_error = 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      addr_q <= '0; wdata_q <= '0; wstrb_q <= '0; write_q <= 1'b0;
    end else begin
      case (state_q)
        IDLE: if (cpu.req_valid && cpu.req_ready) begin
          if (is_code_c) state_q <= WAIT_CODE;
          else if (is_data_c) state_q <= WAIT_DATA;
          else begin
            addr_q <= cpu.req_addr; write_q <= cpu.req_write;
            wdata_q <= cpu.req_wdata; wstrb_q <= cpu.req_wstrb;
            if (is_mmio_c) state_q <= ISSUE_MMIO;
            else state_q <= ERROR;
          end
        end
        ISSUE_MMIO: if (mmio.req_ready) state_q <= WAIT_MMIO;
        WAIT_CODE: if (code.rsp_valid && cpu.rsp_ready) state_q <= IDLE;
        WAIT_DATA: if (data.rsp_valid && cpu.rsp_ready) state_q <= IDLE;
        WAIT_MMIO: if (mmio.rsp_valid && cpu.rsp_ready) state_q <= IDLE;
        ERROR: if (cpu.rsp_ready) state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
