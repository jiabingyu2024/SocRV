// Copyright 2018 ETH Zurich and University of Bologna.
// SPDX-License-Identifier: SHL-0.51
// Imported from pulp-platform/common_cells v1.21.0 for FPnew.
`ifndef COMMON_CELLS_REGISTERS_SVH_
`define COMMON_CELLS_REGISTERS_SVH_

`define FF(__q, __d, __reset_value)                  \
  always_ff @(posedge clk_i or negedge rst_ni) begin \
    if (!rst_ni) __q <= (__reset_value);              \
    else         __q <= (__d);                        \
  end

`define FFAR(__q, __d, __reset_value, __clk, __arst)     \
  always_ff @(posedge (__clk) or posedge (__arst)) begin \
    if (__arst) __q <= (__reset_value);                  \
    else         __q <= (__d);                           \
  end

`define FFARN(__q, __d, __reset_value, __clk, __arst_n)    \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin \
    if (!__arst_n) __q <= (__reset_value);                 \
    else            __q <= (__d);                          \
  end

`define FFSR(__q, __d, __reset_value, __clk, __reset_clk) \
  always_ff @(posedge (__clk)) begin                       \
    __q <= (__reset_clk) ? (__reset_value) : (__d);        \
  end

`define FFSRN(__q, __d, __reset_value, __clk, __reset_n_clk) \
  always_ff @(posedge (__clk)) begin                          \
    __q <= (!__reset_n_clk) ? (__reset_value) : (__d);        \
  end

`define FFNR(__q, __d, __clk)        \
  always_ff @(posedge (__clk)) begin \
    __q <= (__d);                    \
  end

`define FFL(__q, __d, __load, __reset_value)         \
  always_ff @(posedge clk_i or negedge rst_ni) begin \
    if (!rst_ni) __q <= (__reset_value);              \
    else if (__load) __q <= (__d);                    \
  end

`define FFLAR(__q, __d, __load, __reset_value, __clk, __arst) \
  always_ff @(posedge (__clk) or posedge (__arst)) begin      \
    if (__arst) __q <= (__reset_value);                       \
    else if (__load) __q <= (__d);                            \
  end

`define FFLARN(__q, __d, __load, __reset_value, __clk, __arst_n) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin       \
    if (!__arst_n) __q <= (__reset_value);                        \
    else if (__load) __q <= (__d);                                \
  end

`define FFLSR(__q, __d, __load, __reset_value, __clk, __reset_clk) \
  always_ff @(posedge (__clk)) begin                                \
    if (__reset_clk) __q <= (__reset_value);                        \
    else if (__load) __q <= (__d);                                  \
  end

`define FFLSRN(__q, __d, __load, __reset_value, __clk, __reset_n_clk) \
  always_ff @(posedge (__clk)) begin                                   \
    if (!__reset_n_clk) __q <= (__reset_value);                        \
    else if (__load) __q <= (__d);                                     \
  end

`define FFLARNC(__q, __d, __load, __clear, __reset_value, __clk, __arst_n) \
  always_ff @(posedge (__clk) or negedge (__arst_n)) begin                 \
    if (!__arst_n) __q <= (__reset_value);                                  \
    else if (__clear) __q <= (__reset_value);                               \
    else if (__load) __q <= (__d);                                          \
  end

`define FFLNR(__q, __d, __load, __clk) \
  always_ff @(posedge (__clk)) begin   \
    if (__load) __q <= (__d);           \
  end

`endif
