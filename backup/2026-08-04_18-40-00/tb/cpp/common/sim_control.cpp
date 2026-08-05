#include "sim_control.h"

#include <iostream>

#include "perf_stats.h"
#include "soc_dut_adapter.h"
#include "uart_decoder.h"

SimControl::SimControl(const SimConfig& config, SocDutAdapter& dut)
    : config_(config), dut_(dut) {}

SimResult SimControl::run() {
    SimResult result;
    PerfStats stats(config_);
    UartDecoder uart;
    std::uint32_t last_commit_pc = 0;

    dut_.set_reset(false);
    dut_.set_uart_rx(true);
    for (std::uint64_t cycle = 0; cycle < config_.max_cycles; ++cycle) {
        if (cycle == 10) {
            dut_.set_reset(true);
        }
        dut_.step_cycle();
        uart.sample(dut_.uart_tx());
        if (dut_.commit_valid()) {
            last_commit_pc = dut_.commit_pc();
        }
        stats.observe(cycle, dut_.commit_valid(), dut_.test_code());

        if (dut_.cpu_fault()) {
            std::cerr << "\nFAIL: CPU bus fault at cycle " << cycle << "\n";
            result.status = "FAIL";
            result.exit_reason = "cpu_fault";
            result.cycles = cycle;
            result.test_code = 0xffffffffu;
            break;
        }
        if (dut_.test_done()) {
            const bool passed = dut_.test_pass();
            std::cout << "\n" << (passed ? "PASS" : "FAIL")
                      << ": test_code=" << dut_.test_code()
                      << " cycles=" << cycle << "\n";
            result.status = passed ? "PASS" : "FAIL";
            result.exit_reason = "test_status";
            result.cycles = cycle;
            result.test_code = dut_.test_code();
            break;
        }
        if (cycle + 1 == config_.max_cycles) {
            std::cerr << "\nTIMEOUT after " << config_.max_cycles
                      << " cycles\n";
            result.status = "TIMEOUT";
            result.exit_reason = "max_cycles";
            result.cycles = config_.max_cycles;
        }
    }
    result.commits = stats.total_commits();
    result.last_commit_pc = last_commit_pc;
    result.performance = stats.snapshot();
    if (result.status == "PASS" &&
        result.performance.requested &&
        !result.performance.complete) {
        result.status = "FAIL";
        result.exit_reason = "performance_window_incomplete";
    }
    dut_.finish();
    return result;
}
