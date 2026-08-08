#include "soc_dut_adapter.h"

#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vsoc_sim_top.h"

SocDutAdapter::SocDutAdapter(
    int argc,
    char** argv,
    const std::string& trace_path)
    : context_(std::make_unique<VerilatedContext>()),
      dut_(nullptr) {
    context_->commandArgs(argc, argv);
    context_->traceEverOn(!trace_path.empty());
    dut_ = std::make_unique<Vsoc_sim_top>(context_.get());
    dut_->clk_i = 0;
    dut_->rst_ni = 0;
    dut_->uart_rx_i = 1;
    if (!trace_path.empty()) {
        trace_ = std::make_unique<VerilatedVcdC>();
        dut_->trace(trace_.get(), 5);
        trace_->open(trace_path.c_str());
    }
}

SocDutAdapter::~SocDutAdapter() {
    finish();
}

void SocDutAdapter::set_reset(bool released) {
    dut_->rst_ni = released;
}

void SocDutAdapter::set_uart_rx(bool value) {
    dut_->uart_rx_i = value;
}

void SocDutAdapter::step_cycle() {
    for (int phase = 0; phase < 2; ++phase) {
        dut_->clk_i = phase;
        dut_->eval();
        if (trace_) {
            trace_->dump(context_->time());
        }
        context_->timeInc(1);
    }
}

void SocDutAdapter::finish() {
    if (finished_) {
        return;
    }
    dut_->final();
    if (trace_) {
        trace_->close();
    }
    finished_ = true;
}

bool SocDutAdapter::uart_tx() const {
    return dut_->uart_tx_o;
}

bool SocDutAdapter::commit_valid() const {
    return dut_->commit_valid_o;
}

std::uint32_t SocDutAdapter::commit_pc() const {
    return dut_->commit_pc_o;
}

std::vector<ArchEvent> SocDutAdapter::arch_events() const {
    if (!dut_->commit_valid_o) {
        return {};
    }
    ArchEvent event;
    event.valid = true;
    event.retired = dut_->commit_retired_o;
    event.order = dut_->commit_order_o;
    event.pc_rdata = dut_->commit_pc_o;
    event.pc_wdata = dut_->commit_next_pc_o;
    event.instruction = dut_->commit_instruction_o;
    event.rs1_addr = dut_->commit_rs1_addr_o;
    event.rs1_rdata = dut_->commit_rs1_rdata_o;
    event.rs2_addr = dut_->commit_rs2_addr_o;
    event.rs2_rdata = dut_->commit_rs2_rdata_o;
    event.rd_wen = dut_->commit_rd_wen_o;
    event.rd_addr = dut_->commit_rd_addr_o;
    event.rd_wdata = dut_->commit_rd_wdata_o;
    event.sync_trap = dut_->commit_sync_trap_o;
    event.cause = dut_->commit_cause_o;
    event.tval = dut_->commit_tval_o;
    event.mode = dut_->commit_mode_o;
    event.mem_valid = dut_->commit_mem_valid_o;
    event.mem_addr = dut_->commit_mem_addr_o;
    event.mem_rmask = dut_->commit_mem_rmask_o;
    event.mem_wmask = dut_->commit_mem_wmask_o;
    event.mem_rdata = dut_->commit_mem_rdata_o;
    event.mem_wdata = dut_->commit_mem_wdata_o;
    event.csr_mstatus = dut_->commit_csr_mstatus_o;
    event.csr_mie = dut_->commit_csr_mie_o;
    event.csr_mip = dut_->commit_csr_mip_o;
    event.csr_mtvec = dut_->commit_csr_mtvec_o;
    event.csr_mscratch = dut_->commit_csr_mscratch_o;
    event.csr_mepc = dut_->commit_csr_mepc_o;
    event.csr_mcause = dut_->commit_csr_mcause_o;
    event.csr_mtval = dut_->commit_csr_mtval_o;
    event.csr_mcycle = dut_->commit_csr_mcycle_o;
    event.csr_minstret = dut_->commit_csr_minstret_o;
    return {event};
}

std::vector<IrqEvent> SocDutAdapter::irq_events() const {
    if (!dut_->irq_event_valid_o) {
        return {};
    }
    IrqEvent event;
    event.valid = true;
    event.next_order = dut_->irq_event_next_order_o;
    event.mip_pre = dut_->irq_event_mip_pre_o;
    event.mip_post = dut_->irq_event_mip_post_o;
    return {event};
}

bool SocDutAdapter::cpu_fault() const {
    return dut_->cpu_fault_o;
}

bool SocDutAdapter::test_done() const {
    return dut_->test_done_o;
}

bool SocDutAdapter::test_pass() const {
    return dut_->test_pass_o;
}

std::uint32_t SocDutAdapter::test_code() const {
    return dut_->test_code_o;
}

PerfCounterSample SocDutAdapter::perf_counters() const {
    PerfCounterSample value;
    value.icache_misses = dut_->perf_icache_misses_o;
    value.load_misses = dut_->perf_load_misses_o;
    value.store_misses = dut_->perf_store_misses_o;
    value.branch_mispredicts = dut_->perf_branch_mispredicts_o;
    value.decode_branch_mispredicts =
        dut_->perf_decode_branch_mispredicts_o;
    value.store_load_forwarding_failures =
        dut_->perf_store_load_forwarding_failures_o;
    value.memory_dependency_mispredicts =
        dut_->perf_memory_dependency_mispredicts_o;
    value.icache_stall = dut_->perf_icache_stall_o;
    value.decode_stall = dut_->perf_decode_stall_o;
    value.rename_stall = dut_->perf_rename_stall_o;
    value.backend_stall = dut_->perf_backend_stall_o;
    value.recovery_cycle = dut_->perf_recovery_cycle_o;
    value.rename_no_physreg = dut_->perf_rename_no_physreg_o;
    value.rename_no_iq = dut_->perf_rename_no_iq_o;
    value.rename_no_rob = dut_->perf_rename_no_rob_o;
    value.rename_no_lsq = dut_->perf_rename_no_lsq_o;
    value.rename_serialize = dut_->perf_rename_serialize_o;
    value.dispatch_count = dut_->perf_dispatch_count_o;
    value.issue_count = dut_->perf_issue_count_o;
    return value;
}
