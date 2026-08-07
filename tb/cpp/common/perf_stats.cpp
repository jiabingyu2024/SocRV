#include "perf_stats.h"

#include <stdexcept>

namespace {
MicroCounters subtract(
    const MicroCounters& end,
    const MicroCounters& start) {
    MicroCounters value;
#define SOCRV_DELTA(field) value.field = end.field - start.field
    SOCRV_DELTA(cycles);
    SOCRV_DELTA(commits);
    SOCRV_DELTA(branches);
    SOCRV_DELTA(branch_misses);
    SOCRV_DELTA(loads);
    SOCRV_DELTA(stores);
    SOCRV_DELTA(dcache_accesses);
    SOCRV_DELTA(dcache_misses);
    SOCRV_DELTA(stall_front);
    SOCRV_DELTA(stall_memory);
    SOCRV_DELTA(stall_muldiv);
    SOCRV_DELTA(stall_raw);
#undef SOCRV_DELTA
    return value;
}
}  // namespace

PerfStats::PerfStats(const SimConfig& config)
    : requested_(config.performance_enabled()),
      start_code_(config.perf_start_code),
      stop_code_(config.perf_stop_code),
      iterations_(config.benchmark_iterations),
      soc_hz_(config.soc_hz) {}

void PerfStats::observe(
    std::uint64_t cycle,
    std::uint32_t retired_count,
    std::uint32_t test_code,
    const MicroCounters& counters) {
    total_commits_ += retired_count;
    if (!requested_) {
        return;
    }
    if (!started_ && test_code == start_code_) {
        started_ = true;
        start_cycle_ = cycle;
        start_commits_ = total_commits_;
        start_counters_ = counters;
    } else if (started_ && !complete_ && test_code == stop_code_) {
        complete_ = true;
        end_cycle_ = cycle;
        end_commits_ = total_commits_;
        end_counters_ = counters;
    }
}

std::uint64_t PerfStats::total_commits() const {
    return total_commits_;
}

PerfSnapshot PerfStats::snapshot() const {
    PerfSnapshot value;
    value.requested = requested_;
    value.complete = complete_;
    value.iterations = iterations_;
    if (!complete_) {
        return value;
    }
    value.start_cycle = start_cycle_;
    value.end_cycle = end_cycle_;
    value.cycles = end_cycle_ - start_cycle_;
    value.commits = end_commits_ - start_commits_;
    value.microarchitecture = subtract(end_counters_, start_counters_);
    if (value.microarchitecture.cycles != value.cycles) {
        throw std::runtime_error(
            "hardware performance cycle counter disagrees with harness window");
    }
    if (value.microarchitecture.commits != value.commits) {
        throw std::runtime_error(
            "hardware performance commit counter disagrees with commit trace");
    }
    if (value.cycles != 0) {
        value.ipc = static_cast<double>(value.commits) /
                    static_cast<double>(value.cycles);
    }
    if (soc_hz_ != 0) {
        value.seconds = static_cast<double>(value.cycles) /
                        static_cast<double>(soc_hz_);
    }
    if (iterations_ != 0) {
        value.cycles_per_iteration =
            static_cast<double>(value.cycles) /
            static_cast<double>(iterations_);
        value.commits_per_iteration =
            static_cast<double>(value.commits) /
            static_cast<double>(iterations_);
    }
    if (value.seconds != 0.0) {
        value.iterations_per_second =
            static_cast<double>(iterations_) / value.seconds;
    }
    return value;
}
