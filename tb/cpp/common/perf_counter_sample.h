#ifndef SOCRV_TB_PERF_COUNTER_SAMPLE_H
#define SOCRV_TB_PERF_COUNTER_SAMPLE_H

#include <array>
#include <cstdint>

struct BranchEventSample {
    bool valid = false;
    bool mispred = false;
    bool conditional = false;
    std::uint32_t pc = 0;
};

struct PerfCounterSample {
    std::uint32_t icache_misses = 0;
    std::uint32_t load_misses = 0;
    std::uint32_t store_misses = 0;
    std::uint32_t branch_mispredicts = 0;
    std::uint32_t decode_branch_mispredicts = 0;
    std::uint32_t store_load_forwarding_failures = 0;
    std::uint32_t memory_dependency_mispredicts = 0;
    bool icache_stall = false;
    bool decode_stall = false;
    bool rename_stall = false;
    bool backend_stall = false;
    bool recovery_cycle = false;
    std::uint32_t recovery_phase = 0;
    bool recovery_to_phase = false;
    bool recovery_rmt = false;
    bool recovery_iq_return = false;
    bool recovery_replay_flush = false;
    bool recovery_wakeup_flush = false;
    bool recovery_unable_start = false;
    bool recovery_commit_exception = false;
    bool recovery_rw_exception = false;
    bool recovery_flush_all = false;
    bool recovery_active_list = false;
    std::array<BranchEventSample, 2> branch_events{};
    std::array<bool, 2> decode_flush_trigger{};
    std::array<std::uint32_t, 2> decode_branch_pc{};
    bool rename_no_physreg = false;
    bool rename_no_iq = false;
    bool rename_no_rob = false;
    bool rename_no_lsq = false;
    bool rename_serialize = false;
    std::uint32_t dispatch_count = 0;
    std::uint32_t issue_count = 0;
};

#endif
