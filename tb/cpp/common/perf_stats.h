#ifndef SOCRV_TB_PERF_STATS_H
#define SOCRV_TB_PERF_STATS_H

#include <cstdint>

#include "sim_config.h"

struct MicroCounters {
    std::uint64_t cycles = 0;
    std::uint64_t commits = 0;
    std::uint64_t branches = 0;
    std::uint64_t branch_misses = 0;
    std::uint64_t loads = 0;
    std::uint64_t stores = 0;
    std::uint64_t dcache_accesses = 0;
    std::uint64_t dcache_misses = 0;
    std::uint64_t stall_front = 0;
    std::uint64_t stall_memory = 0;
    std::uint64_t stall_muldiv = 0;
    std::uint64_t stall_raw = 0;
};

struct PerfSnapshot {
    bool requested = false;
    bool complete = false;
    std::uint64_t start_cycle = 0;
    std::uint64_t end_cycle = 0;
    std::uint64_t cycles = 0;
    std::uint64_t commits = 0;
    std::uint64_t iterations = 0;
    double ipc = 0.0;
    double seconds = 0.0;
    double cycles_per_iteration = 0.0;
    double commits_per_iteration = 0.0;
    double iterations_per_second = 0.0;
    MicroCounters microarchitecture;
};

class PerfStats {
public:
    explicit PerfStats(const SimConfig& config);
    void observe(
        std::uint64_t cycle,
        std::uint32_t retired_count,
        std::uint32_t test_code,
        const MicroCounters& counters);
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
    MicroCounters start_counters_;
    MicroCounters end_counters_;
};

#endif
