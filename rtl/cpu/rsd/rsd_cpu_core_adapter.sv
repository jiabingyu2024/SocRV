// SocRV-facing wrapper around the RSD out-of-order core.
// The SoC-facing contract remains unchanged; RSD's two cache boundaries are
// connected to the existing instruction and data HXI masters independently.

import BasicTypes::*;
import CacheSystemTypes::*;
import MemoryMapTypes::*;
import DebugTypes::*;
import cpu_types_pkg::*;

module rsd_cpu_core_adapter (
    input  logic clk_i,
    input  logic rst_ni,
    hxi_if.master instr_hxi,
    hxi_if.master data_hxi,
    input  logic irq_software_i,
    input  logic irq_timer_i,
    input  logic irq_external_i,
    output cpu_types_pkg::commit_trace_t commit_o,
    output logic fault_o
);
    localparam int unsigned RETIRE_COUNT_WIDTH = $clog2(COMMIT_WIDTH + 1);

    logic rsd_rst, rsd_rst_start;
    logic ic_error, dc_error;

    MemReadAccessReq ic_req;
    MemAccessReq dc_req;
    MemAccessReqAck ic_ack, dc_ack;
    MemAccessResult ic_result, dc_result;
    MemAccessResponse dc_response;
    DebugRegister debug_register;
    PC_Path last_committed_pc;
    logic serial_we;
    SerialDataPath serial_write_data;
    logic [RETIRE_COUNT_WIDTH-1:0] retire_count_c;
    logic [63:0] retire_order_q, trace_order_q;
    logic trace_valid_q;
    PC_Path trace_pc_q;

    // RSD clears cache/predictor RAMs by walking their indices while reset is
    // asserted.  A one-cycle reset leaves most FPGA RAM valid bits unknown, so
    // retain the upstream reset sequencer at the integration boundary.
    ResetController #(
        .CYCLE_OF_RESET_SEQUENCE(10000)
    ) u_rsd_reset_controller (
        .clk(clk_i),
        .rstTrigger(!rst_ni),
        .locked(rst_ni),
        .rst(rsd_rst),
        .rstStart(rsd_rst_start)
    );

    rsd_icache_hxi_adapter u_icache_hxi (
        .clk_i(clk_i), .rst_i(rsd_rst),
        .req_i(ic_req), .ack_o(ic_ack), .result_o(ic_result),
        .error_o(ic_error), .hxi(instr_hxi)
    );

    rsd_dcache_hxi_adapter u_dcache_hxi (
        .clk_i(clk_i), .rst_i(rsd_rst),
        .req_i(dc_req), .ack_o(dc_ack), .result_o(dc_result),
        .response_o(dc_response), .error_o(dc_error), .hxi(data_hxi)
    );

    Core u_rsd_core (
        .clk(clk_i),
        .rst(rsd_rst),
        .rstStart(rsd_rst_start),
        .icMemAccessReqAck_i(ic_ack),
        .icMemAccessResult_i(ic_result),
        .dcMemAccessReqAck_i(dc_ack),
        .dcMemAccessResult_i(dc_result),
        .dcMemAccessResponse_i(dc_response),
        .reqSoftwareInterrupt(irq_software_i),
        .reqTimerInterrupt(irq_timer_i),
        .reqExternalInterrupt(irq_external_i),
        .externalInterruptCode(5'd11),
        .debugRegister(debug_register),
        .lastCommittedPC(last_committed_pc),
        .icMemAccessReq_o(ic_req),
        .dcMemAccessReq_o(dc_req),
        .serialWE(serial_we),
        .serialWriteData(serial_write_data)
    );

    // ICache requests are speculative.  A predictor/line prefetch may legally
    // probe just beyond IROM and later be flushed, so an I-side HXI error must
    // not become an imprecise fatal SoC fault.  The returned zero word still
    // becomes an illegal-instruction trap if that PC is actually executed.
    // D-side errors are non-speculative at this boundary and remain fatal.
    assign fault_o = dc_error;

    // RSD can retire two lanes in one cycle while the legacy SocRV trace port
    // carries one event.  Emit the youngest retired PC and encode the complete
    // lane count as an order advance.  The simulation performance collector
    // uses that advance, so IPC includes both retire lanes without widening
    // the SoC-facing hardware interface or adding a commit critical path.
    always_comb begin
        retire_count_c = '0;
        for (int i = 0; i < COMMIT_WIDTH; i++) begin
            if (debug_register.cmReg[i].commit)
                retire_count_c = retire_count_c + 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rsd_rst) begin
            retire_order_q <= '0;
            trace_order_q <= '0;
            trace_valid_q <= 1'b0;
            trace_pc_q <= '0;
        end else begin
            trace_valid_q <= retire_count_c != 0;
            if (retire_count_c != 0) begin
                trace_pc_q <= last_committed_pc;
                trace_order_q <= retire_order_q + retire_count_c - 1'b1;
                retire_order_q <= retire_order_q + retire_count_c;
            end
        end
    end

    always_comb begin
        commit_o = '0;
        commit_o.valid = trace_valid_q;
        commit_o.retired = trace_valid_q;
        commit_o.order = trace_order_q;
        commit_o.pc = trace_pc_q;
        commit_o.pc_rdata = trace_pc_q;
        commit_o.pc_wdata = trace_pc_q + 32'd4;
        commit_o.mode = 2'b11;
    end
endmodule
