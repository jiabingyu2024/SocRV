#include "uart_decoder.h"

#include <iostream>

void UartDecoder::sample(bool tx) {
    constexpr int divisor = 434;
    if (!receiving_) {
        if (!tx) {
            receiving_ = true;
            countdown_ = divisor + divisor / 2 - 1;
            bit_index_ = 0;
            byte_ = 0;
        }
        return;
    }
    if (countdown_ > 0) {
        --countdown_;
        return;
    }
    if (bit_index_ < 8) {
        if (tx) {
            byte_ |= static_cast<std::uint8_t>(1u << bit_index_);
        }
        ++bit_index_;
        countdown_ = divisor - 1;
        return;
    }
    if (tx) {
        std::cout << static_cast<char>(byte_) << std::flush;
    } else {
        std::cerr << "\nUART framing error\n";
    }
    receiving_ = false;
}
