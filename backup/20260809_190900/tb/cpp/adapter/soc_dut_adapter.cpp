#include "soc_dut_adapter.h"

#include <verilated.h>
#include <verilated_vcd_c.h>

#include <stdexcept>

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
#if VM_TRACE
        trace_ = std::make_unique<VerilatedVcdC>();
        dut_->trace(trace_.get(), 5);
        trace_->open(trace_path.c_str());
#else
        throw std::runtime_error(
            "this Verilator model was built without trace support");
#endif
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
#if VM_TRACE
        if (trace_) {
            trace_->dump(context_->time());
        }
#endif
        context_->timeInc(1);
    }
}

void SocDutAdapter::finish() {
    if (finished_) {
        return;
    }
    dut_->final();
#if VM_TRACE
    if (trace_) {
        trace_->close();
    }
#endif
    finished_ = true;
}

bool SocDutAdapter::uart_tx() const {
    return dut_->uart_tx_o;
}

bool SocDutAdapter::commit_valid() const {
    return (dut_->trace_valid_o & 0x3u) != 0;
}

std::uint32_t SocDutAdapter::retired_count() const {
    const std::uint32_t valid = dut_->trace_valid_o;
    return (valid & 1u) + ((valid >> 1u) & 1u);
}

std::uint32_t SocDutAdapter::commit_pc() const {
    if ((dut_->trace_valid_o & 0x2u) != 0) {
        return static_cast<std::uint32_t>(dut_->trace_address_o >> 32u);
    }
    return static_cast<std::uint32_t>(dut_->trace_address_o);
}

std::uint32_t SocDutAdapter::debug_mepc() const {
    return dut_->debug_mepc_o;
}

std::uint32_t SocDutAdapter::debug_mcause() const {
    return dut_->debug_mcause_o;
}

std::uint32_t SocDutAdapter::debug_mtval() const {
    return dut_->debug_mtval_o;
}

std::vector<ArchEvent> SocDutAdapter::arch_events() const {
    std::vector<ArchEvent> events;
    const std::uint32_t valid = dut_->trace_valid_o;
    if ((valid & 0x1u) != 0) {
        ArchEvent event;
        event.valid = true;
        event.retired = true;
        event.pc_rdata = static_cast<std::uint32_t>(dut_->trace_address_o);
        event.instruction =
            static_cast<std::uint32_t>(dut_->trace_instruction_o);
        events.push_back(event);
    }
    if ((valid & 0x2u) != 0) {
        ArchEvent event;
        event.valid = true;
        event.retired = true;
        event.pc_rdata =
            static_cast<std::uint32_t>(dut_->trace_address_o >> 32u);
        event.instruction =
            static_cast<std::uint32_t>(dut_->trace_instruction_o >> 32u);
        events.push_back(event);
    }
    return events;
}

std::vector<IrqEvent> SocDutAdapter::irq_events() const {
    return {};
}

bool SocDutAdapter::cpu_fault() const {
    return false;
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
