`timescale 1ns / 1ps

module fp_memory_unit (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      flush_i,
    input  logic                      req_valid_i,
    output logic                      req_ready_o,
    input  core_types_pkg::exec_req_t req_i,
    input  logic                      req_uncached_i,
    output logic                      cache_req_valid_o,
    input  logic                      cache_req_ready_i,
    output logic                      cache_req_write_o,
    output logic [31:0]               cache_req_addr_o,
    output logic [31:0]               cache_req_wdata_o,
    output logic [3:0]                cache_req_wstrb_o,
    output logic                      cache_req_uncached_o,
    input  logic                      cache_resp_valid_i,
    input  logic [31:0]               cache_resp_rdata_i,
    output core_types_pkg::fp_completion_t completion_o,
    output logic                      busy_o
);
    import core_types_pkg::*;

    typedef enum logic [2:0] {
        FP_MEM_IDLE, FP_MEM_REQ_LO, FP_MEM_WAIT_LO,
        FP_MEM_REQ_HI, FP_MEM_WAIT_HI
    } state_e;

    state_e state_q;
    exec_req_t req_q;
    logic [31:0] addr_q, load_low_q;
    logic uncached_q;
    fp_completion_t completion_q;
    logic misaligned_c;
    logic [31:0] req_addr_c;

    assign req_ready_o = state_q == FP_MEM_IDLE;
    assign busy_o = state_q != FP_MEM_IDLE;
    assign completion_o = completion_q;
    assign req_addr_c = req_i.op1 + req_i.uop.imm;
    assign misaligned_c = req_i.uop.fp_fmt ?
                          (|req_addr_c[2:0]) : (|req_addr_c[1:0]);

    always_comb begin
        cache_req_valid_o = state_q == FP_MEM_REQ_LO ||
                            state_q == FP_MEM_REQ_HI;
        cache_req_write_o = req_q.uop.fp_op == FP_STORE;
        cache_req_addr_o = addr_q +
            ((state_q == FP_MEM_REQ_HI) ? 32'd4 : 32'd0);
        cache_req_wdata_o = (state_q == FP_MEM_REQ_HI) ?
                            req_q.fp_op2[63:32] : req_q.fp_op2[31:0];
        cache_req_wstrb_o = 4'hf;
        cache_req_uncached_o = uncached_q;
    end

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            state_q <= FP_MEM_IDLE;
            req_q <= '0;
            addr_q <= '0;
            load_low_q <= '0;
            uncached_q <= 1'b0;
            completion_q <= '0;
        end else begin
            completion_q.valid <= 1'b0;
            unique case (state_q)
                FP_MEM_IDLE: begin
                    if (req_valid_i && req_ready_o) begin
                        req_q <= req_i;
                        addr_q <= req_addr_c;
                        uncached_q <= req_uncached_i;
                        if (misaligned_c) begin
                            completion_q <= '0;
                            completion_q.valid <= 1'b1;
                            completion_q.trans_id <= req_i.trans_id;
                            completion_q.exception_valid <= 1'b1;
                            completion_q.exception_cause <=
                                req_i.uop.fp_op == FP_LOAD ? 5'd4 : 5'd6;
                            completion_q.exception_tval <= req_addr_c;
                        end else begin
                            state_q <= FP_MEM_REQ_LO;
                        end
                    end
                end
                FP_MEM_REQ_LO: begin
                    if (cache_req_ready_i) begin
                        if (req_q.uop.fp_op == FP_STORE) begin
                            if (req_q.uop.fp_fmt) state_q <= FP_MEM_REQ_HI;
                            else begin
                                completion_q <= '0;
                                completion_q.valid <= 1'b1;
                                completion_q.trans_id <= req_q.trans_id;
                                state_q <= FP_MEM_IDLE;
                            end
                        end else begin
                            state_q <= FP_MEM_WAIT_LO;
                        end
                    end
                end
                FP_MEM_WAIT_LO: begin
                    if (cache_resp_valid_i) begin
                        load_low_q <= cache_resp_rdata_i;
                        if (req_q.uop.fp_fmt) begin
                            state_q <= FP_MEM_REQ_HI;
                        end else begin
                            completion_q <= '0;
                            completion_q.valid <= 1'b1;
                            completion_q.trans_id <= req_q.trans_id;
                            completion_q.fp_result <= {32'hffff_ffff, cache_resp_rdata_i};
                            completion_q.writes_frd <= 1'b1;
                            state_q <= FP_MEM_IDLE;
                        end
                    end
                end
                FP_MEM_REQ_HI: begin
                    if (cache_req_ready_i) begin
                        if (req_q.uop.fp_op == FP_STORE) begin
                            completion_q <= '0;
                            completion_q.valid <= 1'b1;
                            completion_q.trans_id <= req_q.trans_id;
                            state_q <= FP_MEM_IDLE;
                        end else begin
                            state_q <= FP_MEM_WAIT_HI;
                        end
                    end
                end
                FP_MEM_WAIT_HI: begin
                    if (cache_resp_valid_i) begin
                        completion_q <= '0;
                        completion_q.valid <= 1'b1;
                        completion_q.trans_id <= req_q.trans_id;
                        completion_q.fp_result <= {cache_resp_rdata_i, load_low_q};
                        completion_q.writes_frd <= 1'b1;
                        state_q <= FP_MEM_IDLE;
                    end
                end
                default: state_q <= FP_MEM_IDLE;
            endcase
        end
    end
endmodule
