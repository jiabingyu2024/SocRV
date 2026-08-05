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
  logic [63:0] order_q;
  logic [1:0] privilege_q;

  logic [31:0] csr_mstatus_q;
  logic [31:0] csr_mie_q;
  logic [31:0] csr_mtvec_q;
  logic [31:0] csr_mscratch_q;
  logic [31:0] csr_mepc_q;
  logic [31:0] csr_mcause_q;
  logic [31:0] csr_mtval_q;
  logic [31:0] csr_mip;
  logic [31:0] csr_mcounteren_q;
  logic [31:0] csr_mcountinhibit_q;
  logic [31:0] csr_pmpcfg0_q;
  logic [31:0] csr_pmpaddr0_q;
  logic csr_tselect_q;
  logic [31:0] csr_tdata1_q [0:1];
  logic [31:0] csr_tdata2_q [0:1];

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
  logic [31:0] dec_trap_tval;
  logic dec_mret;
  logic dec_csr_write;
  logic dec_csr_write_intent;
  logic dec_csr_valid;
  logic [11:0] dec_csr_addr;
  logic [31:0] dec_csr_wdata;
  logic [31:0] csr_read_data;
  logic interrupt_pending;
  logic [31:0] interrupt_cause;
  logic [31:0] load_shifted;
  logic [31:0] load_value;
  logic [3:0] load_rmask;
  logic signed [63:0] rs1_signed_64;
  logic signed [63:0] rs2_signed_64;
  logic signed [63:0] rs2_unsigned_as_signed_64;
  logic signed [63:0] mul_signed;
  logic signed [63:0] mul_signed_unsigned;
  logic [63:0] mul_unsigned;
  logic execute_trigger_match;
  logic load_trigger_match;
  logic store_trigger_match;

  function automatic logic csr_is_implemented(input logic [11:0] address);
    case (address)
      12'h300, 12'h301, 12'h304, 12'h305, 12'h306, 12'h320,
      12'h340, 12'h341, 12'h342, 12'h343, 12'h344,
      12'h3a0, 12'h3b0,
      12'h7a0, 12'h7a1, 12'h7a2,
      12'hb00, 12'hb80, 12'hb02, 12'hb82,
      12'hc00, 12'hc80, 12'hc02, 12'hc82,
      12'hf11, 12'hf12, 12'hf13, 12'hf14:
        csr_is_implemented = 1'b1;
      default:
        csr_is_implemented = 1'b0;
    endcase
  endfunction

  function automatic logic [31:0] mstatus_warl(input logic [31:0] value);
    logic [31:0] result;
    result = value & 32'h0002_1888;
    if (!(value[12:11] inside {2'b00, 2'b11})) result[12:11] = 2'b00;
    return result;
  endfunction

  function automatic cpu_types_pkg::commit_trace_t make_commit(
    input logic retired,
    input logic sync_trap,
    input logic [31:0] next_pc,
    input logic rd_wen,
    input logic [4:0] rd_addr,
    input logic [31:0] rd_wdata,
    input logic [31:0] cause,
    input logic [31:0] tval,
    input logic mem_valid,
    input logic [31:0] mem_addr,
    input logic [3:0] mem_rmask,
    input logic [3:0] mem_wmask,
    input logic [31:0] mem_rdata,
    input logic [31:0] mem_wdata
  );
    cpu_types_pkg::commit_trace_t value;
    value = '0;
    value.valid         = 1'b1;
    value.retired       = retired;
    value.order         = order_q;
    value.pc_rdata      = instruction_pc_q;
    value.pc_wdata      = next_pc;
    value.instruction   = instruction_q;
    value.rs1_addr      = rs1;
    value.rs1_rdata     = rs1_value;
    value.rs2_addr      = rs2;
    value.rs2_rdata     = rs2_value;
    value.rd_wen        = rd_wen && (rd_addr != 0);
    value.rd_addr       = rd_wen ? rd_addr : '0;
    value.rd_wdata      = rd_wdata;
    value.sync_trap     = sync_trap;
    value.cause         = cause;
    value.tval          = tval;
    value.mode          = privilege_q;
    value.mem_valid     = mem_valid;
    value.mem_addr      = mem_addr;
    value.mem_rmask     = mem_rmask;
    value.mem_wmask     = mem_wmask;
    value.mem_rdata     = mem_rdata;
    value.mem_wdata     = mem_wdata;
    value.csr_mstatus   = csr_mstatus_q;
    value.csr_mie       = csr_mie_q;
    value.csr_mip       = csr_mip;
    value.csr_mtvec     = csr_mtvec_q;
    value.csr_mscratch  = csr_mscratch_q;
    value.csr_mepc      = csr_mepc_q;
    value.csr_mcause    = csr_mcause_q;
    value.csr_mtval     = csr_mtval_q;
    value.csr_mcycle    = cycle_q;
    value.csr_minstret  = instret_q;
    return value;
  endfunction

  function automatic cpu_types_pkg::commit_trace_t make_irq_event();
    cpu_types_pkg::commit_trace_t value;
    value = '0;
    value.irq_valid      = 1'b1;
    value.irq_next_order = order_q;
    value.irq_mip_pre    = csr_mip;
    value.irq_mip_post   = csr_mip;
    return value;
  endfunction

  assign opcode    = instruction_q[6:0];
  assign rd        = instruction_q[11:7];
  assign funct3    = instruction_q[14:12];
  assign rs1       = instruction_q[19:15];
  assign rs2       = instruction_q[24:20];
  assign funct7    = instruction_q[31:25];
  assign rs1_value = (rs1 == 0) ? 32'b0 : regs_q[rs1];
  assign rs2_value = (rs2 == 0) ? 32'b0 : regs_q[rs2];
  assign rs1_signed_64 = {{32{rs1_value[31]}}, rs1_value};
  assign rs2_signed_64 = {{32{rs2_value[31]}}, rs2_value};
  assign rs2_unsigned_as_signed_64 = {32'b0, rs2_value};
  assign mul_signed = rs1_signed_64 * rs2_signed_64;
  assign mul_signed_unsigned =
    rs1_signed_64 * rs2_unsigned_as_signed_64;
  assign mul_unsigned = {32'b0, rs1_value} * {32'b0, rs2_value};
  assign imm_i     = {{20{instruction_q[31]}}, instruction_q[31:20]};
  assign imm_s     = {{20{instruction_q[31]}}, instruction_q[31:25], instruction_q[11:7]};
  assign imm_b     = {{19{instruction_q[31]}}, instruction_q[31], instruction_q[7],
                      instruction_q[30:25], instruction_q[11:8], 1'b0};
  assign imm_u     = {instruction_q[31:12], 12'b0};
  assign imm_j     = {{11{instruction_q[31]}}, instruction_q[31], instruction_q[19:12],
                      instruction_q[20], instruction_q[30:21], 1'b0};
  assign csr_mip   = {
    20'b0,
    irq_external_i,
    3'b0,
    irq_timer_i,
    3'b0,
    irq_software_i,
    3'b0
  };

  always_comb begin
    case (instruction_q[31:20])
      12'h300: csr_read_data = csr_mstatus_q;
      12'h301: csr_read_data = 32'h4010_1100;
      12'h304: csr_read_data = csr_mie_q;
      12'h305: csr_read_data = csr_mtvec_q;
      12'h306: csr_read_data = csr_mcounteren_q;
      12'h320: csr_read_data = csr_mcountinhibit_q;
      12'h340: csr_read_data = csr_mscratch_q;
      12'h341: csr_read_data = csr_mepc_q;
      12'h342: csr_read_data = csr_mcause_q;
      12'h343: csr_read_data = csr_mtval_q;
      12'h344: csr_read_data = csr_mip;
      12'h3a0: csr_read_data = csr_pmpcfg0_q;
      12'h3b0: csr_read_data = csr_pmpaddr0_q;
      12'h7a0: csr_read_data = {31'b0, csr_tselect_q};
      12'h7a1: csr_read_data = csr_tdata1_q[csr_tselect_q];
      12'h7a2: csr_read_data = csr_tdata2_q[csr_tselect_q];
      12'hb00: csr_read_data = cycle_q[31:0];
      12'hb80: csr_read_data = cycle_q[63:32];
      12'hb02: csr_read_data = instret_q[31:0];
      12'hb82: csr_read_data = instret_q[63:32];
      12'hc00: csr_read_data = cycle_q[31:0];
      12'hc80: csr_read_data = cycle_q[63:32];
      12'hc02: csr_read_data = instret_q[31:0];
      12'hc82: csr_read_data = instret_q[63:32];
      12'hf11: csr_read_data = 32'b0;
      12'hf12: csr_read_data = 32'd5;
      12'hf13: csr_read_data = 32'b0;
      12'hf14: csr_read_data = 32'b0;
      default: csr_read_data = '0;
    endcase
  end

  always_comb begin
    interrupt_pending = 1'b0;
    interrupt_cause   = '0;
    if ((privilege_q != 2'b11) || csr_mstatus_q[3]) begin
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
    dec_trap_tval   = '0;
    dec_mret        = 1'b0;
    dec_csr_write   = 1'b0;
    dec_csr_write_intent = 1'b0;
    dec_csr_valid   = 1'b0;
    dec_csr_addr    = instruction_q[31:20];
    dec_csr_wdata   = '0;
    execute_trigger_match = 1'b0;
    load_trigger_match = 1'b0;
    store_trigger_match = 1'b0;

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
        else if ((funct3 inside {3'b001, 3'b101}) &&
                 dec_mem_address[0]) begin
          dec_memory = 1'b0;
          dec_trap = 1'b1;
          dec_trap_cause = 32'd4;
          dec_trap_tval = dec_mem_address;
        end else if (funct3 == 3'b010 &&
                     dec_mem_address[1:0] != 2'b00) begin
          dec_memory = 1'b0;
          dec_trap = 1'b1;
          dec_trap_cause = 32'd4;
          dec_trap_tval = dec_mem_address;
        end
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
            if (dec_mem_address[0]) begin
              dec_memory = 1'b0;
              dec_trap = 1'b1;
              dec_trap_cause = 32'd6;
              dec_trap_tval = dec_mem_address;
            end else begin
              dec_mem_wstrb =
                dec_mem_address[1] ? 4'b1100 : 4'b0011;
              dec_mem_wdata =
                rs2_value << ({dec_mem_address[1], 4'b0000});
            end
          end
          3'b010: begin
            if (dec_mem_address[1:0] != 2'b00) begin
              dec_memory = 1'b0;
              dec_trap = 1'b1;
              dec_trap_cause = 32'd6;
              dec_trap_tval = dec_mem_address;
            end else begin
              dec_mem_wstrb = 4'b1111;
              dec_mem_wdata = rs2_value;
            end
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
        if (funct7 == 7'b0000001) begin
          case (funct3)
            3'b000: dec_rd_value = mul_unsigned[31:0];
            3'b001: dec_rd_value = mul_signed[63:32];
            3'b010: dec_rd_value = mul_signed_unsigned[63:32];
            3'b011: dec_rd_value = mul_unsigned[63:32];
            3'b100: begin
              if (rs2_value == 0) dec_rd_value = 32'hffff_ffff;
              else if (rs1_value == 32'h8000_0000 &&
                       rs2_value == 32'hffff_ffff)
                dec_rd_value = 32'h8000_0000;
              else dec_rd_value =
                $signed(rs1_value) / $signed(rs2_value);
            end
            3'b101: dec_rd_value =
              (rs2_value == 0) ? 32'hffff_ffff :
              rs1_value / rs2_value;
            3'b110: begin
              if (rs2_value == 0) dec_rd_value = rs1_value;
              else if (rs1_value == 32'h8000_0000 &&
                       rs2_value == 32'hffff_ffff)
                dec_rd_value = 32'b0;
              else dec_rd_value =
                $signed(rs1_value) % $signed(rs2_value);
            end
            3'b111: dec_rd_value =
              (rs2_value == 0) ? rs1_value :
              rs1_value % rs2_value;
            default: dec_illegal = 1'b1;
          endcase
        end else begin
          case (funct3)
            3'b000: begin
              if (funct7 == 7'b0000000)
                dec_rd_value = rs1_value + rs2_value;
              else if (funct7 == 7'b0100000)
                dec_rd_value = rs1_value - rs2_value;
              else dec_illegal = 1'b1;
            end
            3'b001: begin
              dec_rd_value = rs1_value << rs2_value[4:0];
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            3'b010: begin
              dec_rd_value = {
                31'b0, ($signed(rs1_value) < $signed(rs2_value))
              };
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            3'b011: begin
              dec_rd_value = {31'b0, (rs1_value < rs2_value)};
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            3'b100: begin
              dec_rd_value = rs1_value ^ rs2_value;
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            3'b101: begin
              if (funct7 == 7'b0000000)
                dec_rd_value = rs1_value >> rs2_value[4:0];
              else if (funct7 == 7'b0100000)
                dec_rd_value =
                  $signed(rs1_value) >>> rs2_value[4:0];
              else dec_illegal = 1'b1;
            end
            3'b110: begin
              dec_rd_value = rs1_value | rs2_value;
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            3'b111: begin
              dec_rd_value = rs1_value & rs2_value;
              if (funct7 != 7'b0000000) dec_illegal = 1'b1;
            end
            default: dec_illegal = 1'b1;
          endcase
        end
      end
      7'b0001111: begin
        if (!(funct3 inside {3'b000, 3'b001})) dec_illegal = 1'b1;
      end
      7'b1110011: begin
        if (funct3 == 3'b000) begin
          if (instruction_q == 32'h3020_0073) begin
            dec_mret = 1'b1;
            if (privilege_q != 2'b11) begin
              dec_mret = 1'b0;
              dec_illegal = 1'b1;
            end
          end else if (instruction_q == 32'h0000_0073) begin
            dec_trap = 1'b1;
            dec_trap_cause =
              (privilege_q == 2'b00) ? 32'd8 :
              (privilege_q == 2'b01) ? 32'd9 : 32'd11;
          end else if (instruction_q == 32'h0010_0073) begin
            dec_trap = 1'b1;
            dec_trap_cause = 32'd3;
            dec_trap_tval = instruction_pc_q;
          end else begin
            dec_illegal = 1'b1;
          end
        end else begin
          dec_rd_write = 1'b1;
          dec_rd_value = csr_read_data;
          case (funct3)
            3'b001: begin dec_csr_write_intent = 1'b1; dec_csr_wdata = rs1_value; end
            3'b010: begin dec_csr_write_intent = (rs1 != 0); dec_csr_wdata = csr_read_data | rs1_value; end
            3'b011: begin dec_csr_write_intent = (rs1 != 0); dec_csr_wdata = csr_read_data & ~rs1_value; end
            3'b101: begin dec_csr_write_intent = 1'b1; dec_csr_wdata = {27'b0, rs1}; end
            3'b110: begin dec_csr_write_intent = (rs1 != 0); dec_csr_wdata = csr_read_data | {27'b0, rs1}; end
            3'b111: begin dec_csr_write_intent = (rs1 != 0); dec_csr_wdata = csr_read_data & ~{27'b0, rs1}; end
            default: dec_illegal = 1'b1;
          endcase
          dec_csr_valid = csr_is_implemented(dec_csr_addr);
          if (!dec_illegal &&
              (!dec_csr_valid ||
               (privilege_q < dec_csr_addr[9:8]) ||
               (dec_csr_write_intent && dec_csr_addr[11:10] == 2'b11))) begin
            dec_rd_write = 1'b0;
            dec_illegal = 1'b1;
          end else begin
            dec_csr_write = dec_csr_write_intent;
          end
        end
      end
      default: dec_illegal = 1'b1;
    endcase

    if (!dec_illegal && !dec_trap && dec_next_pc[1:0] != 2'b00) begin
      dec_rd_write = 1'b0;
      dec_memory = 1'b0;
      dec_trap = 1'b1;
      dec_trap_cause = 32'd0;
      dec_trap_tval = dec_next_pc;
    end

    for (int trigger = 0; trigger < 2; trigger++) begin
      if (csr_tdata1_q[trigger][6] &&
          csr_tdata2_q[trigger] == instruction_pc_q &&
          csr_tdata1_q[trigger][2])
        execute_trigger_match = 1'b1;
      if (csr_tdata1_q[trigger][6] &&
          csr_tdata2_q[trigger] == dec_mem_address &&
          csr_tdata1_q[trigger][0])
        load_trigger_match = 1'b1;
      if (csr_tdata1_q[trigger][6] &&
          csr_tdata2_q[trigger] == dec_mem_address &&
          csr_tdata1_q[trigger][1])
        store_trigger_match = 1'b1;
    end

    if (!dec_illegal && !dec_trap && execute_trigger_match) begin
      dec_rd_write = 1'b0;
      dec_memory = 1'b0;
      dec_trap = 1'b1;
      dec_trap_cause = 32'd3;
      dec_trap_tval = instruction_pc_q;
    end else if (!dec_illegal && !dec_trap && dec_memory &&
                 ((!dec_mem_write && load_trigger_match) ||
                  (dec_mem_write && store_trigger_match))) begin
      dec_rd_write = 1'b0;
      dec_memory = 1'b0;
      dec_trap = 1'b1;
      dec_trap_cause = 32'd3;
      dec_trap_tval = dec_mem_address;
    end
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
    load_rmask = '0;
    case (mem_funct3_q)
      3'b000, 3'b100: begin
        load_value = (mem_funct3_q == 3'b000)
          ? {{24{load_shifted[7]}}, load_shifted[7:0]}
          : {24'b0, load_shifted[7:0]};
        load_rmask = 4'b0001 << mem_offset_q;
      end
      3'b001, 3'b101: begin
        load_value = (mem_funct3_q == 3'b001)
          ? {{16{load_shifted[15]}}, load_shifted[15:0]}
          : {16'b0, load_shifted[15:0]};
        load_rmask = mem_offset_q[1] ? 4'b1100 : 4'b0011;
      end
      3'b010: begin
        load_value = load_shifted;
        load_rmask = 4'b1111;
      end
      default: begin
        load_value = '0;
        load_rmask = '0;
      end
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
      order_q          <= '0;
      privilege_q      <= 2'b11;
      csr_mstatus_q    <= '0;
      csr_mie_q        <= '0;
      csr_mtvec_q      <= RESET_VECTOR;
      csr_mscratch_q   <= '0;
      csr_mepc_q       <= '0;
      csr_mcause_q     <= '0;
      csr_mtval_q      <= '0;
      csr_mcounteren_q <= '0;
      csr_mcountinhibit_q <= '0;
      csr_pmpcfg0_q    <= '0;
      csr_pmpaddr0_q   <= '0;
      csr_tselect_q    <= 1'b0;
      for (int trigger = 0; trigger < 2; trigger++) begin
        csr_tdata1_q[trigger] <= '0;
        csr_tdata2_q[trigger] <= '0;
      end
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
            commit_o          <= make_irq_event();
            csr_mepc_q       <= pc_q;
            csr_mcause_q     <= interrupt_cause;
            csr_mtval_q      <= '0;
            csr_mstatus_q[12:11] <= privilege_q;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            privilege_q      <= 2'b11;
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
            commit_o          <= make_commit(
              1'b0, 1'b1, {csr_mtvec_q[31:2], 2'b00},
              1'b0, '0, '0, 32'd2, instruction_q,
              1'b0, '0, '0, '0, '0, '0
            );
            order_q           <= order_q + 64'd1;
            csr_mepc_q       <= instruction_pc_q;
            csr_mcause_q     <= 32'd2;
            csr_mtval_q      <= instruction_q;
            csr_mstatus_q[12:11] <= privilege_q;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            privilege_q      <= 2'b11;
            pc_q             <= {csr_mtvec_q[31:2], 2'b00};
            state_q          <= FETCH_REQ;
          end else if (dec_trap) begin
            commit_o          <= make_commit(
              1'b0, 1'b1, {csr_mtvec_q[31:2], 2'b00},
              1'b0, '0, '0, dec_trap_cause, dec_trap_tval,
              1'b0, '0, '0, '0, '0, '0
            );
            order_q           <= order_q + 64'd1;
            csr_mepc_q       <= instruction_pc_q;
            csr_mcause_q     <= dec_trap_cause;
            csr_mtval_q      <= dec_trap_tval;
            csr_mstatus_q[12:11] <= privilege_q;
            csr_mstatus_q[7] <= csr_mstatus_q[3];
            csr_mstatus_q[3] <= 1'b0;
            privilege_q      <= 2'b11;
            pc_q             <= {csr_mtvec_q[31:2], 2'b00};
            state_q          <= FETCH_REQ;
          end else if (dec_mret) begin
            commit_o          <= make_commit(
              1'b1, 1'b0, csr_mepc_q,
              1'b0, '0, '0, '0, '0,
              1'b0, '0, '0, '0, '0, '0
            );
            pc_q             <= csr_mepc_q;
            csr_mstatus_q[3] <= csr_mstatus_q[7];
            csr_mstatus_q[7] <= 1'b1;
            csr_mstatus_q[12:11] <= 2'b00;
            privilege_q      <= csr_mstatus_q[12:11];
            instret_q        <= instret_q + 64'd1;
            order_q          <= order_q + 64'd1;
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
            commit_o <= make_commit(
              1'b1, 1'b0, dec_next_pc,
              dec_rd_write, rd, dec_rd_value, '0, '0,
              1'b0, '0, '0, '0, '0, '0
            );
            if (dec_rd_write && rd != 0) regs_q[rd] <= dec_rd_value;
            if (dec_csr_write) begin
              case (dec_csr_addr)
                12'h300: csr_mstatus_q  <= mstatus_warl(dec_csr_wdata);
                12'h304: csr_mie_q      <= dec_csr_wdata & 32'h0000_0888;
                12'h305: csr_mtvec_q    <= {
                  dec_csr_wdata[31:2], 1'b0, dec_csr_wdata[0]
                };
                12'h306: csr_mcounteren_q <= dec_csr_wdata & 32'h0000_0005;
                12'h320: csr_mcountinhibit_q <= dec_csr_wdata & 32'h0000_0005;
                12'h340: csr_mscratch_q <= dec_csr_wdata;
                12'h341: csr_mepc_q     <= {dec_csr_wdata[31:2], 2'b00};
                12'h342: csr_mcause_q   <= dec_csr_wdata;
                12'h343: csr_mtval_q    <= dec_csr_wdata;
                12'h3a0: csr_pmpcfg0_q <= dec_csr_wdata;
                12'h3b0: csr_pmpaddr0_q <= dec_csr_wdata;
                12'h7a0: csr_tselect_q <= dec_csr_wdata[0];
                12'h7a1: csr_tdata1_q[csr_tselect_q] <= dec_csr_wdata;
                12'h7a2: csr_tdata2_q[csr_tselect_q] <= dec_csr_wdata;
                12'hb00: cycle_q[31:0] <= dec_csr_wdata;
                12'hb80: cycle_q[63:32] <= dec_csr_wdata;
                12'hb02: instret_q <= {instret_q[63:32], dec_csr_wdata};
                12'hb82: instret_q <= {dec_csr_wdata, instret_q[31:0]};
                default: ;
              endcase
            end
            pc_q                 <= dec_next_pc;
            if (!(dec_csr_write &&
                  dec_csr_addr inside {12'hb02, 12'hb82}))
              instret_q <= instret_q + 64'd1;
            order_q              <= order_q + 64'd1;
            state_q              <= FETCH_REQ;
          end
        end
        MEM_REQ: if (data_hxi.req_ready) state_q <= MEM_RSP;
        MEM_RSP: if (data_hxi.rsp_valid) begin
          if (data_hxi.rsp_err) begin
            fault_o <= 1'b1;
            state_q <= HALTED;
          end else begin
            commit_o <= make_commit(
              1'b1, 1'b0, mem_next_pc_q,
              !mem_write_q, mem_rd_q, load_value, '0, '0,
              1'b1, mem_addr_q,
              mem_write_q ? 4'b0 : load_rmask,
              mem_write_q ? mem_wstrb_q : 4'b0,
              data_hxi.rsp_rdata, mem_wdata_q
            );
            if (!mem_write_q && mem_rd_q != 0) regs_q[mem_rd_q] <= load_value;
            pc_q                 <= mem_next_pc_q;
            instret_q            <= instret_q + 64'd1;
            order_q              <= order_q + 64'd1;
            state_q              <= FETCH_REQ;
          end
        end
        default: state_q <= HALTED;
      endcase
    end
  end
endmodule
