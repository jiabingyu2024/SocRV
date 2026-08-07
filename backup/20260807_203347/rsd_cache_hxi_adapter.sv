// SocRV adapters for the independent RSD ICache and DCache memory ports.
//
// RSD transfers one 64-bit cache line per request while HXI transfers one
// 32-bit word.  The adapters queue complete RSD requests, split cache lines
// into two ordered HXI beats and reassemble read responses.  An RSD request is
// acknowledged only once, when it enters the local queue; HXI backpressure is
// therefore kept off the cache request/ack timing path.

import CacheSystemTypes::*;
import MemoryMapTypes::*;

module rsd_icache_hxi_adapter #(
    parameter int unsigned QUEUE_DEPTH = 2
) (
    input  logic clk_i,
    input  logic rst_i,
    input  MemReadAccessReq req_i,
    output MemAccessReqAck ack_o,
    output MemAccessResult result_o,
    output logic error_o,
    hxi_if.master hxi
);
    localparam int unsigned PTR_W = $clog2(QUEUE_DEPTH);
    localparam int unsigned COUNT_W = $clog2(QUEUE_DEPTH + 1);

    logic [31:0] addr_q [0:QUEUE_DEPTH-1];
    MemAccessSerial serial_q [0:QUEUE_DEPTH-1];
    logic [1:0] sent_count_q [0:QUEUE_DEPTH-1];
    logic [1:0] rsp_count_q [0:QUEUE_DEPTH-1];
    logic [31:0] low_data_q [0:QUEUE_DEPTH-1];
    logic error_seen_q [0:QUEUE_DEPTH-1];

    logic [PTR_W-1:0] alloc_ptr_q, send_ptr_q, rsp_ptr_q;
    logic [COUNT_W-1:0] count_q, send_count_q;
    MemAccessSerial next_serial_q;

    logic accept_c, req_fire_c, rsp_fire_c, complete_c, send_complete_c;
    logic result_valid_q, error_q;
    MemAccessSerial result_serial_q;
    logic [63:0] result_data_q;

    assign accept_c = req_i.valid &&
                      (count_q < COUNT_W'(QUEUE_DEPTH));
    assign req_fire_c = hxi.req_valid && hxi.req_ready;
    assign rsp_fire_c = hxi.rsp_valid && hxi.rsp_ready;

    always_comb begin
        hxi.req_valid = 1'b0;
        hxi.req_addr = '0;
        hxi.req_write = 1'b0;
        hxi.req_wdata = '0;
        hxi.req_wstrb = '0;
        if (send_count_q != 0) begin
            hxi.req_valid = sent_count_q[send_ptr_q] < 2;
            hxi.req_addr = {addr_q[send_ptr_q][31:3], 3'b000} +
                           (sent_count_q[send_ptr_q] == 0 ? 32'd0 : 32'd4);
        end
    end

    assign hxi.rsp_ready = 1'b1;
    assign send_complete_c = req_fire_c &&
                             (sent_count_q[send_ptr_q] == 1);

    always_comb begin
        complete_c = 1'b0;
        if (count_q != 0 && rsp_fire_c)
            complete_c = rsp_count_q[rsp_ptr_q] == 1;

        ack_o = '0;
        ack_o.ack = accept_c;
        ack_o.serial = next_serial_q;

        result_o = '0;
        result_o.valid = result_valid_q;
        result_o.serial = result_serial_q;
        result_o.data = result_data_q;
        error_o = error_q;
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            alloc_ptr_q <= '0;
            send_ptr_q <= '0;
            rsp_ptr_q <= '0;
            count_q <= '0;
            send_count_q <= '0;
            next_serial_q <= '0;
            result_valid_q <= 1'b0;
            result_serial_q <= '0;
            result_data_q <= '0;
            error_q <= 1'b0;
        end else begin
            result_valid_q <= 1'b0;
            error_q <= 1'b0;

            if (accept_c) begin
                addr_q[alloc_ptr_q] <= req_i.addr.addr;
                serial_q[alloc_ptr_q] <= next_serial_q;
                sent_count_q[alloc_ptr_q] <= '0;
                rsp_count_q[alloc_ptr_q] <= '0;
                low_data_q[alloc_ptr_q] <= '0;
                error_seen_q[alloc_ptr_q] <= 1'b0;
                alloc_ptr_q <= alloc_ptr_q + 1'b1;
                next_serial_q <= next_serial_q + 1'b1;
            end

            if (req_fire_c) begin
                if (sent_count_q[send_ptr_q] == 1) begin
                    sent_count_q[send_ptr_q] <= 2;
                    send_ptr_q <= send_ptr_q + 1'b1;
                end else begin
                    sent_count_q[send_ptr_q] <= 1;
                end
            end

            if (rsp_fire_c && count_q != 0) begin
                if (rsp_count_q[rsp_ptr_q] == 0) begin
                    low_data_q[rsp_ptr_q] <= hxi.rsp_rdata;
                    rsp_count_q[rsp_ptr_q] <= 1;
                    if (hxi.rsp_err)
                        error_seen_q[rsp_ptr_q] <= 1'b1;
                end else begin
                    result_valid_q <= 1'b1;
                    result_serial_q <= serial_q[rsp_ptr_q];
                    result_data_q <= {hxi.rsp_rdata, low_data_q[rsp_ptr_q]};
                    error_q <= error_seen_q[rsp_ptr_q] | hxi.rsp_err;
                    rsp_ptr_q <= rsp_ptr_q + 1'b1;
                end
            end

            unique case ({accept_c, complete_c})
                2'b10: count_q <= count_q + 1'b1;
                2'b01: count_q <= count_q - 1'b1;
                default: begin end
            endcase
            unique case ({accept_c, send_complete_c})
                2'b10: send_count_q <= send_count_q + 1'b1;
                2'b01: send_count_q <= send_count_q - 1'b1;
                default: begin end
            endcase
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (QUEUE_DEPTH >= 2);
        assert ((QUEUE_DEPTH & (QUEUE_DEPTH - 1)) == 0);
    end
`endif
endmodule

module rsd_dcache_hxi_adapter #(
    parameter int unsigned QUEUE_DEPTH = 4
) (
    input  logic clk_i,
    input  logic rst_i,
    input  MemAccessReq req_i,
    output MemAccessReqAck ack_o,
    output MemAccessResult result_o,
    output MemAccessResponse response_o,
    output logic error_o,
    hxi_if.master hxi
);
    localparam int unsigned PTR_W = $clog2(QUEUE_DEPTH);
    localparam int unsigned COUNT_W = $clog2(QUEUE_DEPTH + 1);

    logic [31:0] addr_q [0:QUEUE_DEPTH-1];
    logic [63:0] data_q [0:QUEUE_DEPTH-1];
    logic write_q [0:QUEUE_DEPTH-1];
    logic uncached_q [0:QUEUE_DEPTH-1];
    MemAccessSerial read_serial_q [0:QUEUE_DEPTH-1];
    MemWriteSerial write_serial_q [0:QUEUE_DEPTH-1];
    logic [1:0] sent_count_q [0:QUEUE_DEPTH-1];
    logic [1:0] rsp_count_q [0:QUEUE_DEPTH-1];
    logic [31:0] low_data_q [0:QUEUE_DEPTH-1];
    logic error_seen_q [0:QUEUE_DEPTH-1];

    logic [PTR_W-1:0] alloc_ptr_q, send_ptr_q, rsp_ptr_q;
    logic [COUNT_W-1:0] count_q, send_count_q;
    MemAccessSerial next_read_serial_q;
    MemWriteSerial next_write_serial_q;

    logic accept_c, req_fire_c, rsp_fire_c, complete_c, send_complete_c;
    logic result_valid_q, response_valid_q, error_q;
    MemAccessSerial result_serial_q;
    MemWriteSerial response_serial_q;
    logic [63:0] result_data_q;

    assign accept_c = req_i.valid &&
                      (count_q < COUNT_W'(QUEUE_DEPTH));
    assign req_fire_c = hxi.req_valid && hxi.req_ready;
    assign rsp_fire_c = hxi.rsp_valid && hxi.rsp_ready;

    always_comb begin
        hxi.req_valid = 1'b0;
        hxi.req_addr = '0;
        hxi.req_write = 1'b0;
        hxi.req_wdata = '0;
        hxi.req_wstrb = '0;
        if (send_count_q != 0) begin
            hxi.req_valid = uncached_q[send_ptr_q] ?
                            (sent_count_q[send_ptr_q] == 0) :
                            (sent_count_q[send_ptr_q] < 2);
            hxi.req_addr = uncached_q[send_ptr_q] ?
                           {addr_q[send_ptr_q][31:2], 2'b00} :
                           ({addr_q[send_ptr_q][31:3], 3'b000} +
                            (sent_count_q[send_ptr_q] == 0 ? 32'd0 : 32'd4));
            hxi.req_write = write_q[send_ptr_q];
            hxi.req_wdata = uncached_q[send_ptr_q] ?
                            (addr_q[send_ptr_q][2] ?
                             data_q[send_ptr_q][63:32] :
                             data_q[send_ptr_q][31:0]) :
                            (sent_count_q[send_ptr_q] == 0 ?
                             data_q[send_ptr_q][31:0] :
                             data_q[send_ptr_q][63:32]);
            hxi.req_wstrb = write_q[send_ptr_q] ? 4'hf : 4'h0;
        end
    end

    assign hxi.rsp_ready = 1'b1;
    assign send_complete_c = req_fire_c &&
                             (uncached_q[send_ptr_q] ||
                              sent_count_q[send_ptr_q] == 1);

    always_comb begin
        complete_c = 1'b0;
        if (count_q != 0 && rsp_fire_c)
            complete_c = uncached_q[rsp_ptr_q] ||
                         (rsp_count_q[rsp_ptr_q] == 1);

        ack_o = '0;
        ack_o.ack = accept_c;
        ack_o.serial = next_read_serial_q;
        ack_o.wserial = next_write_serial_q;

        result_o = '0;
        result_o.valid = result_valid_q;
        result_o.serial = result_serial_q;
        result_o.data = result_data_q;

        response_o = '0;
        response_o.valid = response_valid_q;
        response_o.serial = response_serial_q;
        error_o = error_q;
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            alloc_ptr_q <= '0;
            send_ptr_q <= '0;
            rsp_ptr_q <= '0;
            count_q <= '0;
            send_count_q <= '0;
            next_read_serial_q <= '0;
            next_write_serial_q <= '0;
            result_valid_q <= 1'b0;
            response_valid_q <= 1'b0;
            result_serial_q <= '0;
            response_serial_q <= '0;
            result_data_q <= '0;
            error_q <= 1'b0;
        end else begin
            result_valid_q <= 1'b0;
            response_valid_q <= 1'b0;
            error_q <= 1'b0;

            if (accept_c) begin
                addr_q[alloc_ptr_q] <= req_i.addr.addr;
                data_q[alloc_ptr_q] <= req_i.data;
                write_q[alloc_ptr_q] <= req_i.we;
                uncached_q[alloc_ptr_q] <= req_i.addr.isUncachable;
                read_serial_q[alloc_ptr_q] <= next_read_serial_q;
                write_serial_q[alloc_ptr_q] <= next_write_serial_q;
                sent_count_q[alloc_ptr_q] <= '0;
                rsp_count_q[alloc_ptr_q] <= '0;
                low_data_q[alloc_ptr_q] <= '0;
                error_seen_q[alloc_ptr_q] <= 1'b0;
                alloc_ptr_q <= alloc_ptr_q + 1'b1;
                if (req_i.we)
                    next_write_serial_q <= next_write_serial_q + 1'b1;
                else
                    next_read_serial_q <= next_read_serial_q + 1'b1;
            end

            if (req_fire_c) begin
                if (uncached_q[send_ptr_q] ||
                    sent_count_q[send_ptr_q] == 1) begin
                    sent_count_q[send_ptr_q] <= uncached_q[send_ptr_q] ? 1 : 2;
                    send_ptr_q <= send_ptr_q + 1'b1;
                end else begin
                    sent_count_q[send_ptr_q] <= 1;
                end
            end

            if (rsp_fire_c && count_q != 0) begin
                if (!uncached_q[rsp_ptr_q] &&
                    rsp_count_q[rsp_ptr_q] == 0) begin
                    low_data_q[rsp_ptr_q] <= hxi.rsp_rdata;
                    rsp_count_q[rsp_ptr_q] <= 1;
                    if (hxi.rsp_err)
                        error_seen_q[rsp_ptr_q] <= 1'b1;
                end else begin
                    if (write_q[rsp_ptr_q]) begin
                        response_valid_q <= 1'b1;
                        response_serial_q <= write_serial_q[rsp_ptr_q];
                    end else begin
                        result_valid_q <= 1'b1;
                        result_serial_q <= read_serial_q[rsp_ptr_q];
                        if (uncached_q[rsp_ptr_q]) begin
                            result_data_q <= addr_q[rsp_ptr_q][2] ?
                                {hxi.rsp_rdata, 32'b0} :
                                {32'b0, hxi.rsp_rdata};
                        end else begin
                            result_data_q <=
                                {hxi.rsp_rdata, low_data_q[rsp_ptr_q]};
                        end
                    end
                    error_q <= error_seen_q[rsp_ptr_q] | hxi.rsp_err;
                    rsp_ptr_q <= rsp_ptr_q + 1'b1;
                end
            end

            unique case ({accept_c, complete_c})
                2'b10: count_q <= count_q + 1'b1;
                2'b01: count_q <= count_q - 1'b1;
                default: begin end
            endcase
            unique case ({accept_c, send_complete_c})
                2'b10: send_count_q <= send_count_q + 1'b1;
                2'b01: send_count_q <= send_count_q - 1'b1;
                default: begin end
            endcase
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (QUEUE_DEPTH >= 2);
        assert ((QUEUE_DEPTH & (QUEUE_DEPTH - 1)) == 0);
    end
`endif
endmodule
