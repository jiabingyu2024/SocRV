#ifndef SOCRV_TB_UART_STIMULUS_H
#define SOCRV_TB_UART_STIMULUS_H

#include <cstdint>
#include <string>

class UartStimulus {
public:
    UartStimulus(
        std::string command,
        std::uint64_t start_cycle,
        std::uint64_t cycles_per_bit);

    bool level(std::uint64_t cycle) const;

private:
    std::string bytes_;
    std::uint64_t start_cycle_;
    std::uint64_t cycles_per_bit_;
};

#endif
