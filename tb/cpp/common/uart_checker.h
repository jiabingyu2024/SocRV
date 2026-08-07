#ifndef SOCRV_TB_UART_CHECKER_H
#define SOCRV_TB_UART_CHECKER_H

#include <cstdint>
#include <string>
#include <vector>

#include "sim_config.h"

struct UartCheckSnapshot {
    std::string name;
    bool passed = false;
    std::string message;
    bool prompt_seen = false;
    std::uint64_t prompt_cycle = 0;
    std::uint64_t prompt_count = 0;
    bool command_sent = false;
    std::uint64_t command_cycle = 0;
    bool command_complete = false;
    bool framing_error = false;
    std::uint64_t decoded_bytes = 0;
    std::vector<std::string> missing;
    std::vector<std::string> forbidden_seen;
};

class UartChecker {
public:
    explicit UartChecker(const SimConfig& config);

    void observe(char byte, std::uint64_t cycle);
    void mark_command_sent(std::uint64_t cycle);
    void mark_framing_error();

    bool prompt_seen() const;
    std::uint64_t prompt_count() const;
    bool command_complete() const;
    UartCheckSnapshot evaluate(
        bool test_passed,
        bool performance_complete) const;

private:
    bool contains_number_after(const std::string& prefix) const;

    const SimConfig& config_;
    std::string transcript_;
    bool prompt_seen_ = false;
    std::uint64_t prompt_cycle_ = 0;
    std::uint64_t prompt_count_ = 0;
    bool command_sent_ = false;
    std::uint64_t command_cycle_ = 0;
    bool framing_error_ = false;
};

#endif
