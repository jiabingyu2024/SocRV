#ifndef SOCRV_TB_SIM_RESULT_H
#define SOCRV_TB_SIM_RESULT_H

#include <cstdint>
#include <string>

#include "perf_stats.h"
#include "sim_config.h"
#include "uart_checker.h"

struct SimResult {
    std::string status = "NO_RESULT";
    std::string exit_reason = "no_result";
    std::uint64_t cycles = 0;
    std::uint64_t commits = 0;
    std::uint32_t test_code = 0;
    std::uint32_t last_commit_pc = 0;
    PerfSnapshot performance;
    UartCheckSnapshot checker;

    void write_json(const SimConfig& config) const;
    int exit_code() const;
};

#endif
