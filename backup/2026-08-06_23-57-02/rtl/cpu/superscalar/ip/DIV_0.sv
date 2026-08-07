`timescale 1ns / 1ps

/**
 * Unsigned 32/32 restoring divider with the same AXI-stream-shaped contract
 * as the original Vivado div_gen wrapper. One request is accepted while idle
 * and a single result pulse is produced exactly 34 clocks later.
 *
 * m_axis_dout_tdata[63:32] = quotient
 * m_axis_dout_tdata[31:0]  = remainder
 */
module DIV_0 (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        s_axis_dividend_tvalid,
    output logic        s_axis_dividend_tready,
    input  logic [31:0] s_axis_dividend_tdata,
    input  logic        s_axis_divisor_tvalid,
    output logic        s_axis_divisor_tready,
    input  logic [31:0] s_axis_divisor_tdata,
    output logic        m_axis_dout_tvalid,
    output logic [63:0] m_axis_dout_tdata
);
    typedef enum logic [1:0] {
        DIV_IDLE,
        DIV_RUN,
        DIV_WAIT_0,
        DIV_WAIT_1
    } div_state_e;

    div_state_e state_q;
    logic [31:0] dividend_q;
    logic [31:0] divisor_q;
    logic [31:0] quotient_q;
    logic [32:0] remainder_q;
    logic [63:0] result_q;
    logic [5:0] iteration_q;
    logic divide_by_zero_q;
    logic fire;
    logic [32:0] shifted_remainder;
    logic [32:0] next_remainder;
    logic [31:0] next_quotient;

    assign s_axis_dividend_tready = state_q == DIV_IDLE;
    assign s_axis_divisor_tready = state_q == DIV_IDLE;
    assign fire = s_axis_dividend_tvalid && s_axis_divisor_tvalid &&
                  s_axis_dividend_tready && s_axis_divisor_tready;

    always_comb begin
        shifted_remainder = {remainder_q[31:0], dividend_q[31]};
        next_remainder = shifted_remainder;
        next_quotient = {quotient_q[30:0], 1'b0};
        if (shifted_remainder >= {1'b0, divisor_q}) begin
            next_remainder = shifted_remainder - {1'b0, divisor_q};
            next_quotient[0] = 1'b1;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state_q <= DIV_IDLE;
            dividend_q <= '0;
            divisor_q <= '0;
            quotient_q <= '0;
            remainder_q <= '0;
            result_q <= '0;
            iteration_q <= '0;
            divide_by_zero_q <= 1'b0;
            m_axis_dout_tvalid <= 1'b0;
            m_axis_dout_tdata <= '0;
        end else begin
            m_axis_dout_tvalid <= 1'b0;
            unique case (state_q)
                DIV_IDLE: begin
                    if (fire) begin
                        dividend_q <= s_axis_dividend_tdata;
                        divisor_q <= s_axis_divisor_tdata;
                        quotient_q <= '0;
                        remainder_q <= '0;
                        iteration_q <= '0;
                        divide_by_zero_q <= s_axis_divisor_tdata == 32'd0;
                        state_q <= DIV_RUN;
                    end
                end
                DIV_RUN: begin
                    dividend_q <= {dividend_q[30:0], 1'b0};
                    quotient_q <= next_quotient;
                    remainder_q <= next_remainder;
                    if (iteration_q == 6'd31) begin
                        result_q <= divide_by_zero_q ? 64'd0 :
                                    {next_quotient, next_remainder[31:0]};
                        state_q <= DIV_WAIT_0;
                    end else begin
                        iteration_q <= iteration_q + 6'd1;
                    end
                end
                DIV_WAIT_0: state_q <= DIV_WAIT_1;
                DIV_WAIT_1: begin
                    m_axis_dout_tdata <= result_q;
                    m_axis_dout_tvalid <= 1'b1;
                    state_q <= DIV_IDLE;
                end
                default: state_q <= DIV_IDLE;
            endcase
        end
    end

endmodule
