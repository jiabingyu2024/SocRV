#include "uart_checker.h"

#include <cctype>
#include <sstream>

namespace {

bool ends_with(const std::string& text, const std::string& suffix) {
    return text.size() >= suffix.size() &&
           text.compare(
               text.size() - suffix.size(),
               suffix.size(),
               suffix) == 0;
}

bool contains(const std::string& text, const std::string& pattern) {
    return text.find(pattern) != std::string::npos;
}

}  // namespace

UartChecker::UartChecker(const SimConfig& config)
    : config_(config) {}

void UartChecker::observe(char byte, std::uint64_t cycle) {
    transcript_.push_back(byte);
    if (!config_.uart_prompt.empty() &&
        ends_with(transcript_, config_.uart_prompt)) {
        ++prompt_count_;
        if (!prompt_seen_) {
            prompt_seen_ = true;
            prompt_cycle_ = cycle;
        }
    }
}

void UartChecker::mark_command_sent(std::uint64_t cycle) {
    command_sent_ = true;
    command_cycle_ = cycle;
}

void UartChecker::mark_framing_error() {
    framing_error_ = true;
}

bool UartChecker::prompt_seen() const {
    return prompt_seen_;
}

std::uint64_t UartChecker::prompt_count() const {
    return prompt_count_;
}

bool UartChecker::command_complete() const {
    return command_sent_ &&
           prompt_count_ >= 2 + config_.uart_followup_commands.size();
}

bool UartChecker::output_complete() const {
    if (!config_.uart_command.empty() && !command_complete()) {
        return false;
    }
    for (const std::string& expected : config_.uart_expect) {
        if (!contains(transcript_, expected)) {
            return false;
        }
    }
    return true;
}

bool UartChecker::contains_number_after(
    const std::string& prefix) const {
    const std::size_t position = transcript_.find(prefix);
    if (position == std::string::npos) {
        return false;
    }
    const std::size_t value_position = position + prefix.size();
    return value_position < transcript_.size() &&
           std::isdigit(
               static_cast<unsigned char>(transcript_[value_position]));
}

UartCheckSnapshot UartChecker::evaluate(
    bool test_passed,
    bool performance_complete) const {
    UartCheckSnapshot snapshot;
    snapshot.name = config_.checker;
    snapshot.prompt_seen = prompt_seen_;
    snapshot.prompt_cycle = prompt_cycle_;
    snapshot.prompt_count = prompt_count_;
    snapshot.command_sent = command_sent_;
    snapshot.command_cycle = command_cycle_;
    snapshot.command_complete = command_complete();
    snapshot.framing_error = framing_error_;
    snapshot.decoded_bytes = transcript_.size();

    if (!test_passed) {
        snapshot.missing.push_back("passing Test Status");
    }

    const bool checks_uart =
        config_.checker.find("uart") != std::string::npos ||
        config_.checker.find("coremark") != std::string::npos;
    if (checks_uart && framing_error_) {
        snapshot.forbidden_seen.push_back("UART framing error");
    }

    if (!config_.uart_command.empty()) {
        if (!prompt_seen_) {
            snapshot.missing.push_back(
                "UART prompt `" + config_.uart_prompt + "`");
        }
        if (!command_sent_) {
            snapshot.missing.push_back("UART command transmission");
        }
        if (!command_complete()) {
            snapshot.missing.push_back(
                "final UART prompt after all command completions");
        }
    }

    for (const std::string& expected : config_.uart_expect) {
        if (!contains(transcript_, expected)) {
            snapshot.missing.push_back(expected);
        }
    }
    for (const std::string& forbidden : config_.uart_reject) {
        if (contains(transcript_, forbidden)) {
            snapshot.forbidden_seen.push_back(forbidden);
        }
    }

    if (config_.checker.find("coremark") != std::string::npos) {
        const std::string iterations =
            "Iterations       : " +
            std::to_string(config_.benchmark_iterations);
        const std::vector<std::string> required = {
            iterations,
            "[0]crclist       : 0xe714",
            "[0]crcmatrix     : 0x1fd7",
            "[0]crcstate      : 0x8e3a",
        };
        for (const std::string& expected : required) {
            if (!contains(transcript_, expected)) {
                snapshot.missing.push_back(expected);
            }
        }
        if (config_.checker.find("uart-command-coremark") !=
            std::string::npos) {
            if (!contains(
                    transcript_,
                    "SocRV CoreMark CRC check PASS")) {
                snapshot.missing.push_back(
                    "SocRV CoreMark CRC check PASS");
            }
            if (!contains_number_after("SocRV exact total ticks: ")) {
                snapshot.missing.push_back(
                    "numeric SocRV exact total ticks");
            }
        }
    }

    if (config_.checker.find("perf-window") != std::string::npos &&
        !performance_complete) {
        snapshot.missing.push_back("complete performance window");
    }

    snapshot.passed =
        snapshot.missing.empty() && snapshot.forbidden_seen.empty();
    if (snapshot.passed) {
        snapshot.message = "all configured checks passed";
    } else {
        std::ostringstream message;
        if (!snapshot.missing.empty()) {
            message << "missing:";
            for (const std::string& item : snapshot.missing) {
                message << " [" << item << "]";
            }
        }
        if (!snapshot.forbidden_seen.empty()) {
            if (!snapshot.missing.empty()) {
                message << "; ";
            }
            message << "forbidden:";
            for (const std::string& item : snapshot.forbidden_seen) {
                message << " [" << item << "]";
            }
        }
        snapshot.message = message.str();
    }
    return snapshot;
}
