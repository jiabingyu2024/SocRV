//-----------------------------------------------------------------
// biRISC-V physical-memory port to SocRV HXI bridge.
// Read bursts are split into ordered 32-bit HXI transactions.  Write data is
// already presented one word at a time by dcache_core and is accepted only
// when the preceding HXI transaction has completed.
//-----------------------------------------------------------------
module dcache_hxi
(
     input           clk_i
    ,input           rst_i
    ,input  [  3:0]  inport_wr_i
    ,input           inport_rd_i
    ,input  [  7:0]  inport_len_i
    ,input  [ 31:0]  inport_addr_i
    ,input  [ 31:0]  inport_write_data_i

    ,output          inport_accept_o
    ,output          inport_ack_o
    ,output          inport_error_o
    ,output [ 31:0]  inport_read_data_o

    ,output          hxi_req_valid_o
    ,input           hxi_req_ready_i
    ,output [ 31:0]  hxi_req_addr_o
    ,output          hxi_req_write_o
    ,output [ 31:0]  hxi_req_wdata_o
    ,output [  3:0]  hxi_req_wstrb_o
    ,input           hxi_rsp_valid_i
    ,output          hxi_rsp_ready_o
    ,input  [ 31:0]  hxi_rsp_rdata_i
    ,input           hxi_rsp_err_i
);

localparam STATE_IDLE = 2'd0;
localparam STATE_REQ  = 2'd1;
localparam STATE_RSP  = 2'd2;

reg [1:0]  state_q;
reg        write_q;
reg [31:0] addr_q;
reg [31:0] wdata_q;
reg [3:0]  wstrb_q;

wire request_w = inport_rd_i || (inport_wr_i != 4'b0);
wire req_fire_w = hxi_req_valid_o && hxi_req_ready_i;
wire rsp_fire_w = hxi_rsp_valid_i && hxi_rsp_ready_o;

// Accept the dcache word into the local request register.  This signal must
// not depend on HXI ready: feeding crossbar back-pressure combinationally into
// dcache_core creates a core -> crossbar -> core ready loop.
assign inport_accept_o    = (state_q == STATE_IDLE);
assign inport_ack_o       = rsp_fire_w;
assign inport_error_o     = rsp_fire_w && hxi_rsp_err_i;
assign inport_read_data_o = hxi_rsp_rdata_i;

assign hxi_req_valid_o = (state_q == STATE_REQ);
assign hxi_req_addr_o  = addr_q;
assign hxi_req_write_o = write_q;
assign hxi_req_wdata_o = wdata_q;
assign hxi_req_wstrb_o = wstrb_q;
assign hxi_rsp_ready_o = (state_q == STATE_RSP);

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    state_q      <= STATE_IDLE;
    write_q      <= 1'b0;
    addr_q       <= 32'b0;
    wdata_q      <= 32'b0;
    wstrb_q      <= 4'b0;
end
else
begin
    case (state_q)
    STATE_IDLE:
    begin
        if (request_w)
        begin
            state_q      <= STATE_REQ;
            write_q      <= !inport_rd_i;
            addr_q       <= {inport_addr_i[31:2], 2'b00};
            wdata_q      <= inport_write_data_i;
            wstrb_q      <= inport_rd_i ? 4'b0 : inport_wr_i;
        end
    end
    STATE_REQ:
    begin
        if (req_fire_w)
            state_q <= STATE_RSP;
    end
    STATE_RSP:
    begin
        if (rsp_fire_w)
        begin
            state_q <= STATE_IDLE;
        end
    end
    default:
        state_q <= STATE_IDLE;
    endcase
end

endmodule
