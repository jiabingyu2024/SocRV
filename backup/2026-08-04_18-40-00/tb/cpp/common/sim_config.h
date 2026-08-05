#ifndef SOCRV_TB_SIM_CONFIG_H
#define SOCRV_TB_SIM_CONFIG_H

#include <cstdint>
#include <string>

struct SimConfig {
    std::uint64_t max_cycles = 200000;
    std::uint64_t benchmark_iterations = 0;
    std::uint64_t soc_hz = 50000000;
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

    static SimConfig parse(int argc, char** argv);
    bool performance_enabled() const;
};

#endif
