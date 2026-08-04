#ifndef SOCRV_TB_UART_DECODER_H
#define SOCRV_TB_UART_DECODER_H

#include <cstdint>

class UartDecoder {
public:
    void sample(bool tx);

private:
    bool receiving_ = false;
    int countdown_ = 0;
    int bit_index_ = 0;
    std::uint8_t byte_ = 0;
};

#endif
