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
};

#endif
