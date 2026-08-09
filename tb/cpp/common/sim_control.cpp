#include "sim_control.h"

#include <deque>
#include <iomanip>
#include <iostream>
#include <vector>

#include "perf_stats.h"
#include "difftest_checker.h"
#include "soc_dut_adapter.h"
#include "uart_checker.h"
#include "uart_decoder.h"
#include "uart_stimulus.h"

SimControl::SimControl(const SimConfig& config, SocDutAdapter& dut)
    : config_(config), dut_(dut) {}

SimResult SimControl::run() {
    SimResult result;
    PerfStats stats(config_);
    UartDecoder uart(config_.uart_cycles_per_bit);
    UartChecker checker(config_);
    UartStimulus uart_stimulus(
        config_.uart_command,
        config_.uart_cycles_per_bit);
    std::vector<std::string> uart_commands;
    if (!config_.uart_command.empty()) {
        uart_commands.push_back(config_.uart_command);
        uart_commands.insert(
            uart_commands.end(),
            config_.uart_followup_commands.begin(),
            config_.uart_followup_commands.end());
    }
    std::size_t uart_commands_sent = 0;
    DiffTestChecker difftest(config_);
    std::uint32_t last_commit_pc = 0;
    std::deque<ArchEvent> recent_arch_events;
    bool difftest_fault_injected = false;
    bool first_lsu_fault_seen = false;
    std::uint32_t first_lsu_fault_start = 0;
    std::uint32_t first_lsu_fault_end = 0;
    std::uint32_t first_lsu_fault_flags = 0;
    bool first_inst_candidate_seen = false;
    std::uint32_t first_inst_candidate_pc = 0;
    std::uint32_t first_inst_candidate_target = 0;
    std::uint32_t first_inst_candidate_flags = 0;

    const auto dump_debug_state = [&]() {
        std::cerr << "EH1 trap state: mepc=0x" << std::hex
                  << std::setw(8) << std::setfill('0') << dut_.debug_mepc()
                  << " mcause=0x" << std::setw(8) << dut_.debug_mcause()
                  << " mtval=0x" << std::setw(8) << dut_.debug_mtval()
                  << std::dec << std::setfill(' ') << "\n";
        if (first_lsu_fault_seen) {
            std::cerr << "First LSU fault: start=0x" << std::hex
                      << std::setw(8) << std::setfill('0')
                      << first_lsu_fault_start << " end=0x" << std::setw(8)
                      << first_lsu_fault_end << " flags=0b"
                      << ((first_lsu_fault_flags >> 3u) & 1u)
                      << ((first_lsu_fault_flags >> 2u) & 1u)
                      << ((first_lsu_fault_flags >> 1u) & 1u)
                      << (first_lsu_fault_flags & 1u)
                      << std::dec << std::setfill(' ') << "\n";
        }
        if (first_inst_candidate_seen) {
            std::cerr << "First IALIGN candidate: pc=0x" << std::hex
                      << std::setw(8) << std::setfill('0')
                      << first_inst_candidate_pc << " target=0x"
                      << std::setw(8) << first_inst_candidate_target
                      << " flags=0x" << std::setw(2)
                      << first_inst_candidate_flags << std::dec
                      << std::setfill(' ') << "\n";
        }
        std::cerr << "Recent retired instructions (oldest first):\n";
        for (const ArchEvent& event : recent_arch_events) {
            std::cerr << "  pc=0x" << std::hex << std::setw(8)
                      << std::setfill('0') << event.pc_rdata
                      << " insn=0x" << std::setw(8) << event.instruction
                      << std::dec << std::setfill(' ') << "\n";
        }
    };

    dut_.set_reset(false);
    dut_.set_uart_rx(true);
    for (std::uint64_t cycle = 0; cycle < config_.max_cycles; ++cycle) {
        if (cycle == 10) {
            dut_.set_reset(true);
        }
        dut_.set_uart_rx(uart_stimulus.level(cycle));
        dut_.step_cycle();
        const std::uint32_t lsu_flags = dut_.debug_lsu_flags();
        if (!first_lsu_fault_seen && (lsu_flags & 0xcu) != 0) {
            first_lsu_fault_seen = true;
            first_lsu_fault_start = dut_.debug_lsu_start();
            first_lsu_fault_end = dut_.debug_lsu_end();
            first_lsu_fault_flags = lsu_flags;
        }
        const std::uint32_t inst_flags = dut_.debug_inst_flags();
        if (!first_inst_candidate_seen &&
            (((inst_flags & 0x9u) == 0x9u) || (inst_flags & 0x2u))) {
            first_inst_candidate_seen = true;
            first_inst_candidate_pc = dut_.debug_inst_pc();
            first_inst_candidate_target = dut_.debug_inst_target();
            first_inst_candidate_flags = inst_flags;
        }
        char decoded_byte = '\0';
        if (uart.sample(dut_.uart_tx(), decoded_byte)) {
            std::cout << decoded_byte << std::flush;
            checker.observe(decoded_byte, cycle);
            if (uart_commands_sent < uart_commands.size() &&
                checker.prompt_count() > uart_commands_sent &&
                (!uart_stimulus.started() ||
                 uart_stimulus.finished(cycle))) {
                if (uart_commands_sent != 0) {
                    uart_stimulus.load(
                        uart_commands[uart_commands_sent]);
                }
                const std::uint64_t command_cycle =
                    cycle + config_.uart_cycles_per_bit;
                uart_stimulus.start(command_cycle);
                checker.mark_command_sent(command_cycle);
                ++uart_commands_sent;
            }
        }
        if (uart.framing_error()) {
            checker.mark_framing_error();
        }
        std::vector<ArchEvent> arch_events = dut_.arch_events();
        const std::vector<IrqEvent> irq_events = dut_.irq_events();
        std::uint32_t retired_count = dut_.retired_count();
        for (const ArchEvent& event : arch_events) {
            if (event.valid) {
                last_commit_pc = event.pc_rdata;
                recent_arch_events.push_back(event);
                if (recent_arch_events.size() > 32) {
                    recent_arch_events.pop_front();
                }
            }
        }
        if (!difftest_fault_injected &&
            !config_.difftest_fault_kind.empty()) {
            for (ArchEvent& event : arch_events) {
                if (!event.valid ||
                    event.order < config_.difftest_fault_order) {
                    continue;
                }
                if (config_.difftest_fault_kind == "order") {
                    ++event.order;
                } else if (config_.difftest_fault_kind == "pc") {
                    event.pc_wdata ^= 4u;
                } else if (config_.difftest_fault_kind == "rd") {
                    if (!event.retired || !event.rd_wen) {
                        continue;
                    }
                    event.rd_wdata ^= 1u;
                } else if (config_.difftest_fault_kind == "mem") {
                    if (!event.mem_valid) {
                        continue;
                    }
                    if (event.mem_wmask != 0) {
                        event.mem_wmask ^= 1u;
                    } else {
                        event.mem_rmask ^= 1u;
                    }
                }
                difftest_fault_injected = true;
                std::cerr << "\nDiffTest self-test injected "
                          << config_.difftest_fault_kind
                          << " fault at order " << event.order << "\n";
                break;
            }
        }
        difftest.observe_cycle(cycle, arch_events, irq_events);
        stats.observe(cycle, retired_count, dut_.test_code());

        if (!difftest.passed()) {
            std::cerr << "\nDIFF_MISMATCH: "
                      << difftest.snapshot().failure_kind << ": "
                      << difftest.snapshot().failure_message << "\n";
            result.status = "DIFF_MISMATCH";
            result.exit_reason =
                "difftest_" + difftest.snapshot().failure_kind;
            result.cycles = cycle;
            break;
        }

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
            if (passed && !checker.output_complete()) {
                if (cycle + 1 == config_.max_cycles) {
                    std::cerr << "\nTIMEOUT waiting for configured UART output after "
                              << config_.max_cycles << " cycles\n";
                    dump_debug_state();
                    result.status = "TIMEOUT";
                    result.exit_reason = "uart_output_timeout";
                    result.cycles = config_.max_cycles;
                    break;
                }
                continue;
            }
            std::cout << "\n" << (passed ? "PASS" : "FAIL")
                      << ": test_code=" << dut_.test_code()
                      << " cycles=" << cycle << "\n";
            if (!passed) {
                dump_debug_state();
            }
            result.status = passed ? "PASS" : "FAIL";
            result.exit_reason = "test_status";
            result.cycles = cycle;
            result.test_code = dut_.test_code();
            break;
        }
        if (!config_.uart_command.empty() &&
            !uart_stimulus.started() &&
            cycle >= config_.uart_prompt_timeout) {
            std::cerr << "\nFAIL: UART prompt `" << config_.uart_prompt
                      << "` not seen before cycle "
                      << config_.uart_prompt_timeout << "\n";
            result.status = "FAIL";
            result.exit_reason = "uart_prompt_timeout";
            result.cycles = cycle;
            break;
        }
        if (cycle + 1 == config_.max_cycles) {
            std::cerr << "\nTIMEOUT after " << config_.max_cycles
                      << " cycles\n";
            dump_debug_state();
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
    result.checker = checker.evaluate(
        result.status == "PASS",
        result.performance.complete);
    if (result.status == "PASS" && !result.checker.passed) {
        std::cerr << "\nFAIL: checker " << result.checker.name << ": "
                  << result.checker.message << "\n";
        result.status = "FAIL";
        result.exit_reason = "checker_failed";
    }
    difftest.finish();
    result.difftest = difftest.snapshot();
    dut_.finish();
    return result;
}
