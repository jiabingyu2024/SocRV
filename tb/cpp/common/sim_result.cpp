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

void write_branch_hotspots(
    std::ofstream& output,
    const std::vector<BranchHotspot>& hotspots) {
    output << "[";
    for (std::size_t index = 0; index < hotspots.size(); ++index) {
        if (index != 0) {
            output << ",";
        }
        const BranchHotspot& hotspot = hotspots[index];
        output << "\n      {\"pc\": " << hotspot.pc
               << ", \"executed\": " << hotspot.executed
               << ", \"mispredicts\": " << hotspot.mispredicts
               << ", \"conditional_mispredicts\": "
               << hotspot.conditional_mispredicts
               << ", \"decode_corrections\": "
               << hotspot.decode_corrections << "}";
    }
    if (!hotspots.empty()) {
        output << "\n    ";
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
               << "    \"zero_retire_cycles\": "
               << performance.zero_retire_cycles << ",\n"
               << "    \"single_retire_cycles\": "
               << performance.single_retire_cycles << ",\n"
               << "    \"dual_retire_cycles\": "
               << performance.dual_retire_cycles << ",\n"
               << "    \"hpm_icache_misses\": "
               << performance.hpm_icache_misses << ",\n"
               << "    \"hpm_load_misses\": "
               << performance.hpm_load_misses << ",\n"
               << "    \"hpm_store_misses\": "
               << performance.hpm_store_misses << ",\n"
               << "    \"hpm_branch_mispredicts\": "
               << performance.hpm_branch_mispredicts << ",\n"
               << "    \"hpm_decode_branch_mispredicts\": "
               << performance.hpm_decode_branch_mispredicts << ",\n"
               << "    \"hpm_store_load_forwarding_failures\": "
               << performance.hpm_store_load_forwarding_failures << ",\n"
               << "    \"hpm_memory_dependency_mispredicts\": "
               << performance.hpm_memory_dependency_mispredicts << ",\n"
               << "    \"stall_icache_cycles\": "
               << performance.stall_icache_cycles << ",\n"
               << "    \"stall_decode_cycles\": "
               << performance.stall_decode_cycles << ",\n"
               << "    \"stall_rename_cycles\": "
               << performance.stall_rename_cycles << ",\n"
               << "    \"stall_backend_cycles\": "
               << performance.stall_backend_cycles << ",\n"
               << "    \"recovery_cycles\": "
               << performance.recovery_cycles << ",\n"
               << "    \"recovery_phase0_cycles\": "
               << performance.recovery_phase0_cycles << ",\n"
               << "    \"recovery_phase1_cycles\": "
               << performance.recovery_phase1_cycles << ",\n"
               << "    \"recovery_start_cycles\": "
               << performance.recovery_start_cycles << ",\n"
               << "    \"recovery_rmt_cycles\": "
               << performance.recovery_rmt_cycles << ",\n"
               << "    \"recovery_iq_return_cycles\": "
               << performance.recovery_iq_return_cycles << ",\n"
               << "    \"recovery_replay_flush_cycles\": "
               << performance.recovery_replay_flush_cycles << ",\n"
               << "    \"recovery_wakeup_flush_cycles\": "
               << performance.recovery_wakeup_flush_cycles << ",\n"
               << "    \"recovery_unable_start_cycles\": "
               << performance.recovery_unable_start_cycles << ",\n"
               << "    \"recovery_commit_exception_cycles\": "
               << performance.recovery_commit_exception_cycles << ",\n"
               << "    \"recovery_rw_exception_cycles\": "
               << performance.recovery_rw_exception_cycles << ",\n"
               << "    \"recovery_flush_all_cycles\": "
               << performance.recovery_flush_all_cycles << ",\n"
               << "    \"recovery_active_list_cycles\": "
               << performance.recovery_active_list_cycles << ",\n"
               << "    \"observed_branch_events\": "
               << performance.observed_branch_events << ",\n"
               << "    \"observed_branch_mispredicts\": "
               << performance.observed_branch_mispredicts << ",\n"
               << "    \"observed_conditional_mispredicts\": "
               << performance.observed_conditional_mispredicts << ",\n"
               << "    \"observed_decode_corrections\": "
               << performance.observed_decode_corrections << ",\n"
               << "    \"branch_mispredict_hotspots\": ";
        write_branch_hotspots(
            output,
            performance.branch_mispredict_hotspots);
        output << ",\n"
               << "    \"rename_no_physreg_cycles\": "
               << performance.rename_no_physreg_cycles << ",\n"
               << "    \"rename_no_iq_cycles\": "
               << performance.rename_no_iq_cycles << ",\n"
               << "    \"rename_no_rob_cycles\": "
               << performance.rename_no_rob_cycles << ",\n"
               << "    \"rename_no_lsq_cycles\": "
               << performance.rename_no_lsq_cycles << ",\n"
               << "    \"rename_serialize_cycles\": "
               << performance.rename_serialize_cycles << ",\n"
               << "    \"zero_dispatch_cycles\": "
               << performance.zero_dispatch_cycles << ",\n"
               << "    \"single_dispatch_cycles\": "
               << performance.single_dispatch_cycles << ",\n"
               << "    \"dual_dispatch_cycles\": "
               << performance.dual_dispatch_cycles << ",\n"
               << "    \"zero_issue_cycles\": "
               << performance.zero_issue_cycles << ",\n"
               << "    \"single_issue_cycles\": "
               << performance.single_issue_cycles << ",\n"
               << "    \"multi_issue_cycles\": "
               << performance.multi_issue_cycles << ",\n"
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
               << "    \"zero_retire_cycles\": null,\n"
               << "    \"single_retire_cycles\": null,\n"
               << "    \"dual_retire_cycles\": null,\n"
               << "    \"hpm_icache_misses\": null,\n"
               << "    \"hpm_load_misses\": null,\n"
               << "    \"hpm_store_misses\": null,\n"
               << "    \"hpm_branch_mispredicts\": null,\n"
               << "    \"hpm_decode_branch_mispredicts\": null,\n"
               << "    \"hpm_store_load_forwarding_failures\": null,\n"
               << "    \"hpm_memory_dependency_mispredicts\": null,\n"
               << "    \"stall_icache_cycles\": null,\n"
               << "    \"stall_decode_cycles\": null,\n"
               << "    \"stall_rename_cycles\": null,\n"
               << "    \"stall_backend_cycles\": null,\n"
               << "    \"recovery_cycles\": null,\n"
               << "    \"recovery_phase0_cycles\": null,\n"
               << "    \"recovery_phase1_cycles\": null,\n"
               << "    \"recovery_start_cycles\": null,\n"
               << "    \"recovery_rmt_cycles\": null,\n"
               << "    \"recovery_iq_return_cycles\": null,\n"
               << "    \"recovery_replay_flush_cycles\": null,\n"
               << "    \"recovery_wakeup_flush_cycles\": null,\n"
               << "    \"recovery_unable_start_cycles\": null,\n"
               << "    \"recovery_commit_exception_cycles\": null,\n"
               << "    \"recovery_rw_exception_cycles\": null,\n"
               << "    \"recovery_flush_all_cycles\": null,\n"
               << "    \"recovery_active_list_cycles\": null,\n"
               << "    \"observed_branch_events\": null,\n"
               << "    \"observed_branch_mispredicts\": null,\n"
               << "    \"observed_conditional_mispredicts\": null,\n"
               << "    \"observed_decode_corrections\": null,\n"
               << "    \"branch_mispredict_hotspots\": null,\n"
               << "    \"rename_no_physreg_cycles\": null,\n"
               << "    \"rename_no_iq_cycles\": null,\n"
               << "    \"rename_no_rob_cycles\": null,\n"
               << "    \"rename_no_lsq_cycles\": null,\n"
               << "    \"rename_serialize_cycles\": null,\n"
               << "    \"zero_dispatch_cycles\": null,\n"
               << "    \"single_dispatch_cycles\": null,\n"
               << "    \"dual_dispatch_cycles\": null,\n"
               << "    \"zero_issue_cycles\": null,\n"
               << "    \"single_issue_cycles\": null,\n"
               << "    \"multi_issue_cycles\": null,\n"
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
           << "    \"prompt_count\": " << checker.prompt_count << ",\n"
           << "    \"command_sent\": " << boolean(checker.command_sent)
           << ",\n"
           << "    \"command_cycle\": ";
    if (checker.command_sent) {
        output << checker.command_cycle;
    } else {
        output << "null";
    }
    output << ",\n"
           << "    \"command_complete\": "
           << boolean(checker.command_complete) << ",\n"
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
           << "  \"difftest\": {\n"
           << "    \"enabled\": " << boolean(difftest.enabled) << ",\n"
           << "    \"passed\": " << boolean(difftest.passed) << ",\n"
           << "    \"backend\": \"" << escape_json(difftest.backend)
           << "\",\n"
           << "    \"backend_version\": \""
           << escape_json(difftest.backend_version) << "\",\n"
           << "    \"mode\": \"" << escape_json(difftest.mode) << "\",\n"
           << "    \"isa\": \"" << escape_json(difftest.isa) << "\",\n"
           << "    \"compared_events\": " << difftest.compared_events << ",\n"
           << "    \"retired_instructions\": "
           << difftest.retired_instructions << ",\n"
           << "    \"mmio_syncs\": " << difftest.mmio_syncs << ",\n"
           << "    \"last_order\": ";
    if (difftest.has_last_order) {
        output << difftest.last_order;
    } else {
        output << "null";
    }
    output << ",\n"
           << "    \"log\": ";
    if (difftest.enabled) {
        output << "\"" << escape_json(difftest.log_path) << "\"";
    } else {
        output << "null";
    }
    output << ",\n"
           << "    \"trace\": ";
    if (difftest.enabled) {
        output << "\"" << escape_json(difftest.trace_path) << "\"";
    } else {
        output << "null";
    }
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
               << "    \"message\": \""
               << escape_json(
                      status == "DIFF_MISMATCH"
                          ? difftest.failure_message
                          : checker.message)
               << "\"";
        if (status == "DIFF_MISMATCH") {
            output << ",\n"
                   << "    \"kind\": \""
                   << escape_json(difftest.failure_kind) << "\",\n"
                   << "    \"cycle\": " << difftest.failure_cycle << ",\n"
                   << "    \"order\": " << difftest.failure_order << "\n";
        } else {
            output << "\n";
        }
        output
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
