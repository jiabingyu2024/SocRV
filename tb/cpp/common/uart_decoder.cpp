#include "uart_decoder.h"

UartDecoder::UartDecoder(std::uint64_t cycles_per_bit)
    : cycles_per_bit_(cycles_per_bit) {}

bool UartDecoder::sample(bool tx, char& decoded_byte) {
    if (!receiving_) {
        if (!tx) {
            receiving_ = true;
            countdown_ =
                cycles_per_bit_ + cycles_per_bit_ / 2u - 1u;
            bit_index_ = 0;
            byte_ = 0;
        }
        return false;
    }
    if (countdown_ > 0) {
        --countdown_;
        return false;
    }
    if (bit_index_ < 8) {
        if (tx) {
            byte_ |= static_cast<std::uint8_t>(1u << bit_index_);
        }
        ++bit_index_;
        countdown_ = cycles_per_bit_ - 1u;
        return false;
    }
    if (tx) {
        decoded_byte = static_cast<char>(byte_);
    } else {
        framing_error_ = true;
    }
    receiving_ = false;
    return tx;
}

bool UartDecoder::framing_error() const {
    return framing_error_;
}
