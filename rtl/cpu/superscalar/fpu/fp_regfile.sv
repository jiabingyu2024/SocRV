`timescale 1ns / 1ps

module fp_regfile (
    input  logic        clk,
    input  logic [4:0]  rs1_addr_i,
    input  logic [4:0]  rs2_addr_i,
    input  logic [4:0]  rs3_addr_i,
    output logic [31:0] rs1_data_o,
    output logic [31:0] rs2_data_o,
    output logic [31:0] rs3_data_o,
    input  logic        write_valid_i,
    input  logic [4:0]  write_addr_i,
    input  logic [31:0] write_data_i
);
    logic [31:0] regs_q [0:31];

    assign rs1_data_o = regs_q[rs1_addr_i];
    assign rs2_data_o = regs_q[rs2_addr_i];
    assign rs3_data_o = regs_q[rs3_addr_i];

    always_ff @(posedge clk) begin
        if (write_valid_i) regs_q[write_addr_i] <= write_data_i;
    end
endmodule
