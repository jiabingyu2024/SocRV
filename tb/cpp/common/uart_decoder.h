#ifndef SOCRV_TB_UART_DECODER_H
#define SOCRV_TB_UART_DECODER_H

#include <cstdint>

class UartDecoder {
public:
    explicit UartDecoder(std::uint64_t cycles_per_bit);

    bool sample(bool tx, char& decoded_byte);
    bool framing_error() const;

private:
    std::uint64_t cycles_per_bit_;
    bool receiving_ = false;
    bool framing_error_ = false;
    std::uint64_t countdown_ = 0;
    int bit_index_ = 0;
    std::uint8_t byte_ = 0;
};

#endif
