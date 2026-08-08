#ifndef SOCRV_TB_PERF_STATS_H
#define SOCRV_TB_PERF_STATS_H

#include <cstdint>
#include <unordered_map>
#include <vector>

#include "sim_config.h"
#include "perf_counter_sample.h"

struct BranchHotspot {
    std::uint32_t pc = 0;
    std::uint64_t executed = 0;
    std::uint64_t mispredicts = 0;
    std::uint64_t conditional_mispredicts = 0;
    std::uint64_t decode_corrections = 0;
};

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
    std::uint64_t stall_icache_cycles = 0;
    std::uint64_t stall_decode_cycles = 0;
    std::uint64_t stall_rename_cycles = 0;
    std::uint64_t stall_backend_cycles = 0;
    std::uint64_t recovery_cycles = 0;
    std::uint64_t recovery_phase0_cycles = 0;
    std::uint64_t recovery_phase1_cycles = 0;
    std::uint64_t recovery_start_cycles = 0;
    std::uint64_t recovery_rmt_cycles = 0;
    std::uint64_t recovery_iq_return_cycles = 0;
    std::uint64_t recovery_replay_flush_cycles = 0;
    std::uint64_t recovery_wakeup_flush_cycles = 0;
    std::uint64_t recovery_unable_start_cycles = 0;
    std::uint64_t recovery_commit_exception_cycles = 0;
    std::uint64_t recovery_rw_exception_cycles = 0;
    std::uint64_t recovery_flush_all_cycles = 0;
    std::uint64_t recovery_active_list_cycles = 0;
    std::uint64_t observed_branch_events = 0;
    std::uint64_t observed_branch_mispredicts = 0;
    std::uint64_t observed_conditional_mispredicts = 0;
    std::uint64_t observed_decode_corrections = 0;
    std::vector<BranchHotspot> branch_mispredict_hotspots;
    std::uint64_t rename_no_physreg_cycles = 0;
    std::uint64_t rename_no_iq_cycles = 0;
    std::uint64_t rename_no_rob_cycles = 0;
    std::uint64_t rename_no_lsq_cycles = 0;
    std::uint64_t rename_serialize_cycles = 0;
    std::uint64_t zero_dispatch_cycles = 0;
    std::uint64_t single_dispatch_cycles = 0;
    std::uint64_t dual_dispatch_cycles = 0;
    std::uint64_t zero_issue_cycles = 0;
    std::uint64_t single_issue_cycles = 0;
    std::uint64_t multi_issue_cycles = 0;
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
    std::uint64_t stall_icache_cycles_ = 0;
    std::uint64_t stall_decode_cycles_ = 0;
    std::uint64_t stall_rename_cycles_ = 0;
    std::uint64_t stall_backend_cycles_ = 0;
    std::uint64_t recovery_cycles_ = 0;
    std::uint64_t recovery_phase0_cycles_ = 0;
    std::uint64_t recovery_phase1_cycles_ = 0;
    std::uint64_t recovery_start_cycles_ = 0;
    std::uint64_t recovery_rmt_cycles_ = 0;
    std::uint64_t recovery_iq_return_cycles_ = 0;
    std::uint64_t recovery_replay_flush_cycles_ = 0;
    std::uint64_t recovery_wakeup_flush_cycles_ = 0;
    std::uint64_t recovery_unable_start_cycles_ = 0;
    std::uint64_t recovery_commit_exception_cycles_ = 0;
    std::uint64_t recovery_rw_exception_cycles_ = 0;
    std::uint64_t recovery_flush_all_cycles_ = 0;
    std::uint64_t recovery_active_list_cycles_ = 0;
    std::uint64_t observed_branch_events_ = 0;
    std::uint64_t observed_branch_mispredicts_ = 0;
    std::uint64_t observed_conditional_mispredicts_ = 0;
    std::uint64_t observed_decode_corrections_ = 0;
    std::unordered_map<std::uint32_t, BranchHotspot> branch_hotspots_;
    std::uint64_t rename_no_physreg_cycles_ = 0;
    std::uint64_t rename_no_iq_cycles_ = 0;
    std::uint64_t rename_no_rob_cycles_ = 0;
    std::uint64_t rename_no_lsq_cycles_ = 0;
    std::uint64_t rename_serialize_cycles_ = 0;
    std::uint64_t zero_dispatch_cycles_ = 0;
    std::uint64_t single_dispatch_cycles_ = 0;
    std::uint64_t dual_dispatch_cycles_ = 0;
    std::uint64_t zero_issue_cycles_ = 0;
    std::uint64_t single_issue_cycles_ = 0;
    std::uint64_t multi_issue_cycles_ = 0;
    PerfCounterSample start_perf_counters_;
    PerfCounterSample end_perf_counters_;
};

#endif
