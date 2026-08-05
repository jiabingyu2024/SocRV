#include "sim_config.h"

#include <stdexcept>
#include <sstream>

namespace {

const char* require_value(int argc, char** argv, int& index) {
    if (index + 1 >= argc) {
        throw std::invalid_argument(
            std::string("missing value for ") + argv[index]);
    }
    return argv[++index];
}

DiffMemoryRegion parse_difftest_region(const std::string& value) {
    std::vector<std::string> fields;
    std::istringstream input(value);
    std::string field;
    while (std::getline(input, field, ',')) {
        fields.push_back(field);
    }
    if (fields.size() != 5) {
        throw std::invalid_argument(
            "--difftest-region requires name,base,size,kind,image");
    }
    DiffMemoryRegion region;
    region.name = fields[0];
    region.base = static_cast<std::uint32_t>(
        std::stoul(fields[1], nullptr, 0));
    region.size = static_cast<std::uint32_t>(
        std::stoul(fields[2], nullptr, 0));
    if (fields[3] == "ram") {
        region.mmio = false;
    } else if (fields[3] == "mmio") {
        region.mmio = true;
    } else {
        throw std::invalid_argument(
            "DiffTest region kind must be ram or mmio");
    }
    if (fields[4] != "-") {
        region.image_path = fields[4];
    }
    return region;
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
        } else if (argument == "--difftest") {
            config.difftest_enabled = true;
        } else if (argument == "--difftest-backend") {
            config.difftest_backend = require_value(argc, argv, index);
        } else if (argument == "--difftest-backend-version") {
            config.difftest_backend_version =
                require_value(argc, argv, index);
        } else if (argument == "--difftest-mode") {
            config.difftest_mode = require_value(argc, argv, index);
        } else if (argument == "--difftest-isa") {
            config.difftest_isa = require_value(argc, argv, index);
        } else if (argument == "--difftest-log") {
            config.difftest_log_path = require_value(argc, argv, index);
        } else if (argument == "--difftest-trace") {
            config.difftest_trace_path = require_value(argc, argv, index);
        } else if (argument == "--difftest-reference-trace") {
            config.difftest_reference_trace_path =
                require_value(argc, argv, index);
        } else if (argument == "--difftest-fault") {
            const std::string value = require_value(argc, argv, index);
            const std::size_t separator = value.find('@');
            if (separator == std::string::npos) {
                throw std::invalid_argument(
                    "--difftest-fault requires KIND@ORDER");
            }
            config.difftest_fault_kind = value.substr(0, separator);
            config.difftest_fault_order = std::stoull(
                value.substr(separator + 1), nullptr, 0);
        } else if (argument == "--difftest-reset-pc") {
            config.difftest_reset_pc = static_cast<std::uint32_t>(
                std::stoul(require_value(argc, argv, index), nullptr, 0));
        } else if (argument == "--difftest-reset-mtvec") {
            config.difftest_reset_mtvec = static_cast<std::uint32_t>(
                std::stoul(require_value(argc, argv, index), nullptr, 0));
        } else if (argument == "--difftest-region") {
            config.difftest_regions.push_back(parse_difftest_region(
                require_value(argc, argv, index)));
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
    if (config.difftest_enabled) {
        if (config.difftest_backend != "spike") {
            throw std::invalid_argument(
                "only the spike DiffTest backend is supported");
        }
        if (config.difftest_mode != "ram-strict" &&
            config.difftest_mode != "soc-mmio") {
            throw std::invalid_argument(
                "DiffTest mode must be ram-strict or soc-mmio");
        }
        if (config.difftest_log_path.empty() ||
            config.difftest_trace_path.empty()) {
            throw std::invalid_argument(
                "DiffTest log and trace paths are required");
        }
        if (config.difftest_regions.empty()) {
            throw std::invalid_argument(
                "at least one DiffTest memory region is required");
        }
        if (!config.difftest_fault_kind.empty() &&
            config.difftest_fault_kind != "order" &&
            config.difftest_fault_kind != "pc" &&
            config.difftest_fault_kind != "rd" &&
            config.difftest_fault_kind != "mem") {
            throw std::invalid_argument(
                "DiffTest fault kind must be order, pc, rd, or mem");
        }
    }
    return config;
}

bool SimConfig::performance_enabled() const {
    return perf_start_code != 0 && perf_stop_code != 0;
}
