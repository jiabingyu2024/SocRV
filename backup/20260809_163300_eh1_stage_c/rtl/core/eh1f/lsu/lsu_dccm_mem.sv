// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
// SocRv no-ECC TCM derivative, 2026.

// 64 KiB data closely coupled memory.
//
// Eight 2048 x 32-bit banks preserve EH1's ability to fetch the two adjacent
// words needed by an unaligned load/store using one synchronous read per bank.
// There are no check bits, syndrome ports, correction cycles or scrub writes.
module lsu_dccm_mem
   import veer_types::*;
(
   input  logic                              clk,
   input  logic                              free_clk,
   input  logic                              rst_l,
   input  logic                              lsu_freeze_dc3,
   input  logic                              clk_override,
   input  logic                              dccm_wren,
   input  logic                              dccm_rden,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_wr_addr,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_lo,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_hi,
   input  logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_wr_data,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_rd_data_lo,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_rd_data_hi,
   input  logic                              scan_mode
);

   localparam int BANK_BITS  = `RV_DCCM_BANK_BITS;
   localparam int BANK_COUNT = `RV_DCCM_NUM_BANKS;
   localparam int ROW_BITS   = `RV_DCCM_INDEX_BITS;
   localparam int ROW_COUNT  = `RV_DCCM_ROWS;

   logic [BANK_BITS-1:0] rd_bank_lo_q, rd_bank_hi_q;
   logic [31:0] bank_dout [0:BANK_COUNT-1];

   for (genvar bank = 0; bank < BANK_COUNT; bank++) begin: dccm_bank_gen
      (* ram_style = "block" *) logic [31:0] bank_mem [0:ROW_COUNT-1];
      logic [ROW_BITS-1:0] read_row;
      logic                 bank_read;
      logic                 bank_write;

      assign bank_read = dccm_rden &
                         ((dccm_rd_addr_lo[2+:BANK_BITS] == bank[BANK_BITS-1:0]) |
                          (dccm_rd_addr_hi[2+:BANK_BITS] == bank[BANK_BITS-1:0]));
      assign bank_write = dccm_wren &
                          (dccm_wr_addr[2+:BANK_BITS] == bank[BANK_BITS-1:0]);

      // If the access crosses a bank boundary, the upper-address bank reads
      // its own row. Otherwise both outputs intentionally select one word.
      assign read_row = ((dccm_rd_addr_hi[2+:BANK_BITS] == bank[BANK_BITS-1:0]) &
                         (dccm_rd_addr_hi[2+:BANK_BITS] != dccm_rd_addr_lo[2+:BANK_BITS])) ?
                           dccm_rd_addr_hi[(BANK_BITS+2)+:ROW_BITS] :
                           dccm_rd_addr_lo[(BANK_BITS+2)+:ROW_BITS];

      always_ff @(posedge clk) begin
         if (!lsu_freeze_dc3) begin
            if (bank_read)
               bank_dout[bank] <= bank_mem[read_row];
            if (bank_write)
               bank_mem[dccm_wr_addr[(BANK_BITS+2)+:ROW_BITS]] <= dccm_wr_data[31:0];
         end
      end
   end

   always_ff @(posedge clk) begin
      if (!lsu_freeze_dc3 && dccm_rden) begin
         rd_bank_lo_q <= dccm_rd_addr_lo[2+:BANK_BITS];
         rd_bank_hi_q <= dccm_rd_addr_hi[2+:BANK_BITS];
      end
   end

   assign dccm_rd_data_lo[31:0] = bank_dout[rd_bank_lo_q];
   assign dccm_rd_data_hi[31:0] = bank_dout[rd_bank_hi_q];

   // free_clk, rst_l, clk_override and scan_mode are retained only on the
   // temporary compatibility boundary and do not alter BRAM contents.

endmodule
