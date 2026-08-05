#include "sim_result.h"

#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

namespace {

std::string escape_json(const std::string& value) {
    std::ostringstream output;
    for (const char character : value) {
        switch (character) {
        case '\\': output << "\\\\"; break;
        case '"': output << "\\\""; break;
        case '\n': output << "\\n"; break;
        case '\r': output << "\\r"; break;
        case '\t': output << "\\t"; break;
        default: output << character; break;
        }
    }
    return output.str();
}

const char* boolean(bool value) {
    return value ? "true" : "false";
}

void write_string_array(
    std::ofstream& output,
    const std::vector<std::string>& values) {
    output << "[";
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) {
            output << ", ";
        }
        output << "\"" << escape_json(values[index]) << "\"";
    }
    output << "]";
}

}  // namespace

void SimResult::write_json(const SimConfig& config) const {
    if (config.result_path.empty()) {
        return;
    }
    std::ofstream output(config.result_path);
    if (!output) {
        throw std::runtime_error(
            "cannot open simulation result: " + config.result_path);
    }
    output << std::fixed << std::setprecision(9);
    output << "{\n"
           << "  \"schema_version\": 1,\n"
           << "  \"kind\": \"simulation\",\n"
           << "  \"target\": \"soc-verilator\",\n"
           << "  \"test\": \"" << escape_json(config.test_name) << "\",\n"
           << "  \"profile\": \"" << escape_json(config.profile) << "\",\n"
           << "  \"status\": \"" << status << "\",\n"
           << "  \"seed\": " << config.seed << ",\n"
           << "  \"cycles\": " << cycles << ",\n"
           << "  \"commits\": " << commits << ",\n"
           << "  \"ipc\": "
           << (cycles == 0 ? 0.0 :
               static_cast<double>(commits) / static_cast<double>(cycles))
           << ",\n"
           << "  \"exit_reason\": \"" << exit_reason << "\",\n"
           << "  \"max_cycles\": " << config.max_cycles << ",\n"
           << "  \"test_code\": " << test_code << ",\n"
           << "  \"last_commit_pc\": " << last_commit_pc << ",\n"
           << "  \"image\": \"" << escape_json(config.image_manifest)
           << "\",\n"
           << "  \"performance\": {\n"
           << "    \"requested\": " << boolean(performance.requested) << ",\n"
           << "    \"complete\": " << boolean(performance.complete) << ",\n"
           << "    \"iterations\": " << performance.iterations << ",\n";
    if (performance.complete) {
        output << "    \"start_cycle\": " << performance.start_cycle << ",\n"
               << "    \"end_cycle\": " << performance.end_cycle << ",\n"
               << "    \"cycles\": " << performance.cycles << ",\n"
               << "    \"commits\": " << performance.commits << ",\n"
               << "    \"ipc\": " << performance.ipc << ",\n"
               << "    \"seconds\": " << performance.seconds << ",\n"
               << "    \"cycles_per_iteration\": "
               << performance.cycles_per_iteration << ",\n"
               << "    \"commits_per_iteration\": "
               << performance.commits_per_iteration << ",\n"
               << "    \"iterations_per_second\": "
               << performance.iterations_per_second << "\n";
    } else {
        output << "    \"start_cycle\": null,\n"
               << "    \"end_cycle\": null,\n"
               << "    \"cycles\": null,\n"
               << "    \"commits\": null,\n"
               << "    \"ipc\": null,\n"
               << "    \"seconds\": null,\n"
               << "    \"cycles_per_iteration\": null,\n"
               << "    \"commits_per_iteration\": null,\n"
               << "    \"iterations_per_second\": null\n";
    }
    output << "  },\n"
           << "  \"checker\": {\n"
           << "    \"name\": \"" << escape_json(checker.name) << "\",\n"
           << "    \"passed\": " << boolean(checker.passed) << ",\n"
           << "    \"message\": \"" << escape_json(checker.message)
           << "\",\n"
           << "    \"prompt_seen\": " << boolean(checker.prompt_seen)
           << ",\n"
           << "    \"prompt_cycle\": ";
    if (checker.prompt_seen) {
        output << checker.prompt_cycle;
    } else {
        output << "null";
    }
    output << ",\n"
           << "    \"command_sent\": " << boolean(checker.command_sent)
           << ",\n"
           << "    \"command_cycle\": ";
    if (checker.command_sent) {
        output << checker.command_cycle;
    } else {
        output << "null";
    }
    output << ",\n"
           << "    \"framing_error\": "
           << boolean(checker.framing_error) << ",\n"
           << "    \"decoded_bytes\": " << checker.decoded_bytes << ",\n"
           << "    \"missing\": ";
    write_string_array(output, checker.missing);
    output << ",\n"
           << "    \"forbidden_seen\": ";
    write_string_array(output, checker.forbidden_seen);
    output << "\n"
           << "  },\n"
           << "  \"artifacts\": {\n"
           << "    \"log\": \"" << escape_json(config.log_path) << "\",\n"
           << "    \"wave\": ";
    if (config.trace_path.empty()) {
        output << "null\n";
    } else {
        output << "\"" << escape_json(config.trace_path) << "\"\n";
    }
    output << "  },\n"
           << "  \"failure\": ";
    if (status == "PASS") {
        output << "null,\n";
    } else {
        output << "{\n"
               << "    \"reason\": \"" << escape_json(exit_reason)
               << "\",\n"
               << "    \"message\": \"" << escape_json(checker.message)
               << "\"\n"
               << "  },\n";
    }
    output
           << "  \"reproduce\": \"" << escape_json(config.reproduce) << "\"\n"
           << "}\n";
}

int SimResult::exit_code() const {
    if (status == "PASS") {
        return 0;
    }
    if (status == "CONFIG_ERROR") {
        return 2;
    }
    return 1;
}
