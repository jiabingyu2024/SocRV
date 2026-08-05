#include "uart_stimulus.h"

#include <utility>

UartStimulus::UartStimulus(
    std::string command,
    std::uint64_t start_cycle,
    std::uint64_t cycles_per_bit)
    : bytes_(std::move(command)),
      start_cycle_(start_cycle),
      cycles_per_bit_(cycles_per_bit) {}

bool UartStimulus::level(std::uint64_t cycle) const {
    if (bytes_.empty() || cycle < start_cycle_) {
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
