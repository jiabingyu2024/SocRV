#include <verilated.h>
#include <verilated_vcd_c.h>

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>

#include "Vsoc_sim_top.h"

namespace {

struct Options {
    std::uint64_t max_cycles = 200000;
    std::string trace_path;
    std::string result_path;
    std::string test_name = "baremetal-smoke";
};

Options parse_options(int argc, char** argv) {
    Options options;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--max-cycles" && index + 1 < argc) {
            options.max_cycles = std::stoull(argv[++index]);
        } else if (argument == "--trace" && index + 1 < argc) {
            options.trace_path = argv[++index];
        } else if (argument == "--result" && index + 1 < argc) {
            options.result_path = argv[++index];
        } else if (argument == "--test" && index + 1 < argc) {
            options.test_name = argv[++index];
        }
    }
    return options;
}

class UartDecoder {
public:
    void sample(bool tx) {
        constexpr int divisor = 434;
        if (!receiving_) {
            if (!tx) {
                receiving_ = true;
                countdown_ = divisor + divisor / 2 - 1;
                bit_index_ = 0;
                byte_ = 0;
            }
            return;
        }
        if (countdown_ > 0) {
            --countdown_;
            return;
        }
        if (bit_index_ < 8) {
            if (tx) byte_ |= static_cast<std::uint8_t>(1u << bit_index_);
            ++bit_index_;
            countdown_ = divisor - 1;
        } else {
            if (tx) {
                std::cout << static_cast<char>(byte_) << std::flush;
            } else {
                std::cerr << "\nUART framing error\n";
            }
            receiving_ = false;
        }
    }

private:
    bool receiving_ = false;
    int countdown_ = 0;
    int bit_index_ = 0;
    std::uint8_t byte_ = 0;
};

void write_result(
    const std::string& path,
    const std::string& test_name,
    const std::string& status,
    std::uint64_t cycles,
    std::uint32_t code,
    std::uint32_t last_pc) {
    if (path.empty()) return;
    std::ofstream output(path);
    output << "{\n"
           << "  \"schema_version\": 1,\n"
           << "  \"kind\": \"simulation\",\n"
           << "  \"target\": \"soc-verilator\",\n"
           << "  \"test\": \"" << test_name << "\",\n"
           << "  \"status\": \"" << status << "\",\n"
           << "  \"cycles\": " << cycles << ",\n"
           << "  \"test_code\": " << code << ",\n"
           << "  \"last_commit_pc\": " << last_pc << "\n"
           << "}\n";
}

}  // namespace

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    const Options options = parse_options(argc, argv);
    auto context = std::make_unique<VerilatedContext>();
    context->commandArgs(argc, argv);
    context->traceEverOn(!options.trace_path.empty());
    auto dut = std::make_unique<Vsoc_sim_top>(context.get());
    std::unique_ptr<VerilatedVcdC> trace;
    if (!options.trace_path.empty()) {
        trace = std::make_unique<VerilatedVcdC>();
        dut->trace(trace.get(), 5);
        trace->open(options.trace_path.c_str());
    }

    dut->clk_i = 0;
    dut->rst_ni = 0;
    dut->uart_rx_i = 1;
    UartDecoder uart;
    std::uint32_t last_commit_pc = 0;

    for (std::uint64_t cycle = 0; cycle < options.max_cycles; ++cycle) {
        if (cycle == 10) dut->rst_ni = 1;
        for (int phase = 0; phase < 2; ++phase) {
            dut->clk_i = phase;
            dut->eval();
            if (trace) trace->dump(context->time());
            context->timeInc(1);
        }
        uart.sample(dut->uart_tx_o);
        if (dut->commit_valid_o) last_commit_pc = dut->commit_pc_o;

        if (dut->cpu_fault_o) {
            std::cerr << "\nFAIL: CPU bus fault at cycle " << cycle << "\n";
            write_result(options.result_path, options.test_name, "FAIL", cycle, 0xffffffffu, last_commit_pc);
            if (trace) trace->close();
            return 1;
        }
        if (dut->test_done_o) {
            const bool passed = dut->test_pass_o;
            std::cout << "\n" << (passed ? "PASS" : "FAIL")
                      << ": test_code=" << dut->test_code_o
                      << " cycles=" << cycle << "\n";
            write_result(
                options.result_path,
                options.test_name,
                passed ? "PASS" : "FAIL",
                cycle,
                dut->test_code_o,
                last_commit_pc);
            if (trace) trace->close();
            return passed ? 0 : 1;
        }
    }

    std::cerr << "\nTIMEOUT after " << options.max_cycles << " cycles\n";
    write_result(options.result_path, options.test_name, "TIMEOUT", options.max_cycles, 0, last_commit_pc);
    if (trace) trace->close();
    return 2;
}
