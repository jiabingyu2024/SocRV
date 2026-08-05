#ifndef SOCRV_TB_UART_STIMULUS_H
#define SOCRV_TB_UART_STIMULUS_H

#include <cstdint>
#include <string>

class UartStimulus {
public:
    UartStimulus(
        std::string command,
        std::uint64_t cycles_per_bit);

    void start(std::uint64_t cycle);
    bool started() const;
    bool level(std::uint64_t cycle) const;

private:
    std::string bytes_;
    std::uint64_t cycles_per_bit_;
    std::uint64_t start_cycle_ = 0;
    bool started_ = false;
};

#endif
