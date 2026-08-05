`include "cpu_defines.svh"

module csr_file (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [11:0] i_raddr,
    output logic [31:0] o_rdata,
    output logic        o_access_valid,
    output logic        o_access_read_only,
    input  logic        i_we,
    input  logic [11:0] i_waddr,
    input  logic [31:0] i_wdata,
    input  logic [1:0]  i_wmode,
    input  logic        i_fflags_we,
    input  logic [4:0]  i_fflags,
    output logic [2:0]  o_frm,
    input  logic        i_trap_en,
    input  logic [31:0] i_trap_pc,
    input  logic [31:0] i_trap_cause,
    input  logic [31:0] i_trap_tval,
    input  logic        i_mret_en,
    input  logic        i_retire,
    input  logic        i_irq_software,
    input  logic        i_irq_timer,
    input  logic        i_irq_external,
    output logic        o_interrupt_pending,
    output logic [31:0] o_interrupt_cause,
    output logic [1:0]  o_privilege,
    output logic [31:0] o_ecall_cause,
    output logic [31:0] o_mtvec,
    output logic [31:0] o_mepc,
    output logic [31:0] o_mstatus,
    output logic [31:0] o_mie,
    output logic [31:0] o_mip,
    output logic [31:0] o_mscratch,
    output logic [31:0] o_mcause,
    output logic [31:0] o_mtval,
    output logic [63:0] o_mcycle,
    output logic [63:0] o_minstret
);
    logic [1:0] privilege_q;
    logic [31:0] mstatus_q;
    logic [31:0] mie_q;
    logic [31:0] mtvec_q;
    logic [31:0] mcounteren_q;
    logic [31:0] mcountinhibit_q;
    logic [31:0] mscratch_q;
    logic [31:0] mepc_q;
    logic [31:0] mcause_q;
    logic [31:0] mtval_q;
    logic [31:0] pmpcfg0_q;
    logic [31:0] pmpaddr0_q;
    logic [63:0] cycle_q;
    logic [63:0] instret_q;
    logic [2:0] frm_q;
    logic [4:0] fflags_q;
    logic [31:0] mip;
    logic [31:0] fflags_write_value;
    logic [31:0] frm_write_value;
    logic [31:0] fcsr_write_value;
    logic [31:0] mepc_write_value;

    function automatic logic csr_is_implemented(input logic [11:0] address);
        case (address)
            12'h001, 12'h002, 12'h003,
            12'h300, 12'h301, 12'h304, 12'h305, 12'h306, 12'h320,
            12'h340, 12'h341, 12'h342, 12'h343, 12'h344,
            12'h3a0, 12'h3b0,
            12'hb00, 12'hb80, 12'hb02, 12'hb82,
            12'hc00, 12'hc80, 12'hc02, 12'hc82,
            12'h7a0, 12'h7a5,
            12'hf11, 12'hf12, 12'hf13, 12'hf14:
                csr_is_implemented = 1'b1;
            default: csr_is_implemented = 1'b0;
        endcase
    endfunction

    function automatic logic [31:0] apply_wmode(
        input logic [31:0] old_value,
        input logic [31:0] operand,
        input logic [1:0] mode
    );
        case (mode)
            2'b00: apply_wmode = operand;
            2'b01: apply_wmode = old_value | operand;
            2'b10: apply_wmode = old_value & ~operand;
            default: apply_wmode = old_value;
        endcase
    endfunction

    function automatic logic [31:0] mstatus_warl(input logic [31:0] value);
        logic [31:0] result;
        result = value & 32'h0002_1888;
        if (!(value[12:11] inside {2'b00, 2'b11})) result[12:11] = 2'b00;
        return result;
    endfunction

    assign mip = {20'b0, i_irq_external, 3'b0, i_irq_timer,
                  3'b0, i_irq_software, 3'b0};
    assign o_access_valid = csr_is_implemented(i_raddr);
    assign o_access_read_only = (i_raddr[11:10] == 2'b11);
    assign o_frm       = frm_q;
    assign o_privilege = privilege_q;
    assign o_ecall_cause = (privilege_q == 2'b00) ? 32'd8 :
                           (privilege_q == 2'b01) ? 32'd9 : 32'd11;
    assign o_mtvec     = mtvec_q;
    assign o_mepc      = mepc_q;
    assign o_mstatus   = mstatus_q;
    assign o_mie       = mie_q;
    assign o_mip       = mip;
    assign o_mscratch  = mscratch_q;
    assign o_mcause    = mcause_q;
    assign o_mtval     = mtval_q;
    assign o_mcycle    = cycle_q;
    assign o_minstret  = instret_q;
    assign fflags_write_value = apply_wmode({27'd0, fflags_q}, i_wdata, i_wmode);
    assign frm_write_value = apply_wmode({29'd0, frm_q}, i_wdata, i_wmode);
    assign fcsr_write_value = apply_wmode({24'd0, frm_q, fflags_q}, i_wdata, i_wmode);
    assign mepc_write_value = apply_wmode(mepc_q, i_wdata, i_wmode);

    always_comb begin
        unique case (i_raddr)
            12'h001: o_rdata = {27'b0, fflags_q};
            12'h002: o_rdata = {29'b0, frm_q};
            12'h003: o_rdata = {24'b0, frm_q, fflags_q};
            12'h300: o_rdata = mstatus_q;
            // Keep the target SoC's integer compliance contract: the F
            // datapath is present, but misa.F is not advertised by this gate.
            12'h301: o_rdata = 32'h4010_1100; // RV32 I/M/U
            12'h304: o_rdata = mie_q;
            12'h305: o_rdata = mtvec_q;
            12'h306: o_rdata = mcounteren_q;
            12'h320: o_rdata = mcountinhibit_q;
            12'h340: o_rdata = mscratch_q;
            12'h341: o_rdata = mepc_q;
            12'h342: o_rdata = mcause_q;
            12'h343: o_rdata = mtval_q;
            12'h344: o_rdata = mip;
            12'h3a0: o_rdata = pmpcfg0_q;
            12'h3b0: o_rdata = pmpaddr0_q;
            12'hb00, 12'hc00: o_rdata = cycle_q[31:0];
            12'hb80, 12'hc80: o_rdata = cycle_q[63:32];
            12'hb02, 12'hc02: o_rdata = instret_q[31:0];
            12'hb82, 12'hc82: o_rdata = instret_q[63:32];
            // No hardware trigger slots.  tselect is a non-zero WARL value so
            // software can discover that fact without taking an illegal trap.
            12'h7a0: o_rdata = 32'd1;
            12'hf12: o_rdata = 32'd5;
            default: o_rdata = 32'd0;
        endcase
    end

    always_comb begin
        o_interrupt_pending = 1'b0;
        o_interrupt_cause = 32'd0;
        if ((privilege_q != 2'b11) || mstatus_q[3]) begin
            if (i_irq_external && mie_q[11]) begin
                o_interrupt_pending = 1'b1;
                o_interrupt_cause = 32'h8000_000b;
            end else if (i_irq_timer && mie_q[7]) begin
                o_interrupt_pending = 1'b1;
                o_interrupt_cause = 32'h8000_0007;
            end else if (i_irq_software && mie_q[3]) begin
                o_interrupt_pending = 1'b1;
                o_interrupt_cause = 32'h8000_0003;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            privilege_q     <= 2'b11;
            mstatus_q       <= 32'd0;
            mie_q           <= 32'd0;
            mtvec_q         <= cpu_config_pkg::CPU_RESET_VECTOR;
            mcounteren_q    <= 32'd0;
            mcountinhibit_q <= 32'd0;
            mscratch_q      <= 32'd0;
            mepc_q          <= 32'd0;
            mcause_q        <= 32'd0;
            mtval_q         <= 32'd0;
            pmpcfg0_q       <= 32'd0;
            pmpaddr0_q      <= 32'd0;
            cycle_q         <= 64'd0;
            instret_q       <= 64'd0;
            frm_q           <= 3'd0;
            fflags_q        <= 5'd0;
        end else begin
            if (!mcountinhibit_q[0]) cycle_q <= cycle_q + 64'd1;
            if (i_retire && !mcountinhibit_q[2] &&
                !(i_we && ((i_waddr == 12'hb02) || (i_waddr == 12'hb82)))) begin
                instret_q <= instret_q + 64'd1;
            end

            if (i_trap_en) begin
                mepc_q <= {i_trap_pc[31:2], 2'b00};
                mcause_q <= i_trap_cause;
                mtval_q <= i_trap_tval;
                mstatus_q[12:11] <= privilege_q;
                mstatus_q[7] <= mstatus_q[3];
                mstatus_q[3] <= 1'b0;
                privilege_q <= 2'b11;
            end else if (i_mret_en) begin
                privilege_q <= mstatus_q[12:11];
                mstatus_q[3] <= mstatus_q[7];
                mstatus_q[7] <= 1'b1;
                mstatus_q[12:11] <= 2'b00;
            end else begin
                if (i_we) begin
                    unique case (i_waddr)
                        12'h001: fflags_q <= fflags_write_value[4:0];
                        12'h002: frm_q <= frm_write_value[2:0];
                        12'h003: begin
                            frm_q <= fcsr_write_value[7:5];
                            fflags_q <= fcsr_write_value[4:0];
                        end
                        12'h300: mstatus_q <= mstatus_warl(apply_wmode(mstatus_q, i_wdata, i_wmode));
                        12'h304: mie_q <= apply_wmode(mie_q, i_wdata, i_wmode) & 32'h0000_0888;
                        12'h305: begin
                            logic [31:0] value;
                            value = apply_wmode(mtvec_q, i_wdata, i_wmode);
                            mtvec_q <= {value[31:2], 1'b0, value[0]};
                        end
                        12'h306: mcounteren_q <= apply_wmode(mcounteren_q, i_wdata, i_wmode) & 32'h5;
                        12'h320: mcountinhibit_q <= apply_wmode(mcountinhibit_q, i_wdata, i_wmode) & 32'h5;
                        12'h340: mscratch_q <= apply_wmode(mscratch_q, i_wdata, i_wmode);
                        12'h341: mepc_q <= {mepc_write_value[31:2], 2'b00};
                        12'h342: mcause_q <= apply_wmode(mcause_q, i_wdata, i_wmode);
                        12'h343: mtval_q <= apply_wmode(mtval_q, i_wdata, i_wmode);
                        12'h3a0: pmpcfg0_q <= apply_wmode(pmpcfg0_q, i_wdata, i_wmode);
                        12'h3b0: pmpaddr0_q <= apply_wmode(pmpaddr0_q, i_wdata, i_wmode);
                        12'hb00: cycle_q[31:0] <= apply_wmode(cycle_q[31:0], i_wdata, i_wmode);
                        12'hb80: cycle_q[63:32] <= apply_wmode(cycle_q[63:32], i_wdata, i_wmode);
                        12'hb02: instret_q[31:0] <= apply_wmode(instret_q[31:0], i_wdata, i_wmode);
                        12'hb82: instret_q[63:32] <= apply_wmode(instret_q[63:32], i_wdata, i_wmode);
                        default: ;
                    endcase
                end else if (i_fflags_we) begin
                    fflags_q <= fflags_q | i_fflags;
                end
            end
        end
    end
endmodule
