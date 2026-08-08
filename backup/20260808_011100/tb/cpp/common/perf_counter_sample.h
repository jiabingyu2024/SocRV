#ifndef SOCRV_TB_PERF_COUNTER_SAMPLE_H
#define SOCRV_TB_PERF_COUNTER_SAMPLE_H

#include <cstdint>

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
    bool rename_no_physreg = false;
    bool rename_no_iq = false;
    bool rename_no_rob = false;
    bool rename_no_lsq = false;
    bool rename_serialize = false;
    std::uint32_t dispatch_count = 0;
    std::uint32_t issue_count = 0;
};

#endif
