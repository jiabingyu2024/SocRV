//==============================================================================
// 模块: control_unit
// 功能概述：
//   纯组合（或带小寄存器，视实现而定）控制译码单元。输入 32 位指令字，输出访存/写回/ALU 类型、
//   是否用立即数作 ALU 第二操作数、分支标志、func3、alu_ctrl、inst_spec 等，不含寄存器堆读写。
// 接口/协作审查（供采纳）：
//   - 与 stage_id 中控制信号应对齐；注释掉的 o_alu1_src/o_alu2_src 若后续启用，需同步流水线寄存器位宽。
//   - o_inst_spec 为 4 位自定义编码，建议文档化与 RISC-V opcode/funct 的对应关系，便于 EX/前递/分支共用。
//==============================================================================
`include "cpu_defines.svh"

module control_unit(
    input  logic  [`INST_BUS]               i_instr,

    output logic                            o_mem_read,
    output logic                            o_mem_write,
    output logic                            o_reg_write,
    output logic                            o_wb_src,
    // output logic                            o_alu1_src,
    // output logic                            o_alu2_src,
    output logic                            o_is_rs2_imm,
    output logic                            o_uses_rs1,
    output logic                            o_uses_rs2,
    output logic  [3:0]                     o_inst_spec,

    output logic  [3:0]                     o_alu_ctrl,
    output logic  [2:0]                     o_func3,

    output logic                            o_is_branch,
    output logic  [3:0]                     o_mem_mask,
    output logic                            o_load_unsigned,
    // output logic                            o_is_jtype,
    // output logic                            o_is_lui,

    output logic                            o_is_m_ext,
    output logic  [`M_OP_BUS]              o_m_op,

    output logic                            o_is_f_ext,
    output logic                            o_f_reg_write,
    output logic                            o_uses_frs1,
    output logic                            o_uses_frs2,
    output logic                            o_uses_frs3,

    output logic                            o_illegal,

    output logic  [11:0]                    o_csr_addr
);

    logic [6:0] opcode;
    logic [2:0] func3;
    logic [6:0] func7;

    assign opcode = i_instr[6:0];
    assign func3  = i_instr[14:12];
    assign func7  = i_instr[31:25];

    always_comb begin
        o_mem_read      = 1'b0;
        o_mem_write     = 1'b0;
        o_reg_write     = 1'b0;
        o_wb_src        = `WB_SRC_ALU;
        o_is_rs2_imm    = 1'b0;
        o_uses_rs1      = 1'b0;
        o_uses_rs2      = 1'b0;
        o_inst_spec     = '0;
        o_alu_ctrl      = `ALU_ADD;
        o_func3         = func3;
        o_is_branch     = 1'b0;
        o_mem_mask      = `MASK_WORD;
        o_load_unsigned = 1'b0;
        o_is_m_ext      = 1'b0;
        o_m_op          = func3;
        o_is_f_ext      = 1'b0;
        o_f_reg_write   = 1'b0;
        o_uses_frs1     = 1'b0;
        o_uses_frs2     = 1'b0;
        o_uses_frs3     = 1'b0;
        o_illegal       = 1'b0;
        o_csr_addr      = i_instr[31:20];

        unique case (opcode)
            `OP_R_TYPE: begin
                o_reg_write = 1'b1;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b1;
                o_is_m_ext  = (func7 == `FUNC7_MULDIV);
                o_m_op      = func3;
                unique case (func3)
                    `FUNC3_ADD_SUB: begin
                        o_alu_ctrl = (func7 == `FUNC7_SUB) ? `ALU_SUB : `ALU_ADD;
                        o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_SUB, `FUNC7_MULDIV});
                    end
                    `FUNC3_SRL_SRA: begin
                        o_alu_ctrl = (func7 == `FUNC7_SRA) ? `ALU_SRA : `ALU_SRL;
                        o_illegal = !(func7 inside {`FUNC7_SRL, `FUNC7_SRA, `FUNC7_MULDIV});
                    end
                    `FUNC3_SLT:     begin o_alu_ctrl = `ALU_LT;  o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    `FUNC3_SLTU:    begin o_alu_ctrl = `ALU_LTU; o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    `FUNC3_AND:     begin o_alu_ctrl = `ALU_AND; o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    `FUNC3_OR:      begin o_alu_ctrl = `ALU_OR;  o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    `FUNC3_XOR:     begin o_alu_ctrl = `ALU_XOR; o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    `FUNC3_SLL:     begin o_alu_ctrl = `ALU_SL;  o_illegal = !(func7 inside {`FUNC7_ADD, `FUNC7_MULDIV}); end
                    default:        o_illegal = 1'b1;
                endcase
            end

            `OP_I_TYPE: begin
                o_reg_write  = 1'b1;
                o_is_rs2_imm = 1'b1;
                o_uses_rs1   = 1'b1;
                unique case (func3)
                    `FUNC3_ADD_SUB: o_alu_ctrl = `ALU_ADD;
                    `FUNC3_SLT:     o_alu_ctrl = `ALU_LT;
                    `FUNC3_SLTU:    o_alu_ctrl = `ALU_LTU;
                    `FUNC3_AND:     o_alu_ctrl = `ALU_AND;
                    `FUNC3_OR:      o_alu_ctrl = `ALU_OR;
                    `FUNC3_XOR:     o_alu_ctrl = `ALU_XOR;
                    `FUNC3_SLL:     o_alu_ctrl = `ALU_SL;
                    `FUNC3_SRL_SRA: o_alu_ctrl = i_instr[30] ? `ALU_SRA : `ALU_SRL;
                    default:        o_alu_ctrl = `ALU_ADD;
                endcase
                if ((func3 == `FUNC3_SLL) && (func7 != 7'b0000000))
                    o_illegal = 1'b1;
                if ((func3 == `FUNC3_SRL_SRA) &&
                    !(func7 inside {7'b0000000, 7'b0100000}))
                    o_illegal = 1'b1;
            end

            `OP_L_TYPE: begin
                o_mem_read      = 1'b1;
                o_reg_write     = 1'b1;
                o_wb_src        = `WB_SRC_MEM;
                o_is_rs2_imm    = 1'b1;
                o_uses_rs1      = 1'b1;
                o_alu_ctrl      = `ALU_ADD;
                o_load_unsigned = func3[2];
                unique case (func3)
                    `FUNC3_LB, `FUNC3_LBU: o_mem_mask = `MASK_BYTE;
                    `FUNC3_LH, `FUNC3_LHU: o_mem_mask = `MASK_HALF;
                    `FUNC3_LW:             o_mem_mask = `MASK_WORD;
                    default: begin
                        o_mem_mask = `MASK_WORD;
                        o_illegal = 1'b1;
                    end
                endcase
            end

            `OP_S_TYPE: begin
                o_mem_write  = 1'b1;
                o_is_rs2_imm = 1'b1;
                o_uses_rs1   = 1'b1;
                o_uses_rs2   = 1'b1;
                o_alu_ctrl   = `ALU_ADD;
                unique case (func3)
                    `FUNC3_SB: o_mem_mask = `MASK_BYTE;
                    `FUNC3_SH: o_mem_mask = `MASK_HALF;
                    `FUNC3_SW: o_mem_mask = `MASK_WORD;
                    default: begin
                        o_mem_mask = `MASK_WORD;
                        o_illegal = 1'b1;
                    end
                endcase
            end

            `OP_B_TYPE: begin
                o_is_branch = 1'b1;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b1;
                o_illegal = !(func3 inside {3'b000, 3'b001, 3'b100,
                                            3'b101, 3'b110, 3'b111});
            end

            `OP_JAL: begin
                o_reg_write = 1'b1;
                o_inst_spec = `EX_JAL;
            end

            `OP_JALR: begin
                o_reg_write  = 1'b1;
                o_is_rs2_imm = 1'b1;
                o_uses_rs1   = 1'b1;
                o_inst_spec  = `EX_JALR;
                o_alu_ctrl   = `ALU_ADD;
                o_illegal    = (func3 != 3'b000);
            end

            `OP_LUI: begin
                o_reg_write  = 1'b1;
                o_is_rs2_imm = 1'b1;
                o_inst_spec  = `EX_LUI;
            end

            `OP_AUIPC: begin
                o_reg_write  = 1'b1;
                o_is_rs2_imm = 1'b1;
                o_inst_spec  = `EX_AUIPC;
                o_alu_ctrl   = `ALU_ADD;
            end

            // fence / fence.i — treated as NOP (no cache in this pipeline)
            `OP_MISC_MEM: begin
                o_illegal = !(func3 inside {3'b000, 3'b001});
            end

            `OP_F_LOAD: begin
                o_is_f_ext      = 1'b1;
                o_f_reg_write   = 1'b1;
                o_mem_read      = 1'b1;
                o_wb_src        = `WB_SRC_MEM;
                o_is_rs2_imm    = 1'b1;
                o_uses_rs1      = 1'b1;
                o_mem_mask      = `MASK_WORD;
                o_illegal       = (func3 != 3'b010);
            end

            `OP_F_STORE: begin
                o_is_f_ext      = 1'b1;
                o_mem_write     = 1'b1;
                o_is_rs2_imm    = 1'b1;
                o_uses_rs1      = 1'b1;
                o_uses_frs2     = 1'b1;
                o_mem_mask      = `MASK_WORD;
                o_illegal       = (func3 != 3'b010);
            end

            `OP_F_MADD, `OP_F_MSUB, `OP_F_NMSUB, `OP_F_NMADD: begin
                o_is_f_ext      = 1'b1;
                o_f_reg_write   = 1'b1;
                o_uses_frs1     = 1'b1;
                o_uses_frs2     = 1'b1;
                o_uses_frs3     = 1'b1;
            end

            `OP_F_TYPE: begin
                o_is_f_ext = 1'b1;
                unique case (func7)
                    7'b1100000: begin // FCVT.W[U].S
                        o_reg_write = 1'b1;
                        o_uses_frs1 = 1'b1;
                    end
                    7'b1010000: begin // FEQ/FLT/FLE
                        o_reg_write = 1'b1;
                        o_uses_frs1 = 1'b1;
                        o_uses_frs2 = 1'b1;
                    end
                    7'b1110000: begin // FMV.X.W/FCLASS.S
                        o_reg_write = 1'b1;
                        o_uses_frs1 = 1'b1;
                    end
                    7'b1101000,       // FCVT.S.W[U]
                    7'b1111000: begin // FMV.W.X
                        o_f_reg_write = 1'b1;
                        o_uses_rs1    = 1'b1;
                    end
                    7'b0101100: begin // FSQRT.S
                        o_f_reg_write = 1'b1;
                        o_uses_frs1   = 1'b1;
                    end
                    default: begin
                        o_f_reg_write = 1'b1;
                        o_uses_frs1   = 1'b1;
                        o_uses_frs2   = 1'b1;
                    end
                endcase
            end

            // CSR instructions, ecall, ebreak, mret
            `OP_SYSTEM: begin
                unique case (func3)
                    3'b000: begin
                        // ecall / ebreak / mret (distinguished by instr[31:20])
                        case (i_instr)
                            32'h0000_0073: o_inst_spec = `EX_ECALL;
                            32'h0010_0073: o_inst_spec = `EX_EBREAK;
                            32'h3020_0073: o_inst_spec = `EX_MRET;
                            default: o_illegal = 1'b1;
                        endcase
                    end
                    `FUNC3_CSRRW,
                    `FUNC3_CSRRS,
                    `FUNC3_CSRRC,
                    `FUNC3_CSRRWI,
                    `FUNC3_CSRRSI,
                    `FUNC3_CSRRCI: begin
                        o_reg_write  = 1'b1;
                        o_inst_spec  = `EX_CSR;
                        // Immediate variants (func3[2]=1): ALU operand comes
                        // from zimm (imm_unit puts it in o_imm).
                        o_is_rs2_imm = func3[2];
                        o_uses_rs1   = !func3[2];
                    end
                    default: o_illegal = 1'b1;
                endcase
            end

            default: begin
                o_illegal = 1'b1;
            end
        endcase
    end
endmodule
