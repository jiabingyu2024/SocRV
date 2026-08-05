#include "difftest_checker.h"

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

#include "reference_model.h"
#include "sim_config.h"

namespace {

std::string hex32(std::uint32_t value) {
    std::ostringstream output;
    output << "0x" << std::hex << std::setw(8) << std::setfill('0') << value;
    return output.str();
}

std::string describe_commit(std::uint64_t cycle, const ArchEvent& event) {
    std::ostringstream output;
    output << "{\"type\":\"commit\",\"cycle\":" << cycle
           << ",\"order\":" << event.order
           << ",\"retired\":" << (event.retired ? "true" : "false")
           << ",\"pc\":\"" << hex32(event.pc_rdata)
           << "\",\"next_pc\":\"" << hex32(event.pc_wdata)
           << "\",\"insn\":\"" << hex32(event.instruction)
           << "\",\"rd\":" << (event.rd_wen ? event.rd_addr : 0)
           << ",\"rd_value\":\"" << hex32(event.rd_wdata) << "\""
           << ",\"trap\":" << (event.sync_trap ? "true" : "false")
           << ",\"cause\":\"" << hex32(event.cause) << "\"";
    if (event.mem_valid) {
        output << ",\"mem\":{\"addr\":\"" << hex32(event.mem_addr)
               << "\",\"rmask\":" << event.mem_rmask
               << ",\"wmask\":" << event.mem_wmask
               << ",\"rdata\":\"" << hex32(event.mem_rdata)
               << "\",\"wdata\":\"" << hex32(event.mem_wdata) << "\"}";
    }
    output << "}";
    return output.str();
}

std::string describe_irq(std::uint64_t cycle, const IrqEvent& event) {
    std::ostringstream output;
    output << "{\"type\":\"irq\",\"cycle\":" << cycle
           << ",\"next_order\":" << event.next_order
           << ",\"mip_pre\":\"" << hex32(event.mip_pre)
           << "\",\"mip_post\":\"" << hex32(event.mip_post) << "\"}";
    return output.str();
}

}  // namespace

DiffTestChecker::DiffTestChecker(const SimConfig& config) {
    snapshot_.enabled = config.difftest_enabled;
    snapshot_.backend = config.difftest_backend;
    snapshot_.backend_version = config.difftest_backend_version;
    snapshot_.mode = config.difftest_mode;
    snapshot_.isa = config.difftest_isa;
    snapshot_.log_path = config.difftest_log_path;
    snapshot_.trace_path = config.difftest_trace_path;
    if (!snapshot_.enabled) {
        return;
    }
    if (!spike_reference_available()) {
        throw std::runtime_error(
            "this Verilator model was built without Spike support");
    }
    ReferenceConfig reference_config;
    reference_config.backend = config.difftest_backend;
    reference_config.backend_version = config.difftest_backend_version;
    reference_config.mode = config.difftest_mode;
    reference_config.isa = config.difftest_isa;
    reference_config.reference_trace_path = config.difftest_reference_trace_path;
    reference_config.reset_pc = config.difftest_reset_pc;
    reference_config.reset_mtvec = config.difftest_reset_mtvec;
    reference_config.regions = config.difftest_regions;
    reference_ = create_reference_model(reference_config);
}

DiffTestChecker::~DiffTestChecker() = default;

void DiffTestChecker::observe_cycle(
    std::uint64_t cycle,
    const std::vector<ArchEvent>& events,
    const std::vector<IrqEvent>& irq_events) {
    if (!enabled() || !passed()) {
        return;
    }
    for (const IrqEvent& event : irq_events) {
        if (!event.valid) {
            continue;
        }
        remember(describe_irq(cycle, event));
        reference_->notify_irq(event);
    }

    std::vector<ArchEvent> ordered = events;
    std::sort(
        ordered.begin(),
        ordered.end(),
        [](const ArchEvent& lhs, const ArchEvent& rhs) {
            return lhs.order < rhs.order;
        });
    for (const ArchEvent& event : ordered) {
        if (!event.valid) {
            continue;
        }
        remember(describe_commit(cycle, event));
        if (expected_order_valid_ && event.order != expected_order_) {
            fail(
                cycle,
                event.order,
                "ORDER",
                "expected commit order " + std::to_string(expected_order_) +
                    ", got " + std::to_string(event.order));
            return;
        }
        expected_order_ = event.order + 1;
        expected_order_valid_ = true;
        snapshot_.last_order = event.order;
        snapshot_.has_last_order = true;
        ++snapshot_.compared_events;
        if (event.retired) {
            ++snapshot_.retired_instructions;
        }
        const ReferenceStepOutcome outcome = reference_->step(event);
        snapshot_.mmio_syncs = outcome.mmio_syncs;
        if (!outcome.passed) {
            fail(
                cycle,
                event.order,
                outcome.kind.empty() ? "REFERENCE_ERROR" : outcome.kind,
                outcome.message);
            return;
        }
    }
}

void DiffTestChecker::finish() {
    if (!enabled()) {
        return;
    }
    write_artifacts(true);
}

bool DiffTestChecker::enabled() const {
    return snapshot_.enabled;
}

bool DiffTestChecker::passed() const {
    return snapshot_.passed;
}

const DiffTestSnapshot& DiffTestChecker::snapshot() const {
    return snapshot_;
}

void DiffTestChecker::fail(
    std::uint64_t cycle,
    std::uint64_t order,
    const std::string& kind,
    const std::string& message) {
    snapshot_.passed = false;
    snapshot_.failure_cycle = cycle;
    snapshot_.failure_order = order;
    snapshot_.failure_kind = kind;
    snapshot_.failure_message = message;
    write_artifacts(false);
}

void DiffTestChecker::remember(const std::string& line) {
    commit_history_.push_back(line);
    if (commit_history_.size() > 64) {
        commit_history_.pop_front();
    }
    if (line.find("\"mem\"") != std::string::npos) {
        memory_history_.push_back(line);
        if (memory_history_.size() > 32) {
            memory_history_.pop_front();
        }
    }
}

void DiffTestChecker::write_artifacts(bool final) {
    if (snapshot_.log_path.empty() || snapshot_.trace_path.empty()) {
        return;
    }
    {
        std::ofstream trace(snapshot_.trace_path);
        if (!trace) {
            throw std::runtime_error(
                "cannot open DiffTest trace: " + snapshot_.trace_path);
        }
        for (const std::string& line : commit_history_) {
            trace << line << "\n";
        }
    }
    {
        std::ofstream log(snapshot_.log_path);
        if (!log) {
            throw std::runtime_error(
                "cannot open DiffTest log: " + snapshot_.log_path);
        }
        log << "backend: " << snapshot_.backend << "\n"
            << "backend_version: " << snapshot_.backend_version << "\n"
            << "mode: " << snapshot_.mode << "\n"
            << "isa: " << snapshot_.isa << "\n"
            << "status: " << (snapshot_.passed ? "PASS" : "DIFF_MISMATCH")
            << "\n"
            << "compared_events: " << snapshot_.compared_events << "\n"
            << "retired_instructions: " << snapshot_.retired_instructions
            << "\n"
            << "mmio_syncs: " << snapshot_.mmio_syncs << "\n";
        if (!snapshot_.passed) {
            log << "failure_cycle: " << snapshot_.failure_cycle << "\n"
                << "failure_order: " << snapshot_.failure_order << "\n"
                << "failure_kind: " << snapshot_.failure_kind << "\n"
                << "failure_message: " << snapshot_.failure_message << "\n";
        } else if (!final) {
            log << "status_detail: checker still running\n";
        }
        log << "trace: " << snapshot_.trace_path << "\n";
    }
    artifacts_written_ = true;
}
