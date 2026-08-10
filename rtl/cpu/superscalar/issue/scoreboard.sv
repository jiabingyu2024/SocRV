`timescale 1ns / 1ps

module scoreboard #(
    parameter int unsigned DEPTH = core_config_pkg::SCOREBOARD_DEPTH,
    parameter int unsigned CNT_W = $clog2(DEPTH + 1)
) (
    input  logic clk,
    input  logic rst,
    input  logic flush_i,

    input  logic allocate_i,
    input  core_types_pkg::uop_t allocate_uop_i,
    input  logic [31:0] allocate_csr_src_i,
    output logic [core_config_pkg::TRANS_ID_W-1:0] allocate_trans_id_o,

    input  logic fixed_complete_i,
    input  core_types_pkg::completion_t fixed_completion_i,
    input  logic load_complete_i,
    input  logic [core_config_pkg::TRANS_ID_W-1:0] load_trans_id_i,
    input  logic [31:0] load_result_i,
    output logic load_complete_accepted_o,
    input  logic slow_complete_i,
    input  logic [core_config_pkg::TRANS_ID_W-1:0] slow_trans_id_i,
    input  logic [31:0] slow_result_i,
    input  core_types_pkg::fp_completion_t fp_completion_i,

    input  logic commit_i,
    output logic [core_config_pkg::TRANS_ID_W-1:0] commit_trans_id_o,
    output core_types_pkg::scoreboard_entry_t commit_entry_o,
    output logic [CNT_W-1:0] count_o,
    output logic serial_pending_o,

    input  core_types_pkg::uop_t query_uop_i,
    output logic query_rs1_found_o,
    output logic query_rs1_ready_o,
    output logic [core_config_pkg::TRANS_ID_W-1:0] query_rs1_trans_id_o,
    output logic [31:0] query_rs1_data_o,
    output logic query_rs2_found_o,
    output logic query_rs2_ready_o,
    output logic [core_config_pkg::TRANS_ID_W-1:0] query_rs2_trans_id_o,
    output logic [31:0] query_rs2_data_o
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
        logic [4:0]  rd;
        logic        writes_rd;
        logic [4:0]  frd;
        logic        writes_frd;
        logic        fp_dirty;
        fp_op_e      fp_op;
        fu_e         fu;
        logic        serialize;
        sys_op_e     sys_op;
        csr_op_e     csr_op;
        logic [11:0] csr_addr;
        logic [31:0] csr_src;
        logic        is_call;
        logic        is_return;
        logic [31:0] link_addr;
    } scoreboard_static_t;

    localparam int unsigned STATIC_W = $bits(scoreboard_static_t);

    scoreboard_entry_t entries_q [0:DEPTH-1];
    // These fields are immutable after allocation and are only observed at
    // the commit head. A single packed distributed-RAM write removes their
    // per-slot FF clock enables from the branch/issue allocation cone.
    (* ram_style = "distributed" *) logic [STATIC_W-1:0] static_q [0:DEPTH-1];
    scoreboard_static_t static_head;
    logic [31:0] producer_valid_q;
    logic [TRANS_ID_W-1:0] producer_tid_q [0:31];
    logic [TRANS_ID_W-1:0] allocate_ptr_q, commit_ptr_q;
    integer i;

    assign allocate_trans_id_o = allocate_ptr_q;
    assign commit_trans_id_o = commit_ptr_q;
    always_comb begin
        static_head = scoreboard_static_t'(static_q[commit_ptr_q]);
        commit_entry_o = entries_q[commit_ptr_q];
        commit_entry_o.pc = static_head.pc;
        commit_entry_o.instr = static_head.instr;
        commit_entry_o.rd = static_head.rd;
        commit_entry_o.writes_rd = static_head.writes_rd;
        commit_entry_o.frd = static_head.frd;
        commit_entry_o.writes_frd = static_head.writes_frd;
        commit_entry_o.fp_dirty = static_head.fp_dirty;
        commit_entry_o.fp_op = static_head.fp_op;
        commit_entry_o.fu = static_head.fu;
        commit_entry_o.serialize = static_head.serialize;
        commit_entry_o.sys_op = static_head.sys_op;
        commit_entry_o.csr_op = static_head.csr_op;
        commit_entry_o.csr_addr = static_head.csr_addr;
        commit_entry_o.csr_src = static_head.csr_src;
        commit_entry_o.is_call = static_head.is_call;
        commit_entry_o.is_return = static_head.is_return;
        commit_entry_o.link_addr = static_head.link_addr;

        query_rs1_found_o = query_uop_i.uses_rs1 && query_uop_i.rs1 != 0 &&
                            producer_valid_q[query_uop_i.rs1];
        query_rs1_trans_id_o = query_rs1_found_o ?
                               producer_tid_q[query_uop_i.rs1] : '0;
        query_rs1_ready_o = !query_rs1_found_o ||
                            entries_q[query_rs1_trans_id_o].done;
        query_rs1_data_o = query_rs1_found_o ?
                           entries_q[query_rs1_trans_id_o].result : 32'd0;

        query_rs2_found_o = query_uop_i.uses_rs2 && query_uop_i.rs2 != 0 &&
                            producer_valid_q[query_uop_i.rs2];
        query_rs2_trans_id_o = query_rs2_found_o ?
                               producer_tid_q[query_uop_i.rs2] : '0;
        query_rs2_ready_o = !query_rs2_found_o ||
                            entries_q[query_rs2_trans_id_o].done;
        query_rs2_data_o = query_rs2_found_o ?
                           entries_q[query_rs2_trans_id_o].result : 32'd0;
        load_complete_accepted_o = load_complete_i && entries_q[load_trans_id_i].occupied;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            allocate_ptr_q <= '0;
            commit_ptr_q <= '0;
            count_o <= '0;
            producer_valid_q <= '0;
            serial_pending_o <= 1'b0;
            for (i = 0; i < DEPTH; i = i + 1)
                entries_q[i].occupied <= 1'b0;
        end else if (flush_i) begin
            allocate_ptr_q <= '0;
            commit_ptr_q <= '0;
            count_o <= '0;
            producer_valid_q <= '0;
            serial_pending_o <= 1'b0;
            for (i = 0; i < DEPTH; i = i + 1)
                entries_q[i].occupied <= 1'b0;
        end else begin
            // Preserve the original same-cycle priority: a new allocation is
            // younger than completion and commit updates to the reused slot.
            if (fixed_complete_i && entries_q[fixed_completion_i.trans_id].occupied) begin
                entries_q[fixed_completion_i.trans_id].done <= 1'b1;
                entries_q[fixed_completion_i.trans_id].result <= fixed_completion_i.result;
                entries_q[fixed_completion_i.trans_id].exception_valid <=
                    fixed_completion_i.exception_valid;
                entries_q[fixed_completion_i.trans_id].exception_cause <=
                    fixed_completion_i.exception_cause;
                entries_q[fixed_completion_i.trans_id].exception_tval <=
                    fixed_completion_i.exception_tval;
                entries_q[fixed_completion_i.trans_id].store_slot_valid <=
                    fixed_completion_i.store_slot_valid;
                entries_q[fixed_completion_i.trans_id].store_slot <=
                    fixed_completion_i.store_slot;
            end
            if (load_complete_accepted_o) begin
                entries_q[load_trans_id_i].done <= 1'b1;
                entries_q[load_trans_id_i].result <= load_result_i;
            end
            if (slow_complete_i && entries_q[slow_trans_id_i].occupied) begin
                entries_q[slow_trans_id_i].done <= 1'b1;
                entries_q[slow_trans_id_i].result <= slow_result_i;
            end
            if (fp_completion_i.valid && entries_q[fp_completion_i.trans_id].occupied) begin
                entries_q[fp_completion_i.trans_id].done <= 1'b1;
                entries_q[fp_completion_i.trans_id].result <= fp_completion_i.int_result;
                entries_q[fp_completion_i.trans_id].fp_result <= fp_completion_i.fp_result;
                entries_q[fp_completion_i.trans_id].fp_flags <= fp_completion_i.fp_flags;
                entries_q[fp_completion_i.trans_id].exception_valid <=
                    fp_completion_i.exception_valid;
                entries_q[fp_completion_i.trans_id].exception_cause <=
                    fp_completion_i.exception_cause;
                entries_q[fp_completion_i.trans_id].exception_tval <=
                    fp_completion_i.exception_tval;
            end

            if (commit_i) begin
                if (commit_entry_o.writes_rd && commit_entry_o.rd != 0 &&
                    producer_valid_q[commit_entry_o.rd] &&
                    producer_tid_q[commit_entry_o.rd] == commit_ptr_q)
                    producer_valid_q[commit_entry_o.rd] <= 1'b0;
                entries_q[commit_ptr_q].occupied <= 1'b0;
                commit_ptr_q <= commit_ptr_q + 1'b1;
                if (commit_entry_o.serialize || commit_entry_o.exception_valid)
                    serial_pending_o <= 1'b0;
            end

            if (allocate_i) begin
                entries_q[allocate_ptr_q].occupied <= 1'b1;
                entries_q[allocate_ptr_q].done <= allocate_uop_i.exception_valid ||
                                                  allocate_uop_i.fu == FU_SYSTEM;
                entries_q[allocate_ptr_q].fp_result <= '0;
                entries_q[allocate_ptr_q].fp_flags <= '0;
                entries_q[allocate_ptr_q].exception_valid <= allocate_uop_i.exception_valid;
                entries_q[allocate_ptr_q].exception_cause <= allocate_uop_i.exception_cause;
                entries_q[allocate_ptr_q].exception_tval <= allocate_uop_i.exception_tval;
                entries_q[allocate_ptr_q].store_slot_valid <= 1'b0;
                static_q[allocate_ptr_q] <= scoreboard_static_t'{
                    pc: allocate_uop_i.pc,
                    instr: allocate_uop_i.instr,
                    rd: allocate_uop_i.rd,
                    writes_rd: allocate_uop_i.writes_rd,
                    frd: allocate_uop_i.frd,
                    writes_frd: allocate_uop_i.writes_frd,
                    fp_dirty: allocate_uop_i.fu == FU_FP ||
                              allocate_uop_i.fu == FU_FP_MEM,
                    fp_op: allocate_uop_i.fp_op,
                    fu: allocate_uop_i.fu,
                    serialize: allocate_uop_i.serialize,
                    sys_op: allocate_uop_i.sys_op,
                    csr_op: allocate_uop_i.csr_op,
                    csr_addr: allocate_uop_i.csr_addr,
                    csr_src: allocate_uop_i.csr_imm ?
                        {27'd0, allocate_uop_i.rs1} : allocate_csr_src_i,
                    is_call: (allocate_uop_i.is_jal || allocate_uop_i.is_jalr) &&
                             (allocate_uop_i.rd == 5'd1 || allocate_uop_i.rd == 5'd5),
                    is_return: allocate_uop_i.is_jalr &&
                               (allocate_uop_i.rs1 == 5'd1 ||
                                allocate_uop_i.rs1 == 5'd5) &&
                               allocate_uop_i.rd == 0,
                    link_addr: allocate_uop_i.pc + 32'd4
                };
                if (allocate_uop_i.writes_rd && allocate_uop_i.rd != 0) begin
                    producer_valid_q[allocate_uop_i.rd] <= 1'b1;
                    producer_tid_q[allocate_uop_i.rd] <= allocate_ptr_q;
                end
                allocate_ptr_q <= allocate_ptr_q + 1'b1;
                if (allocate_uop_i.serialize) serial_pending_o <= 1'b1;
            end

            unique case ({allocate_i, commit_i})
                2'b10: count_o <= count_o + 1'b1;
                2'b01: count_o <= count_o - 1'b1;
                default: begin end
            endcase
        end
    end

`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (!rst) begin
            assert (count_o <= CNT_W'(DEPTH));
            if (fixed_complete_i)
                assert (entries_q[fixed_completion_i.trans_id].occupied);
            if (load_complete_i) assert (entries_q[load_trans_id_i].occupied);
            if (slow_complete_i) assert (entries_q[slow_trans_id_i].occupied);
            if (fp_completion_i.valid)
                assert (entries_q[fp_completion_i.trans_id].occupied);
        end
    end
`endif
endmodule
