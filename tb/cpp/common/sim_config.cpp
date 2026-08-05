#include "sim_config.h"

#include <stdexcept>

namespace {

const char* require_value(int argc, char** argv, int& index) {
    if (index + 1 >= argc) {
        throw std::invalid_argument(
            std::string("missing value for ") + argv[index]);
    }
    return argv[++index];
}

}  // namespace

SimConfig SimConfig::parse(int argc, char** argv) {
    SimConfig config;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--max-cycles") {
            config.max_cycles = std::stoull(
                require_value(argc, argv, index), nullptr, 0);
        } else if (argument == "--trace") {
            config.trace_path = require_value(argc, argv, index);
        } else if (argument == "--result") {
            config.result_path = require_value(argc, argv, index);
        } else if (argument == "--log") {
            config.log_path = require_value(argc, argv, index);
        } else if (argument == "--test") {
            config.test_name = require_value(argc, argv, index);
        } else if (argument == "--profile") {
            config.profile = require_value(argc, argv, index);
        } else if (argument == "--image-manifest") {
            config.image_manifest = require_value(argc, argv, index);
        } else if (argument == "--seed") {
            config.seed = static_cast<std::uint32_t>(std::stoul(
                require_value(argc, argv, index), nullptr, 0));
        } else if (argument == "--perf-start-code") {
            config.perf_start_code = static_cast<std::uint32_t>(std::stoul(
                require_value(argc, argv, index), nullptr, 0));
        } else if (argument == "--perf-stop-code") {
            config.perf_stop_code = static_cast<std::uint32_t>(std::stoul(
                require_value(argc, argv, index), nullptr, 0));
        } else if (argument == "--benchmark-iterations") {
            config.benchmark_iterations = std::stoull(
                require_value(argc, argv, index), nullptr, 0);
        } else if (argument == "--soc-hz") {
            config.soc_hz = std::stoull(
                require_value(argc, argv, index), nullptr, 0);
        } else if (argument == "--uart-command") {
            config.uart_command = require_value(argc, argv, index);
        } else if (argument == "--uart-prompt") {
            config.uart_prompt = require_value(argc, argv, index);
        } else if (argument == "--uart-prompt-timeout") {
            config.uart_prompt_timeout = std::stoull(
                require_value(argc, argv, index), nullptr, 0);
        } else if (argument == "--uart-cycles-per-bit") {
            config.uart_cycles_per_bit = std::stoull(
                require_value(argc, argv, index), nullptr, 0);
        } else if (argument == "--checker") {
            config.checker = require_value(argc, argv, index);
        } else if (argument == "--uart-expect") {
            config.uart_expect.emplace_back(
                require_value(argc, argv, index));
        } else if (argument == "--uart-reject") {
            config.uart_reject.emplace_back(
                require_value(argc, argv, index));
        } else if (argument == "--reproduce") {
            config.reproduce = require_value(argc, argv, index);
        } else if (!argument.empty() && argument.front() == '+') {
            // Verilog plusargs are consumed by the generated model.
        } else {
            throw std::invalid_argument("unknown argument: " + argument);
        }
    }
    if (config.max_cycles == 0) {
        throw std::invalid_argument("--max-cycles must be positive");
    }
    if ((config.perf_start_code == 0) != (config.perf_stop_code == 0)) {
        throw std::invalid_argument(
            "performance start and stop codes must be supplied together");
    }
    if (!config.uart_command.empty() &&
        config.uart_cycles_per_bit < 2u) {
        throw std::invalid_argument(
            "--uart-cycles-per-bit must be at least 2");
    }
    if (!config.uart_command.empty() &&
        config.uart_prompt.empty()) {
        throw std::invalid_argument(
            "--uart-prompt is required with --uart-command");
    }
    if (!config.uart_command.empty() &&
        config.uart_prompt_timeout == 0u) {
        throw std::invalid_argument(
            "--uart-prompt-timeout must be positive");
    }
    return config;
}

bool SimConfig::performance_enabled() const {
    return perf_start_code != 0 && perf_stop_code != 0;
}
