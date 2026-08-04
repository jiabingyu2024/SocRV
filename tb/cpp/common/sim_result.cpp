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
           << "  \"artifacts\": {\n"
           << "    \"log\": \"" << escape_json(config.log_path) << "\",\n"
           << "    \"wave\": ";
    if (config.trace_path.empty()) {
        output << "null\n";
    } else {
        output << "\"" << escape_json(config.trace_path) << "\"\n";
    }
    output << "  },\n"
           << "  \"failure\": null,\n"
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
