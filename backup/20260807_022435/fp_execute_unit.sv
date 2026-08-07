`timescale 1ns / 1ps

module fp_execute_unit (
    input  logic                      clk,
    input  logic                      rst,
    input  logic                      flush_i,
    input  logic                      req_valid_i,
    output logic                      req_ready_o,
    input  core_types_pkg::exec_req_t req_i,
    input  logic [2:0]                effective_rm_i,
    output core_types_pkg::fp_completion_t completion_o,
    output logic                      busy_o
);
    import core_types_pkg::*;
    import fpnew_pkg::*;

    localparam fpu_features_t SOCRV_RV32FD = '{
        Width:         64,
        EnableVectors: 1'b0,
        EnableNanBox:  1'b1,
        FpFmtMask:     5'b11000,
        IntFmtMask:    4'b0010
    };

    // Split the wide FP64 datapaths at FPnew's intended internal boundaries.
    // ADDMUL/CONV also use an output register so result/flag generation cannot
    // form a single path through the CPU scoreboard at the 50 MHz FPGA target.
    localparam fpu_implementation_t SOCRV_PIPELINED = '{
        PipeRegs:   '{'{default: 3}, // ADDMUL: input, internal and output
                      '{default: 1}, // DIVSQRT: output
                      '{default: 1}, // NONCOMP: input
                      '{default: 3}},// CONV: input, internal and output
        UnitTypes:  '{'{default: PARALLEL}, // ADDMUL
                      '{default: MERGED},   // DIVSQRT
                      '{default: PARALLEL}, // NONCOMP
                      '{default: MERGED}},  // CONV
        PipeConfig: DISTRIBUTED
    };

    logic pending_q;
    exec_req_t req_q;
    logic [2:0] rm_q;
    logic fp_in_valid, fp_in_ready;
    logic [2:0][63:0] operands;
    roundmode_e round_mode;
    operation_e operation;
    logic op_mod;
    fp_format_e src_fmt, dst_fmt;
    logic [63:0] fp_result;
    status_t fp_status;
    logic fp_out_valid, fp_busy;
    logic [core_config_pkg::TRANS_ID_W-1:0] fp_tag;

    assign req_ready_o = !pending_q && !fp_busy;
    assign fp_in_valid = pending_q;
    assign src_fmt = req_q.uop.fp_fmt ? FP64 : FP32;
    assign dst_fmt = req_q.uop.fp_dst_fmt ? FP64 : FP32;

    always_comb begin
        operands = '0;
        round_mode = roundmode_e'(rm_q);
        operands[0] = req_q.fp_op1;
        operands[1] = req_q.fp_op2;
        operands[2] = req_q.fp_op3;
        operation = ADD;
        op_mod = 1'b0;
        unique case (req_q.uop.fp_op)
            FP_ADD: begin
                operation = ADD;
                operands[1] = req_q.fp_op1;
                operands[2] = req_q.fp_op2;
            end
            FP_SUB: begin
                operation = ADD; op_mod = 1'b1;
                operands[1] = req_q.fp_op1;
                operands[2] = req_q.fp_op2;
            end
            FP_MUL: operation = MUL;
            FP_DIV: operation = DIV;
            FP_SQRT: operation = SQRT;
            FP_FMADD: operation = FMADD;
            FP_FMSUB: begin operation = FMADD; op_mod = 1'b1; end
            FP_FNMSUB: operation = FNMSUB;
            FP_FNMADD: begin operation = FNMSUB; op_mod = 1'b1; end
            FP_SGNJ: begin operation = SGNJ; round_mode = RNE; end
            FP_SGNJN: begin operation = SGNJ; round_mode = RTZ; end
            FP_SGNJX: begin operation = SGNJ; round_mode = RDN; end
            FP_MIN: begin operation = MINMAX; round_mode = RNE; end
            FP_MAX: begin operation = MINMAX; round_mode = RTZ; end
            FP_EQ: begin operation = CMP; round_mode = RDN; end
            FP_LT: begin operation = CMP; round_mode = RTZ; end
            FP_LE: begin operation = CMP; round_mode = RNE; end
            FP_CLASS: operation = CLASSIFY;
            FP_F2I: begin operation = F2I; op_mod = req_q.uop.fp_unsigned; end
            FP_I2F: begin
                operation = I2F;
                op_mod = req_q.uop.fp_unsigned;
                operands[0] = {32'd0, req_q.op1};
            end
            FP_F2F: operation = F2F;
            FP_MV_X_W: begin
                operation = SGNJ; round_mode = RUP; op_mod = 1'b1;
            end
            FP_MV_W_X: begin
                operation = SGNJ; round_mode = RUP;
                operands[0] = {32'hffff_ffff, req_q.op1};
            end
            default: operation = ADD;
        endcase
    end

    fpnew_top #(
        .Features(SOCRV_RV32FD),
        .Implementation(SOCRV_PIPELINED),
        .DivSqrtSel(PULP),
        .TagType(logic [core_config_pkg::TRANS_ID_W-1:0])
    ) u_fpnew (
        .clk_i(clk), .rst_ni(!rst), .operands_i(operands),
        .rnd_mode_i(round_mode), .op_i(operation), .op_mod_i(op_mod),
        .src_fmt_i(src_fmt), .dst_fmt_i(dst_fmt), .int_fmt_i(INT32),
        .vectorial_op_i(1'b0), .tag_i(req_q.trans_id), .simd_mask_i(1'b1),
        .in_valid_i(fp_in_valid), .in_ready_o(fp_in_ready), .flush_i(flush_i),
        .result_o(fp_result), .status_o(fp_status), .tag_o(fp_tag),
        .out_valid_o(fp_out_valid), .out_ready_i(1'b1), .busy_o(fp_busy),
        .early_valid_o()
    );

    always_comb begin
        completion_o = '0;
        completion_o.valid = fp_out_valid;
        completion_o.trans_id = fp_tag;
        completion_o.int_result = fp_result[31:0];
        completion_o.fp_result = fp_result;
        completion_o.fp_flags = fp_status;
        completion_o.writes_rd = req_q.uop.writes_rd;
        completion_o.writes_frd = req_q.uop.writes_frd;
    end

    assign busy_o = pending_q || fp_busy;

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            pending_q <= 1'b0;
            req_q <= '0;
            rm_q <= RNE;
        end else begin
            if (req_valid_i && req_ready_o) begin
                pending_q <= 1'b1;
                req_q <= req_i;
                rm_q <= effective_rm_i;
            end
            if (fp_in_valid && fp_in_ready) pending_q <= 1'b0;
        end
    end
endmodule
