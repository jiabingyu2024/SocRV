module eh1_fpu (
   input  logic        clk,
   input  logic        rst_l,
   input  logic        flush_i,
   input  logic        req_valid_i,
   output logic        req_ready_o,
   input  logic [31:0] inst_i,
   input  logic [31:0] int_rs1_i,
   input  logic [31:0] frs1_i,
   input  logic [31:0] frs2_i,
   input  logic [31:0] frs3_i,
   input  logic [2:0]  frm_i,
   output logic        resp_valid_o,
   output logic [31:0] result_o,
   output logic [4:0]  flags_o,
   output logic        writes_gpr_o,
   output logic        writes_fpr_o,
   output logic [4:0]  rd_o,
   output logic        busy_o
);
   import fpnew_pkg::*;

   localparam fpu_implementation_t EH1F_PIPELINED = '{
      PipeRegs:   '{'{default: 3},
                    '{default: 1},
                    '{default: 1},
                    '{default: 3}},
      UnitTypes:  '{'{default: PARALLEL},
                    '{default: MERGED},
                    '{default: PARALLEL},
                    '{default: MERGED}},
      PipeConfig: DISTRIBUTED
   };

   logic pending_q, active_q;
   logic [31:0] inst_q, int_rs1_q, frs1_q, frs2_q, frs3_q;
   logic [2:0] frm_q;
   logic fp_in_valid, fp_in_ready, fp_out_valid;
   logic [2:0][31:0] operands;
   roundmode_e round_mode;
   operation_e operation;
   logic op_mod;
   logic [31:0] fp_result;
   status_t fp_status;
   logic [6:0] fp_tag;
   logic [6:0] request_tag;
   logic request_writes_gpr, request_writes_fpr;

   wire [6:0] opcode = inst_q[6:0];
   wire [6:0] funct7 = inst_q[31:25];
   wire [2:0] funct3 = inst_q[14:12];

   assign req_ready_o = !pending_q && !active_q;
   assign fp_in_valid = pending_q;
   assign request_tag = {request_writes_gpr, request_writes_fpr, inst_q[11:7]};

   always_comb begin
      operands = '0;
      operands[0] = frs1_q;
      operands[1] = frs2_q;
      operands[2] = frs3_q;
      round_mode = roundmode_e'((funct3 == 3'b111) ? frm_q : funct3);
      operation = ADD;
      op_mod = 1'b0;
      request_writes_gpr = 1'b0;
      request_writes_fpr = 1'b1;

      unique case (opcode)
         7'b1000011: operation = FMADD;
         7'b1000111: begin operation = FMADD; op_mod = 1'b1; end
         7'b1001011: operation = FNMSUB;
         7'b1001111: begin operation = FNMSUB; op_mod = 1'b1; end
         7'b1010011: begin
            unique case (funct7)
               7'b0000000: begin
                  operation = ADD;
                  operands[1] = frs1_q;
                  operands[2] = frs2_q;
               end
               7'b0000100: begin
                  operation = ADD; op_mod = 1'b1;
                  operands[1] = frs1_q;
                  operands[2] = frs2_q;
               end
               7'b0001000: operation = MUL;
               7'b0001100: operation = DIV;
               7'b0101100: operation = SQRT;
               7'b0010000: begin
                  operation = SGNJ;
                  unique case (funct3)
                     3'b000: round_mode = RNE;
                     3'b001: round_mode = RTZ;
                     default: round_mode = RDN;
                  endcase
               end
               7'b0010100: begin
                  operation = MINMAX;
                  round_mode = funct3[0] ? RTZ : RNE;
               end
               7'b1010000: begin
                  operation = CMP;
                  request_writes_gpr = 1'b1;
                  request_writes_fpr = 1'b0;
                  unique case (funct3)
                     3'b010: round_mode = RDN;
                     3'b001: round_mode = RTZ;
                     default: round_mode = RNE;
                  endcase
               end
               7'b1100000: begin
                  operation = F2I;
                  op_mod = inst_q[20];
                  request_writes_gpr = 1'b1;
                  request_writes_fpr = 1'b0;
               end
               7'b1101000: begin
                  operation = I2F;
                  op_mod = inst_q[20];
                  operands[0] = int_rs1_q;
               end
               7'b1110000: begin
                  request_writes_gpr = 1'b1;
                  request_writes_fpr = 1'b0;
                  if (funct3 == 3'b001) begin
                     operation = CLASSIFY;
                  end else begin
                     operation = SGNJ;
                     round_mode = RUP;
                     op_mod = 1'b1;
                  end
               end
               7'b1111000: begin
                  operation = SGNJ;
                  round_mode = RUP;
                  operands[0] = int_rs1_q;
               end
               default: ;
            endcase
         end
         default: ;
      endcase
   end

   fpnew_top #(
      .Features(RV32F),
      .Implementation(EH1F_PIPELINED),
      .DivSqrtSel(PULP),
      .TagType(logic [6:0])
   ) fpnew (
      .clk_i(clk), .rst_ni(rst_l), .operands_i(operands),
      .rnd_mode_i(round_mode), .op_i(operation), .op_mod_i(op_mod),
      .src_fmt_i(FP32), .dst_fmt_i(FP32), .int_fmt_i(INT32),
      .vectorial_op_i(1'b0), .tag_i(request_tag), .simd_mask_i(1'b1),
      .in_valid_i(fp_in_valid), .in_ready_o(fp_in_ready), .flush_i(flush_i),
      .result_o(fp_result), .status_o(fp_status), .tag_o(fp_tag),
      .out_valid_o(fp_out_valid), .out_ready_i(1'b1), .busy_o(),
      .early_valid_o()
   );

   assign resp_valid_o = fp_out_valid && !flush_i;
   assign result_o = fp_result;
   assign flags_o = fp_status;
   assign writes_gpr_o = fp_tag[6];
   assign writes_fpr_o = fp_tag[5];
   assign rd_o = fp_tag[4:0];
   assign busy_o = pending_q || active_q;

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         pending_q <= 1'b0;
         active_q <= 1'b0;
         inst_q <= 32'b0;
         int_rs1_q <= 32'b0;
         frs1_q <= 32'b0;
         frs2_q <= 32'b0;
         frs3_q <= 32'b0;
         frm_q <= RNE;
      end else if (flush_i) begin
         pending_q <= 1'b0;
         active_q <= 1'b0;
      end else begin
         if (req_valid_i && req_ready_o) begin
            pending_q <= 1'b1;
            inst_q <= inst_i;
            int_rs1_q <= int_rs1_i;
            frs1_q <= frs1_i;
            frs2_q <= frs2_i;
            frs3_q <= frs3_i;
            frm_q <= frm_i;
         end
         if (fp_in_valid && fp_in_ready) begin
            pending_q <= 1'b0;
            active_q <= 1'b1;
         end
         if (fp_out_valid) active_q <= 1'b0;
      end
   end

`ifndef SYNTHESIS
   always_ff @(posedge clk) begin
      if (rst_l && fp_in_valid && fp_in_ready)
         $display("EH1F_FPU_REQ inst=%08x op=%0d mod=%0d a=%08x b=%08x c=%08x tag=%02x",
                  inst_q, operation, op_mod, operands[0], operands[1], operands[2], request_tag);
      if (rst_l && fp_out_valid)
         $display("EH1F_FPU_RSP result=%08x flags=%02x tag=%02x",
                  fp_result, fp_status, fp_tag);
   end
`endif
endmodule
