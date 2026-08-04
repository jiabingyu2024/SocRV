module demo_cpu_core #(
  parameter logic [31:0] RESET_VECTOR = cpu_config_pkg::CPU_RESET_VECTOR
) (
  input logic clk_i,
  input logic rst_ni,
  hxi_if.master instr_hxi,
  hxi_if.master data_hxi,
  input logic irq_software_i,
  input logic irq_timer_i,
  input logic irq_external_i,
  output cpu_types_pkg::commit_trace_t commit_o,
  output logic fault_o
);
  typedef enum logic [2:0] {
    FETCH_REQ,
    FETCH_RSP,
    EXECUTE,
    MEM_REQ,
    MEM_RSP,
    HALTED
  } state_t;

  state_t state_q;
  logic [31:0] regs_q [0:31];
  logic [31:0] pc_q;
  logic [31:0] instruction_q;
  logic [31:0] instruction_pc_q;
  logic [63:0] cycle_q;
  logic [63:0] instret_q;

  logic [31:0] csr_mstatus_q;
  logic [31:0] csr_mie_q;
  logic [31:0] csr_mtvec_q;
  logic [31:0] csr_mscratch_q;
  logic [31:0] csr_mepc_q;
  logic [31:0] csr_mcause_q;

  logic [31:0] mem_addr_q;
  logic mem_write_q;
  logic [31:0] mem_wdata_q;
  logic [3:0] mem_wstrb_q;
  logic [4:0] mem_rd_q;
  logic [2:0] mem_funct3_q;
  logic [1:0] mem_offset_q;
  logic [31:0] mem_next_pc_q;

  logic [6:0] opcode;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [31:0] rs1_value;
  logic [31:0] rs2_value;
  logic [31:0] imm_i;
  logic [31:0] imm_s;
  logic [31:0] imm_b;
  logic [31:0] imm_u;
  logic [31:0] imm_j;

  logic dec_rd_write;
  logic [31:0] dec_rd_value;
  logic [31:0] dec_next_pc;
  logic dec_memory;
  logic dec_mem_write;
  logic [31:0] dec_mem_address;
  logic [31:0] dec_mem_wdata;
  logic [3:0] dec_mem_wstrb;
  logic dec_illegal;
  logic dec_trap;
  logic [31:0] dec_trap_cause;
  logic dec_mret;
  logic dec_csr_write;
  logic [11:0] dec_csr_addr;
  logic [31:0] dec_csr_wdata;
  logic [31:0] csr_read_data;
  logic interrupt_pending;
  logic [31:0] interrupt_cause;
  logic [31:0] load_shifted;
  logic [31:0] load_value;

  assign opcode    = instruction_q[6:0];
  assign rd        = instruction_q[11:7];
  assign funct3    = instruction_q[14:12];
  assign rs1       = instruction_q[19:15];
  assign rs2       = instruction_q[24:20];
  assign funct7    = instruction_q[31:25];
  assign rs1_value = (rs1 == 0) ? 32'b0 : regs_q[rs1];
  assign rs2_value = (rs2 == 0) ? 32'b0 : regs_q[rs2];
  assign imm_i     = {{20{instruction_q[31]}}, instruction_q[31:20]};
  assign imm_s     = {{20{instruction_q[31]}}, instruction_q[31:25], instruction_q[11:7]};
  assign imm_b     = {{19{instruction_q[31]}}, instruction_q[31], instruction_q[7],
                      instruction_q[30:25], instruction_q[11:8], 1'b0};
  assign imm_u     = {instruction_q[31:12], 12'b0};
  assign imm_j     = {{11{instruction_q[31]}}, instruction_q[31], instruction_q[19:12],
                      instruction_q[20], instruction_q[30:21], 1'b0};

  always_comb begin
    case (instruction_q[31:20])
      12'h300: csr_read_data = csr_mstatus_q;
      12'h304: csr_read_data = csr_mie_q;
      12'h305: csr_read_data = csr_mtvec_q;
      12'h340: csr_read_data = csr_mscratch_q;
      12'h341: csr_read_data = csr_mepc_q;
      12'h342: csr_read_data = csr_mcause_q;
      12'hc00: csr_read_data = cycle_q[31:0];
      12'hc80: csr_read_data = cycle_q[63:32];
      12'hc02: csr_read_data = instret_q[31:0];
      12'hc82: csr_read_data = instret_q[63:32];
      default: csr_read_data = '0;
    endcase
  end

  always_comb begin
    interrupt_pending = 1'b0;
    interrupt_cause   = '0;
    if (csr_mstatus_q[3]) begin
      if (irq_external_i && csr_mie_q[11]) begin
        interrupt_pending = 1'b1;
        interrupt_cause   = 32'h8000_000b;
      end else if (irq_timer_i && csr_mie_q[7]) begin
        interrupt_pending = 1'b1;
        interrupt_cause   = 32'h8000_0007;
      end else if (irq_software_i && csr_mie_q[3]) begin
        interrupt_pending = 1'b1;
        interrupt_cause   = 32'h8000_0003;
      end
    end
  end

  always_comb begin
    dec_rd_write    = 1'b0;
    dec_rd_value    = '0;
    dec_next_pc     = instruction_pc_q + 32'd4;
    dec_memory      = 1'b0;
    dec_mem_write   = 1'b0;
    dec_mem_address = '0;
    dec_mem_wdata   = '0;
    dec_mem_wstrb   = '0;
    dec_illegal     = 1'b0;
    dec_trap        = 1'b0;
    dec_trap_cause  = '0;
    dec_mret        = 1'b0;
    dec_csr_write   = 1'b0;
    dec_csr_addr    = instruction_q[31:20];
    dec_csr_wdata   = '0;

    case (opcode)
      7'b0110111: begin
        dec_rd_write = 1'b1;
        dec_rd_value = imm_u;
      end
      7'b0010111: begin
        dec_rd_write = 1'b1;
        dec_rd_value = instruction_pc_q + imm_u;
      end
      7'b1101111: begin
        dec_rd_write = 1'b1;
        dec_rd_value = instruction_pc_q + 32'd4;
        dec_next_pc  = instruction_pc_q + imm_j;
      end
      7'b1100111: begin
        dec_rd_write = 1'b1;
        dec_rd_value = instruction_pc_q + 32'd4;
        dec_next_pc  = (rs1_value + imm_i) & 32'hffff_fffe;
        if (funct3 != 3'b000) dec_illegal = 1'b1;
      end
      7'b1100011: begin
        case (funct3)
          3'b000: if (rs1_value == rs2_value) dec_next_pc = instruction_pc_q + imm_b;
          3'b001: if (rs1_value != rs2_value) dec_next_pc = instruction_pc_q + imm_b;
          3'b100: if ($signed(rs1_value) < $signed(rs2_value)) dec_next_pc = instruction_pc_q + imm_b;
          3'b101: if ($signed(rs1_value) >= $signed(rs2_value)) dec_next_pc = instruction_pc_q + imm_b;
          3'b110: if (rs1_value < rs2_value) dec_next_pc = instruction_pc_q + imm_b;
          3'b111: if (rs1_value >= rs2_value) dec_next_pc = instruction_pc_q + imm_b;
          default: dec_illegal = 1'b1;
        endcase
      end
      7'b0000011: begin
        dec_memory      = 1'b1;
        dec_mem_address = rs1_value + imm_i;
        if (!(funct3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101})) dec_illegal = 1'b1;
      end
      7'b0100011: begin
        dec_memory      = 1'b1;
        dec_mem_write   = 1'b1;
        dec_mem_address = rs1_value + imm_s;
        case (funct3)
          3'b000: begin
            dec_mem_wstrb = 4'b0001 << dec_mem_address[1:0];
            dec_mem_wdata = rs2_value << ({dec_mem_address[1:0], 3'b000});
          end
          3'b001: begin
            if (dec_mem_address[0]) dec_illegal = 1'b1;
            dec_mem_wstrb = dec_mem_address[1] ? 4'b1100 : 4'b0011;
            dec_mem_wdata = rs2_value << ({dec_mem_address[1], 4'b0000});
          end
          3'b010: begin
            if (dec_mem_address[1:0] != 0) dec_illegal = 1'b1;
            dec_mem_wstrb = 4'b1111;
            dec_mem_wdata = rs2_value;
          end
          default: dec_illegal = 1'b1;
        endcase
      end
      7'b0010011: begin
        dec_rd_write = 1'b1;
        case (funct3)
          3'b000: dec_rd_value = rs1_value + imm_i;
          3'b010: dec_rd_value = {31'b0, ($signed(rs1_value) < $signed(imm_i))};
          3'b011: dec_rd_value = {31'b0, (rs1_value < imm_i)};
          3'b100: dec_rd_value = rs1_value ^ imm_i;
          3'b110: dec_rd_value = rs1_value | imm_i;
          3'b111: dec_rd_value = rs1_value & imm_i;
          3'b001: begin
            dec_rd_value = rs1_value << instruction_q[24:20];
            if (funct7 != 7'b0000000) dec_illegal = 1'b1;
          end
          3'b101: begin
            if (funct7 == 7'b0000000) dec_rd_value = rs1_value >> instruction_q[24:20];
            else if (funct7 == 7'b0100000) dec_rd_value = $signed(rs1_value) >>> instruction_q[24:20];
            else dec_illegal = 1'b1;
          end
          default: dec_illegal = 1'b1;
        endcase
      end
      7'b0110011: begin
        dec_rd_write = 1'b1;
        case (funct3)
          3'b000: begin
            if (funct7 == 7'b0000000) dec_rd_value = rs1_value + rs2_value;
            else if (funct7 == 7'b0100000) dec_rd_value = rs1_value - rs2_value;
            else dec_illegal = 1'b1;
          end
          3'b001: dec_rd_value = rs1_value << rs2_value[4:0];
          3'b010: dec_rd_value = {31'b0, ($signed(rs1_value) < $signed(rs2_value))};
          3'b011: dec_rd_value = {31'b0, (rs1_value < rs2_value)};
          3'b100: dec_rd_value = rs1_value ^ rs2_value;
          3'b101: begin
            if (funct7 == 7'b0000000) dec_rd_value = rs1_value >> rs2_value[4:0];
            else if (funct7 == 7'b0100000) dec_rd_value = $signed(rs1_value) >>> rs2_value[4:0];
            else dec_illegal = 1'b1;
          end
          3'b110: dec_rd_value = rs1_value | rs2_value;
          3'b111: dec_rd_value = rs1_value & rs2_value;
          default: dec_illegal = 1'b1;
        endcase
      end
      7'b0001111: begin
        if (funct3 != 3'b000) dec_illegal = 1'b1;
      end
      7'b1110011: begin
        if (funct3 == 3'b000) begin
          if (instruction_q == 32'h3020_0073) dec_mret = 1'b1;
          else begin
            dec_trap = 1'b1;
            dec_trap_cause = (instruction_q[31:20] == 12'd1) ? 32'd3 : 32'd11;
          end
        end else begin
          dec_rd_write = 1'b1;
          dec_rd_value = csr_read_data;
          case (funct3)
            3'b001: begin dec_csr_write = 1'b1; dec_csr_wdata = rs1_value; end
            3'b010: begin dec_csr_write = (rs1 != 0); dec_csr_wdata = csr_read_data | rs1_value; end
            3'b011: begin dec_csr_write = (rs1 != 0); dec_csr_wdata = csr_read_data & ~rs1_value; end
            3'b101: begin dec_csr_write = 1'b1; dec_csr_wdata = {27'b0, rs1}; end
            3'b110: begin dec_csr_write = (rs1 != 0); dec_csr_wdata = csr_read_data | {27'b0, rs1}; end
            3'b111: begin dec_csr_write = (rs1 != 0); dec_csr_wdata = csr_read_data & ~{27'b0, rs1}; end
            default: dec_illegal = 1'b1;
          endcase
        end
      end
      default: dec_illegal = 1'b1;
    endcase
  end

  assign instr_hxi.req_valid = (state_q == FETCH_REQ) && !interrupt_pending;
  assign instr_hxi.req_addr  = pc_q;
  assign instr_hxi.req_write = 1'b0;
  assign instr_hxi.req_wdata = '0;
  assign instr_hxi.req_wstrb = '0;
  assign instr_hxi.rsp_ready = (state_q == FETCH_RSP);

  assign data_hxi.req_valid = (state_q == MEM_REQ);
  assign data_hxi.req_addr  = {mem_addr_q[31:2], 2'b00};
  assign data_hxi.req_write = mem_write_q;
  assign data_hxi.req_wdata = mem_wdata_q;
  assign data_hxi.req_wstrb = mem_wstrb_q;
  assign data_hxi.rsp_ready = (state_q == MEM_RSP);

  assign load_shifted = data_hxi.rsp_rdata >> ({mem_offset_q, 3'b000});
  always_comb begin
    case (mem_funct3_q)
      3'b000: load_value = {{24{load_shifted[7]}}, load_shifted[7:0]};
      3'b001: load_value = {{16{load_shifted[15]}}, load_shifted[15:0]};
      3'b010: load_value = load_shifted;
      3'b100: load_value = {24'b0, load_shifted[7:0]};
      3'b101: load_value = {16'b0, load_shifted[15:0]};
      default: load_value = '0;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q          <= FETCH_REQ;
      pc_q             <= RESET_VECTOR;
      instruction_q    <= '0;
      instruction_pc_q <= '0;
      cycle_q          <= '0;
      instret_q        <= '0;
      csr_mstatus_q    <= '0;
      csr_mie_q        <= '0;
      csr_mtvec_q      <= RESET_VECTOR;
      csr_mscratch_q   <= '0;
      csr_mepc_q       <= '0;
      csr_mcause_q     <= '0;
      mem_addr_q       <= '0;
      mem_write_q      <= 1'b0;
      mem_wdata_q      <= '0;
      mem_wstrb_q      <= '0;
      mem_rd_q         <= '0;
      mem_funct3_q     <= '0;
      mem_offset_q     <= '0;
      mem_next_pc_q    <= '0;
      commit_o         <= '0;
      fault_o          <= 1'b0;
      for (int i = 0; i < 32; i++) regs_q[i] <= '0;
    end else begin
      cycle_q      <= cycle_q + 64'd1;
      commit_o     <= '0;
      regs_q[0]    <= '0;

      case (state_q)
        FETCH_REQ: begin
          if (interrupt_pending) begin
            csr_mepc_q       <= pc_q;
            csr_mcause_q     <= interrupt_cause;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            pc_q             <= {csr_mtvec_q[31:2], 2'b00};
          end else if (instr_hxi.req_ready) begin
            state_q <= FETCH_RSP;
          end
        end
        FETCH_RSP: if (instr_hxi.rsp_valid) begin
          if (instr_hxi.rsp_err) begin
            fault_o <= 1'b1;
            state_q <= HALTED;
          end else begin
            instruction_q    <= instr_hxi.rsp_rdata;
            instruction_pc_q <= pc_q;
            state_q          <= EXECUTE;
          end
        end
        EXECUTE: begin
          if (dec_illegal) begin
            csr_mepc_q       <= instruction_pc_q;
            csr_mcause_q     <= 32'd2;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            pc_q             <= {csr_mtvec_q[31:2], 2'b00};
            state_q          <= FETCH_REQ;
          end else if (dec_trap) begin
            csr_mepc_q       <= instruction_pc_q;
            csr_mcause_q     <= dec_trap_cause;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            pc_q             <= {csr_mtvec_q[31:2], 2'b00};
            state_q          <= FETCH_REQ;
          end else if (dec_mret) begin
            pc_q             <= csr_mepc_q;
            csr_mstatus_q[3] <= csr_mstatus_q[7];
            csr_mstatus_q[7] <= 1'b1;
            instret_q        <= instret_q + 64'd1;
            commit_o.valid   <= 1'b1;
            commit_o.pc      <= instruction_pc_q;
            commit_o.instruction <= instruction_q;
            state_q          <= FETCH_REQ;
          end else if (dec_memory) begin
            mem_addr_q    <= dec_mem_address;
            mem_write_q   <= dec_mem_write;
            mem_wdata_q   <= dec_mem_wdata;
            mem_wstrb_q   <= dec_mem_wstrb;
            mem_rd_q      <= rd;
            mem_funct3_q  <= funct3;
            mem_offset_q  <= dec_mem_address[1:0];
            mem_next_pc_q <= dec_next_pc;
            state_q       <= MEM_REQ;
          end else begin
            if (dec_rd_write && rd != 0) regs_q[rd] <= dec_rd_value;
            if (dec_csr_write) begin
              case (dec_csr_addr)
                12'h300: csr_mstatus_q  <= dec_csr_wdata;
                12'h304: csr_mie_q      <= dec_csr_wdata;
                12'h305: csr_mtvec_q    <= dec_csr_wdata;
                12'h340: csr_mscratch_q <= dec_csr_wdata;
                12'h341: csr_mepc_q     <= dec_csr_wdata;
                12'h342: csr_mcause_q   <= dec_csr_wdata;
                default: ;
              endcase
            end
            pc_q                 <= dec_next_pc;
            instret_q            <= instret_q + 64'd1;
            commit_o.valid       <= 1'b1;
            commit_o.pc          <= instruction_pc_q;
            commit_o.instruction <= instruction_q;
            commit_o.rd          <= dec_rd_write ? rd : '0;
            commit_o.rd_value    <= dec_rd_value;
            state_q              <= FETCH_REQ;
          end
        end
        MEM_REQ: if (data_hxi.req_ready) state_q <= MEM_RSP;
        MEM_RSP: if (data_hxi.rsp_valid) begin
          if (data_hxi.rsp_err) begin
            fault_o <= 1'b1;
            state_q <= HALTED;
          end else begin
            if (!mem_write_q && mem_rd_q != 0) regs_q[mem_rd_q] <= load_value;
            pc_q                 <= mem_next_pc_q;
            instret_q            <= instret_q + 64'd1;
            commit_o.valid       <= 1'b1;
            commit_o.pc          <= instruction_pc_q;
            commit_o.instruction <= instruction_q;
            commit_o.rd          <= mem_write_q ? '0 : mem_rd_q;
            commit_o.rd_value    <= load_value;
            state_q              <= FETCH_REQ;
          end
        end
        default: state_q <= HALTED;
      endcase
    end
  end
endmodule
