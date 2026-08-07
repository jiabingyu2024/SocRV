#ifndef SOCRV_TB_SIM_CONFIG_H
#define SOCRV_TB_SIM_CONFIG_H

#include <cstdint>
#include <string>
#include <vector>

#include "difftest_types.h"

struct SimConfig {
    std::uint64_t max_cycles = 200000;
    std::uint64_t benchmark_iterations = 0;
    std::uint64_t soc_hz = 200000000;
    std::uint64_t uart_cycles_per_bit = 1736;
    std::uint64_t uart_prompt_timeout = 5000000;
    std::uint32_t perf_start_code = 0;
    std::uint32_t perf_stop_code = 0;
    std::uint32_t seed = 1;
    std::string trace_path;
    std::string result_path;
    std::string log_path;
    std::string image_manifest;
    std::string profile;
    std::string reproduce;
    std::string test_name = "baremetal-smoke";
    std::string uart_command;
    std::string uart_prompt = "msh >";
    std::string checker = "test-status";
    std::vector<std::string> uart_expect;
    std::vector<std::string> uart_reject;
    bool difftest_enabled = false;
    std::string difftest_backend = "spike";
    std::string difftest_backend_version;
    std::string difftest_mode = "ram-strict";
    std::string difftest_isa = "rv32im_zicsr_zicntr_zifencei";
    std::string difftest_log_path;
    std::string difftest_trace_path;
    std::string difftest_reference_trace_path;
    std::string difftest_fault_kind;
    std::uint64_t difftest_fault_order = 0;
    std::uint32_t difftest_reset_pc = 0;
    std::uint32_t difftest_reset_mtvec = 0;
    std::vector<DiffMemoryRegion> difftest_regions;

    static SimConfig parse(int argc, char** argv);
    bool performance_enabled() const;
};

#endif
