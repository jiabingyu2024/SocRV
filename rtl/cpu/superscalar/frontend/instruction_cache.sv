`timescale 1ns / 1ps

// Blocking direct-mapped instruction cache. The external HXI port remains
// strictly single-outstanding, while hits can sustain one fetch per cycle.
module instruction_cache #(
    parameter int unsigned WORDS = 1024
) (
    input  logic clk, input logic rst,
    input  logic cpu_req_valid_i, output logic cpu_req_ready_o,
    input  logic [31:0] cpu_req_addr_i,
    output logic cpu_resp_valid_o, output logic [31:0] cpu_resp_data_o,
    output logic cpu_resp_err_o,
    output logic mem_req_valid_o, input logic mem_req_ready_i,
    output logic [31:0] mem_req_addr_o,
    input  logic mem_resp_valid_i, input logic [31:0] mem_resp_data_i,
    input  logic mem_resp_err_i
);
    localparam int unsigned INDEX_W = $clog2(WORDS);
    localparam int unsigned TAG_W = 32 - INDEX_W - 2;
    typedef enum logic [1:0] {IC_IDLE, IC_MISS_REQ, IC_MISS_WAIT} state_e;
    state_e state_q;

    (* ram_style = "block" *) logic [31:0] data_mem [0:WORDS-1];
    (* ram_style = "block" *) logic [TAG_W-1:0] tag_mem [0:WORDS-1];
    logic [WORDS-1:0] valid_q;
    logic lookup_valid_q, lookup_line_valid_q;
    logic [31:0] lookup_addr_q, lookup_data_q;
    logic [TAG_W-1:0] lookup_tag_q;
    logic miss_resp_valid_q, miss_resp_err_q;
    logic [31:0] miss_resp_data_q;
    logic lookup_hit, request_fire;
    logic [INDEX_W-1:0] request_index, miss_index;

    assign request_index = cpu_req_addr_i[INDEX_W+1:2];
    assign miss_index = lookup_addr_q[INDEX_W+1:2];
    assign lookup_hit = lookup_valid_q && lookup_line_valid_q &&
                        lookup_tag_q == lookup_addr_q[31:INDEX_W+2];
    assign cpu_req_ready_o = state_q == IC_IDLE &&
                             (!lookup_valid_q || lookup_hit);
    assign request_fire = cpu_req_valid_i && cpu_req_ready_o;
    assign cpu_resp_valid_o = lookup_hit || miss_resp_valid_q;
    assign cpu_resp_data_o = lookup_hit ? lookup_data_q : miss_resp_data_q;
    assign cpu_resp_err_o = lookup_hit ? 1'b0 : miss_resp_err_q;
    assign mem_req_valid_o = state_q == IC_MISS_REQ;
    assign mem_req_addr_o = {lookup_addr_q[31:2], 2'b00};

    always_ff @(posedge clk) begin
        if (rst) begin
            state_q <= IC_IDLE;
            valid_q <= '0;
            lookup_valid_q <= 1'b0;
            lookup_addr_q <= '0;
            lookup_data_q <= '0;
            lookup_tag_q <= '0;
            lookup_line_valid_q <= 1'b0;
            miss_resp_valid_q <= 1'b0;
            miss_resp_data_q <= '0;
            miss_resp_err_q <= 1'b0;
        end else begin
            miss_resp_valid_q <= 1'b0;
            if (state_q == IC_IDLE) begin
                lookup_valid_q <= request_fire;
                if (request_fire) begin
                    lookup_addr_q <= cpu_req_addr_i;
                    lookup_data_q <= data_mem[request_index];
                    lookup_tag_q <= tag_mem[request_index];
                    lookup_line_valid_q <= valid_q[request_index];
                end
                if (lookup_valid_q && !lookup_hit) begin
                    lookup_valid_q <= 1'b0;
                    state_q <= IC_MISS_REQ;
                end
            end else if (state_q == IC_MISS_REQ) begin
                if (mem_req_valid_o && mem_req_ready_i)
                    state_q <= IC_MISS_WAIT;
            end else if (mem_resp_valid_i) begin
                miss_resp_valid_q <= 1'b1;
                miss_resp_data_q <= mem_resp_data_i;
                miss_resp_err_q <= mem_resp_err_i;
                if (!mem_resp_err_i) begin
                    data_mem[miss_index] <= mem_resp_data_i;
                    tag_mem[miss_index] <= lookup_addr_q[31:INDEX_W+2];
                    valid_q[miss_index] <= 1'b1;
                end
                state_q <= IC_IDLE;
            end
        end
    end

`ifndef SYNTHESIS
    initial assert (WORDS >= 2 && (WORDS & (WORDS - 1)) == 0);
    always_ff @(posedge clk) if (!rst) begin
        assert (!(lookup_hit && miss_resp_valid_q));
        if (mem_req_valid_o) assert (state_q == IC_MISS_REQ);
    end
`endif
endmodule
