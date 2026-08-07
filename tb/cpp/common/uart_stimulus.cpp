#include "uart_stimulus.h"

#include <utility>

UartStimulus::UartStimulus(
    std::string command,
    std::uint64_t cycles_per_bit)
    : bytes_(std::move(command)),
      cycles_per_bit_(cycles_per_bit) {}

void UartStimulus::start(std::uint64_t cycle) {
    if (!started_) {
        start_cycle_ = cycle;
        started_ = true;
    }
}

void UartStimulus::load(std::string command) {
    bytes_ = std::move(command);
    start_cycle_ = 0;
    started_ = false;
}

bool UartStimulus::started() const {
    return started_;
}

bool UartStimulus::finished(std::uint64_t cycle) const {
    if (!started_ || cycle < start_cycle_) {
        return false;
    }
    const std::uint64_t frame_cycles = 10u * cycles_per_bit_;
    return cycle - start_cycle_ >= bytes_.size() * frame_cycles;
}

bool UartStimulus::level(std::uint64_t cycle) const {
    if (bytes_.empty() || !started_ || cycle < start_cycle_) {
        return true;
    }

    const std::uint64_t elapsed = cycle - start_cycle_;
    const std::uint64_t frame_cycles = 10u * cycles_per_bit_;
    const std::uint64_t byte_index = elapsed / frame_cycles;
    if (byte_index >= bytes_.size()) {
        return true;
    }

    const std::uint64_t bit =
        (elapsed % frame_cycles) / cycles_per_bit_;
    if (bit == 0u) {
        return false;
    }
    if (bit <= 8u) {
        const auto byte = static_cast<std::uint8_t>(bytes_[byte_index]);
        return ((byte >> (bit - 1u)) & 1u) != 0u;
    }
    return true;
}
