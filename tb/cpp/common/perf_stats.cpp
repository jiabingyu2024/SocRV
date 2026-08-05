#include "perf_stats.h"

PerfStats::PerfStats(const SimConfig& config)
    : requested_(config.performance_enabled()),
      start_code_(config.perf_start_code),
      stop_code_(config.perf_stop_code),
      iterations_(config.benchmark_iterations),
      soc_hz_(config.soc_hz) {}

void PerfStats::observe(
    std::uint64_t cycle,
    std::uint32_t retired_count,
    std::uint32_t test_code) {
    total_commits_ += retired_count;
    if (!requested_) {
        return;
    }
    if (!started_ && test_code == start_code_) {
        started_ = true;
        start_cycle_ = cycle;
        start_commits_ = total_commits_;
    } else if (started_ && !complete_ && test_code == stop_code_) {
        complete_ = true;
        end_cycle_ = cycle;
        end_commits_ = total_commits_;
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
