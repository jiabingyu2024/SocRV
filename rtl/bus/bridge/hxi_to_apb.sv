module hxi_to_apb (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.slave hxi,
  output logic [31:0] paddr_o,
  output logic        psel_o,
  output logic        penable_o,
  output logic        pwrite_o,
  output logic [31:0] pwdata_o,
  output logic [3:0]  pstrb_o,
  input  logic [31:0] prdata_i,
  input  logic        pready_i,
  input  logic        pslverr_i
);
  typedef enum logic [1:0] {IDLE, SETUP, ACCESS, RESPONSE} state_t;
  state_t state_q;
  logic [31:0] addr_q;
  logic write_q;
  logic [31:0] wdata_q;
  logic [3:0] wstrb_q;
  logic [31:0] rdata_q;
  logic err_q;

  assign hxi.req_ready = (state_q == IDLE);
  assign hxi.rsp_valid = (state_q == RESPONSE);
  assign hxi.rsp_rdata = rdata_q;
  assign hxi.rsp_err   = err_q;
  assign paddr_o       = addr_q;
  assign pwrite_o      = write_q;
  assign pwdata_o      = wdata_q;
  assign pstrb_o       = wstrb_q;
  assign psel_o        = (state_q == SETUP) || (state_q == ACCESS);
  assign penable_o     = (state_q == ACCESS);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      addr_q  <= '0;
      write_q <= 1'b0;
      wdata_q <= '0;
      wstrb_q <= '0;
      rdata_q <= '0;
      err_q   <= 1'b0;
    end else begin
      case (state_q)
        IDLE: if (hxi.req_valid) begin
          addr_q  <= hxi.req_addr;
          write_q <= hxi.req_write;
          wdata_q <= hxi.req_wdata;
          wstrb_q <= hxi.req_wstrb;
          state_q <= SETUP;
        end
        SETUP: state_q <= ACCESS;
        ACCESS: if (pready_i) begin
          rdata_q <= prdata_i;
          err_q   <= pslverr_i;
          state_q <= RESPONSE;
        end
        RESPONSE: if (hxi.rsp_ready) state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule
