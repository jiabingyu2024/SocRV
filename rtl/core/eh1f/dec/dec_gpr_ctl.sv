// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module dec_gpr_ctl #(parameter GPR_BANKS      = 1,
                               GPR_BANKS_LOG2 = 1)  (
    input logic active_clk,

    input logic [4:0] raddr0,  // logical read addresses
    input logic [4:0] raddr1,
    input logic [4:0] raddr2,
    input logic [4:0] raddr3,

    input logic       rden0,   // read enables
    input logic       rden1,
    input logic       rden2,
    input logic       rden3,

    input logic [4:0] waddr0,  // logical write addresses
    input logic [4:0] waddr1,
    input logic [4:0] waddr2,

    input logic wen0,          // write enables
    input logic wen1,
    input logic wen2,

    input logic [31:0] wd0,    // write data
    input logic [31:0] wd1,
    input logic [31:0] wd2,

    input logic                      wen_bank_id,  // write enable for banks
    input logic [GPR_BANKS_LOG2-1:0] wr_bank_id,   // read enable for banks

    input logic       clk,
    input logic       rst_l,

    output logic [31:0] rd0,  // read data
    output logic [31:0] rd1,
    output logic [31:0] rd2,
    output logic [31:0] rd3,

    input  logic        scan_mode
);

   // Three single-write value banks plus a live-value table replace the
   // ASIC-style 31-way flop read mux.  Each value bank is replicated for the
   // four asynchronous read ports so Vivado can map the arrays to LUTRAM.
   logic [1:0]  live_bank [0:31];
   logic [4:0]  read_addr [0:3];
   logic [31:0] bank0_rd  [0:3];
   logic [31:0] bank1_rd  [0:3];
   logic [31:0] bank2_rd  [0:3];
   logic [31:0] read_data [0:3];

   assign read_addr[0] = raddr0;
   assign read_addr[1] = raddr1;
   assign read_addr[2] = raddr2;
   assign read_addr[3] = raddr3;

   for (genvar rp = 0; rp < 4; rp++) begin : gpr_read_replica
      (* ram_style = "distributed" *) logic [31:0] write_bank0 [0:31];
      (* ram_style = "distributed" *) logic [31:0] write_bank1 [0:31];
      (* ram_style = "distributed" *) logic [31:0] write_bank2 [0:31];

      initial begin
         for (int entry = 0; entry < 32; entry++) begin
            write_bank0[entry] = '0;
            write_bank1[entry] = '0;
            write_bank2[entry] = '0;
         end
      end

      always_ff @(posedge clk) begin
         if (wen0 && (waddr0 != 5'd0)) write_bank0[waddr0] <= wd0;
         if (wen1 && (waddr1 != 5'd0)) write_bank1[waddr1] <= wd1;
         if (wen2 && (waddr2 != 5'd0)) write_bank2[waddr2] <= wd2;
      end

      assign bank0_rd[rp] = write_bank0[read_addr[rp]];
      assign bank1_rd[rp] = write_bank1[read_addr[rp]];
      assign bank2_rd[rp] = write_bank2[read_addr[rp]];

      always_comb begin
         unique case (live_bank[read_addr[rp]])
            2'd1:    read_data[rp] = bank1_rd[rp];
            2'd2:    read_data[rp] = bank2_rd[rp];
            default: read_data[rp] = bank0_rd[rp];
         endcase
      end
   end

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         for (int entry = 0; entry < 32; entry++) live_bank[entry] <= 2'd0;
      end
      else begin
         if (wen0 && (waddr0 != 5'd0)) live_bank[waddr0] <= 2'd0;
         if (wen1 && (waddr1 != 5'd0)) live_bank[waddr1] <= 2'd1;
         if (wen2 && (waddr2 != 5'd0)) live_bank[waddr2] <= 2'd2;
      end
   end

   assign rd0 = (rden0 && (raddr0 != 5'd0)) ? read_data[0] : 32'b0;
   assign rd1 = (rden1 && (raddr1 != 5'd0)) ? read_data[1] : 32'b0;
   assign rd2 = (rden2 && (raddr2 != 5'd0)) ? read_data[2] : 32'b0;
   assign rd3 = (rden3 && (raddr3 != 5'd0)) ? read_data[3] : 32'b0;

`ifdef ASSERT_ON
   // asserting that no 2 ports will write to the same gpr simultaneously
   assert_multiple_wen_to_same_gpr: assert #0 (~((wen0 & wen1 & (waddr0 == waddr1) & (waddr0 != 5'd0)) |
                                                  (wen0 & wen2 & (waddr0 == waddr2) & (waddr0 != 5'd0)) |
                                                  (wen1 & wen2 & (waddr1 == waddr2) & (waddr1 != 5'd0))));
   assert_single_logical_bank: assert #0 (GPR_BANKS == 1);

`endif

   logic unused_compat;
   assign unused_compat = &{1'b0, active_clk, scan_mode, wen_bank_id, wr_bank_id};

endmodule
