#ifndef SOCRV_TB_PERF_STATS_H
#define SOCRV_TB_PERF_STATS_H

#include <cstdint>

#include "sim_config.h"
#include "perf_counter_sample.h"

struct PerfSnapshot {
    bool requested = false;
    bool complete = false;
    std::uint64_t start_cycle = 0;
    std::uint64_t end_cycle = 0;
    std::uint64_t cycles = 0;
    std::uint64_t commits = 0;
    std::uint64_t zero_retire_cycles = 0;
    std::uint64_t single_retire_cycles = 0;
    std::uint64_t dual_retire_cycles = 0;
    std::uint64_t hpm_icache_misses = 0;
    std::uint64_t hpm_load_misses = 0;
    std::uint64_t hpm_store_misses = 0;
    std::uint64_t hpm_branch_mispredicts = 0;
    std::uint64_t hpm_decode_branch_mispredicts = 0;
    std::uint64_t hpm_store_load_forwarding_failures = 0;
    std::uint64_t hpm_memory_dependency_mispredicts = 0;
    std::uint64_t iterations = 0;
    double ipc = 0.0;
    double seconds = 0.0;
    double cycles_per_iteration = 0.0;
    double commits_per_iteration = 0.0;
    double iterations_per_second = 0.0;
};

class PerfStats {
public:
    explicit PerfStats(const SimConfig& config);
    void observe(
        std::uint64_t cycle,
        std::uint32_t retired_count,
        std::uint32_t test_code,
        const PerfCounterSample& perf_counters);
    std::uint64_t total_commits() const;
    PerfSnapshot snapshot() const;

private:
    bool requested_;
    bool started_ = false;
    bool complete_ = false;
    std::uint32_t start_code_;
    std::uint32_t stop_code_;
    std::uint64_t iterations_;
    std::uint64_t soc_hz_;
    std::uint64_t total_commits_ = 0;
    std::uint64_t start_cycle_ = 0;
    std::uint64_t end_cycle_ = 0;
    std::uint64_t start_commits_ = 0;
    std::uint64_t end_commits_ = 0;
    std::uint64_t zero_retire_cycles_ = 0;
    std::uint64_t single_retire_cycles_ = 0;
    std::uint64_t dual_retire_cycles_ = 0;
    PerfCounterSample start_perf_counters_;
    PerfCounterSample end_perf_counters_;
};

#endif
