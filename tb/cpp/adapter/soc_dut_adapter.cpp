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
