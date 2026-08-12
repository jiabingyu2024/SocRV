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

module dec_ib_ctl
   import veer_types::*;
(
   input logic   free_clk,
   input logic   active_clk,

   input logic                 dbg_cmd_valid,
   input logic                 dbg_cmd_write,
   input logic [1:0]           dbg_cmd_type,
   input logic [1:0]           dbg_cmd_size,
   input logic [31:0]          dbg_cmd_addr,

   input logic exu_flush_final,

   input logic          dec_ib0_valid_eff_d,
   input logic          dec_ib1_valid_eff_d,

   input br_pkt_t i0_brp,
   input br_pkt_t i1_brp,

   input logic   ifu_i0_pc4,
   input logic   ifu_i1_pc4,

   input logic   ifu_i0_valid,
   input logic   ifu_i1_valid,

   input logic   ifu_i0_icaf,
   input logic   ifu_i1_icaf,
   input logic   ifu_i0_icaf_second,
   input logic   ifu_i1_icaf_second,
   input logic   ifu_i0_perr,
   input logic   ifu_i1_perr,
   input logic   ifu_i0_sbecc,
   input logic   ifu_i1_sbecc,
   input logic   ifu_i0_dbecc,
   input logic   ifu_i1_dbecc,

   input logic [31:0]  ifu_i0_instr,
   input logic [31:0]  ifu_i1_instr,

   input logic [31:1]  ifu_i0_pc,
   input logic [31:1]  ifu_i1_pc,

   input logic   dec_i0_decode_d,
   input logic   dec_i1_decode_d,

   input logic   rst_l,
   input logic   clk,

   output logic dec_ib3_valid_d,
   output logic dec_ib2_valid_d,
   output logic dec_ib1_valid_d,
   output logic dec_ib0_valid_d,

   output logic [31:0] dec_i0_instr_d,
   output logic [31:0] dec_i1_instr_d,

   output logic [31:1] dec_i0_pc_d,
   output logic [31:1] dec_i1_pc_d,

   output logic dec_i0_pc4_d,
   output logic dec_i1_pc4_d,

   output br_pkt_t dec_i0_brp,
   output br_pkt_t dec_i1_brp,

   output logic dec_i0_icaf_d,
   output logic dec_i1_icaf_d,
   output logic dec_i0_icaf_second_d,
   output logic dec_i0_perr_d,
   output logic dec_i1_perr_d,
   output logic dec_i0_sbecc_d,
   output logic dec_i1_sbecc_d,
   output logic dec_i0_dbecc_d,
   output logic dec_i1_dbecc_d,
   output logic dec_debug_wdata_rs1_d,

   output logic dec_debug_fence_d,

   input logic [15:0] ifu_i0_cinst,
   input logic [15:0] ifu_i1_cinst,

   output logic [15:0] dec_i0_cinst_d,
   output logic [15:0] dec_i1_cinst_d,

   input  logic scan_mode
   );

`include "global.h"

   localparam IB_PTR_WIDTH = (DEC_INSTBUF_DEPTH == 4) ? 2 : 1;
   localparam BP_WIDTH = $bits(br_pkt_t);

   logic flush_final;
   rvdff #(1) flush_upperff (.*, .clk(free_clk), .din(exu_flush_final), .dout(flush_final));

   // Debug instructions are inserted only while the machine is halted and the
   // instruction buffer is empty.  Keep the original instruction synthesis.
   logic         debug_valid;
   logic         debug_read;
   logic         debug_write;
   logic         debug_read_gpr;
   logic         debug_write_gpr;
   logic         debug_read_csr;
   logic         debug_write_csr;
   logic [4:0]   dreg;
   logic [11:0]  dcsr;
   logic [31:0]  ib0_debug_in;
   logic         debug_fence_in;

   assign debug_valid = dbg_cmd_valid & (dbg_cmd_type[1:0] != 2'h2);
   assign debug_read  = debug_valid & ~dbg_cmd_write;
   assign debug_write = debug_valid &  dbg_cmd_write;
   assign debug_read_gpr  = debug_read  & (dbg_cmd_type[1:0] == 2'h0);
   assign debug_write_gpr = debug_write & (dbg_cmd_type[1:0] == 2'h0);
   assign debug_read_csr  = debug_read  & (dbg_cmd_type[1:0] == 2'h1);
   assign debug_write_csr = debug_write & (dbg_cmd_type[1:0] == 2'h1);

   assign dreg[4:0] = dbg_cmd_addr[4:0];
   assign dcsr[11:0] = dbg_cmd_addr[11:0];

   assign ib0_debug_in[31:0] = ({32{debug_read_gpr}}  & {12'b000000000000,dreg[4:0],15'b110000000110011}) |
                               ({32{debug_write_gpr}} & {20'b00000000000000000110,dreg[4:0],7'b0110011}) |
                               ({32{debug_read_csr}}  & {dcsr[11:0],20'b00000010000001110011}) |
                               ({32{debug_write_csr}} & {dcsr[11:0],20'b00000001000001110011});

   rvdff #(1) debug_wdata_rs1ff (.*, .clk(free_clk),
                                 .din(debug_write_gpr | debug_write_csr),
                                 .dout(dec_debug_wdata_rs1_d));

   assign debug_fence_in = debug_write_csr & (dcsr[11:0] == 12'h7c4);
   rvdff #(1) debug_fence_ff (.*, .clk(free_clk),
                              .din(debug_fence_in), .dout(dec_debug_fence_d));

   // v5.6: use independent head and tail pointers instead of physically
   // compacting every wide entry after issue.  Decode/issue feedback advances
   // only the small head/count state.  IFU arrivals advance only the tail and
   // write each wide instruction/PC/BP entry once.
   //
   // v5.7: keep local registered head views for each wide read family.  The
   // second-issue views carry head+1 as state instead of rebuilding that
   // increment in the decode data path.  KEEP prevents synthesis from merging
   // the equivalent state, allowing each mux cone to be placed near its own
   // consumers without changing FIFO or issue semantics.
   (* keep = "true", max_fanout = 32 *)
   logic [IB_PTR_WIDTH-1:0] head_instr0_ptr, head_instr1_ptr;
   (* keep = "true", max_fanout = 32 *)
   logic [IB_PTR_WIDTH-1:0] head_pc0_ptr, head_pc1_ptr;
   (* keep = "true", max_fanout = 32 *)
   logic [IB_PTR_WIDTH-1:0] head_bp0_ptr, head_bp1_ptr;
   (* keep = "true", max_fanout = 32 *)
   logic [IB_PTR_WIDTH-1:0] head_cinst0_ptr, head_cinst1_ptr;
   logic [IB_PTR_WIDTH-1:0] tail_ptr, tail_ptr_in;
   logic [IB_PTR_WIDTH-1:0] tail1_ptr;
   logic [2:0] ib_count, ib_count_in;
   logic [1:0] push_count, pop_count;
   logic       ifu_i0_val, ifu_i1_val;
   logic       push0, push1, debug_insert;

   if (DEC_INSTBUF_DEPTH == 4) begin : GEN_FOUR_ENTRY_ACCEPT
      assign ifu_i0_val = ifu_i0_valid & (ib_count < 3'd4) & ~flush_final;
      assign ifu_i1_val = ifu_i1_valid & (ib_count < 3'd3) & ~flush_final;
   end
   else begin : GEN_TWO_ENTRY_ACCEPT
      // Preserve the original two-entry same-cycle refill policy, which uses
      // effective decode valids rather than the pre-issue occupancy.
      assign ifu_i0_val = ifu_i0_valid &
                          (~dec_ib0_valid_eff_d | ~dec_ib1_valid_eff_d) &
                          ~flush_final;
      assign ifu_i1_val = ifu_i1_valid &
                          (~dec_ib0_valid_eff_d & ~dec_ib1_valid_eff_d) &
                          ~flush_final;
   end

   assign debug_insert = debug_valid & (ib_count == 3'd0);
   assign push0 = ifu_i0_val | debug_insert;
   assign push1 = ifu_i1_val;
   assign push_count[1:0] = {1'b0,push0} + {1'b0,push1};
   assign pop_count[1:0] = {1'b0,dec_i0_decode_d} + {1'b0,dec_i1_decode_d};

   assign tail1_ptr = tail_ptr + {{(IB_PTR_WIDTH-1){1'b0}},1'b1};

   assign tail_ptr_in = flush_final ? '0 : tail_ptr + push_count[IB_PTR_WIDTH-1:0];
   assign ib_count_in = flush_final ? 3'd0 :
                        ib_count + {1'b0,push_count} - {1'b0,pop_count};

   always_ff @(posedge active_clk or negedge rst_l) begin
      if (!rst_l) begin
         head_instr0_ptr <= '0;
         head_pc0_ptr    <= '0;
         head_bp0_ptr    <= '0;
         head_cinst0_ptr <= '0;
         head_instr1_ptr <= {{(IB_PTR_WIDTH-1){1'b0}},1'b1};
         head_pc1_ptr    <= {{(IB_PTR_WIDTH-1){1'b0}},1'b1};
         head_bp1_ptr    <= {{(IB_PTR_WIDTH-1){1'b0}},1'b1};
         head_cinst1_ptr <= {{(IB_PTR_WIDTH-1){1'b0}},1'b1};
      end
      else begin
         head_instr0_ptr <= flush_final ? '0 :
                            head_instr0_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_pc0_ptr    <= flush_final ? '0 :
                            head_pc0_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_bp0_ptr    <= flush_final ? '0 :
                            head_bp0_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_cinst0_ptr <= flush_final ? '0 :
                            head_cinst0_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_instr1_ptr <= flush_final ?
                            {{(IB_PTR_WIDTH-1){1'b0}},1'b1} :
                            head_instr1_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_pc1_ptr    <= flush_final ?
                            {{(IB_PTR_WIDTH-1){1'b0}},1'b1} :
                            head_pc1_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_bp1_ptr    <= flush_final ?
                            {{(IB_PTR_WIDTH-1){1'b0}},1'b1} :
                            head_bp1_ptr + pop_count[IB_PTR_WIDTH-1:0];
         head_cinst1_ptr <= flush_final ?
                            {{(IB_PTR_WIDTH-1){1'b0}},1'b1} :
                            head_cinst1_ptr + pop_count[IB_PTR_WIDTH-1:0];
      end
   end

   rvdff #(IB_PTR_WIDTH) ib_tailff (.*, .clk(active_clk),
                                    .din(tail_ptr_in), .dout(tail_ptr));
   rvdff #(3) ib_countff (.*, .clk(active_clk),
                          .din(ib_count_in), .dout(ib_count));

   logic [DEC_INSTBUF_DEPTH-1:0] slot_we0, slot_we1, slot_we;
   assign slot_we0 = {DEC_INSTBUF_DEPTH{push0}} &
                     ({{(DEC_INSTBUF_DEPTH-1){1'b0}},1'b1} << tail_ptr);
   assign slot_we1 = {DEC_INSTBUF_DEPTH{push1}} &
                     ({{(DEC_INSTBUF_DEPTH-1){1'b0}},1'b1} << tail1_ptr);
   assign slot_we = slot_we0 | slot_we1;

   // v5.8: instruction bits have two write-identical physical copies.  The
   // i0 and i1 decode cones no longer share a single slot-bit launch register,
   // which was the dominant v5.7 post-route family.  KEEP prevents synthesis
   // from merging the banks back together; this changes neither queue state
   // nor the cycle in which an instruction is visible.
   (* keep = "true" *) logic [31:0] ib_i0_slot [0:DEC_INSTBUF_DEPTH-1];
   (* keep = "true" *) logic [31:0] ib_i1_slot [0:DEC_INSTBUF_DEPTH-1];
   logic [36:0] pc_slot [0:DEC_INSTBUF_DEPTH-1];
   logic [15:0] cinst_slot [0:DEC_INSTBUF_DEPTH-1];
   logic [BP_WIDTH-1:0] bp_slot [0:DEC_INSTBUF_DEPTH-1];

   logic [31:0] ib_slot_in [0:DEC_INSTBUF_DEPTH-1];
   logic [36:0] pc_slot_in [0:DEC_INSTBUF_DEPTH-1];
   logic [15:0] cinst_slot_in [0:DEC_INSTBUF_DEPTH-1];
   logic [BP_WIDTH-1:0] bp_slot_in [0:DEC_INSTBUF_DEPTH-1];

   logic [36:0] ifu_i0_pcdata, ifu_i1_pcdata;
   assign ifu_i0_pcdata = {ifu_i0_icaf_second, ifu_i0_dbecc, ifu_i0_sbecc,
                           ifu_i0_perr, ifu_i0_icaf, ifu_i0_pc[31:1], ifu_i0_pc4};
   assign ifu_i1_pcdata = {ifu_i1_icaf_second, ifu_i1_dbecc, ifu_i1_sbecc,
                           ifu_i1_perr, ifu_i1_icaf, ifu_i1_pc[31:1], ifu_i1_pc4};

   for (genvar slot = 0; slot < DEC_INSTBUF_DEPTH; slot++) begin : IB_RING
      assign ib_slot_in[slot] = slot_we0[slot] ?
                                (debug_insert ? ib0_debug_in : ifu_i0_instr) :
                                ifu_i1_instr;
      assign pc_slot_in[slot] = slot_we0[slot] ? ifu_i0_pcdata : ifu_i1_pcdata;
      assign cinst_slot_in[slot] = slot_we0[slot] ? ifu_i0_cinst : ifu_i1_cinst;
      assign bp_slot_in[slot] = slot_we0[slot] ? i0_brp : i1_brp;

      (* dont_touch = "true" *)
      rvdffe #(32) ib_i0ff (.*, .en(slot_we[slot]),
                             .din(ib_slot_in[slot]), .dout(ib_i0_slot[slot]));
      (* dont_touch = "true" *)
      rvdffe #(32) ib_i1ff (.*, .en(slot_we[slot]),
                             .din(ib_slot_in[slot]), .dout(ib_i1_slot[slot]));
      rvdffe #(37) pcff (.*, .en(slot_we[slot]),
                          .din(pc_slot_in[slot]), .dout(pc_slot[slot]));
      rvdffe #(16) cinstff (.*, .en(slot_we[slot]),
                             .din(cinst_slot_in[slot]), .dout(cinst_slot[slot]));
      rvdffe #(BP_WIDTH) bpff (.*, .en(slot_we[slot]),
                                .din(bp_slot_in[slot]), .dout(bp_slot[slot]));
   end

   logic [36:0] pc_head0, pc_head1;
   assign dec_i0_instr_d = ib_i0_slot[head_instr0_ptr];
   assign dec_i1_instr_d = ib_i1_slot[head_instr1_ptr];
   assign dec_i0_cinst_d = cinst_slot[head_cinst0_ptr];
   assign dec_i1_cinst_d = cinst_slot[head_cinst1_ptr];
   assign dec_i0_brp = bp_slot[head_bp0_ptr];
   assign dec_i1_brp = bp_slot[head_bp1_ptr];
   assign pc_head0 = pc_slot[head_pc0_ptr];
   assign pc_head1 = pc_slot[head_pc1_ptr];

   assign dec_i0_icaf_second_d = pc_head0[36];
   assign dec_i0_dbecc_d = pc_head0[35];
   assign dec_i1_dbecc_d = pc_head1[35];
   assign dec_i0_sbecc_d = pc_head0[34];
   assign dec_i1_sbecc_d = pc_head1[34];
   assign dec_i0_perr_d = pc_head0[33];
   assign dec_i1_perr_d = pc_head1[33];
   assign dec_i0_icaf_d = pc_head0[32];
   assign dec_i1_icaf_d = pc_head1[32];
   assign dec_i0_pc_d = pc_head0[31:1];
   assign dec_i1_pc_d = pc_head1[31:1];
   assign dec_i0_pc4_d = pc_head0[0];
   assign dec_i1_pc4_d = pc_head1[0];

   assign dec_ib0_valid_d = (ib_count >= 3'd1);
   assign dec_ib1_valid_d = (ib_count >= 3'd2);
   if (DEC_INSTBUF_DEPTH == 4) begin : GEN_FOUR_ENTRY_VALID
      assign dec_ib2_valid_d = (ib_count >= 3'd3);
      assign dec_ib3_valid_d = (ib_count >= 3'd4);
   end
   else begin : GEN_TWO_ENTRY_VALID
      assign dec_ib2_valid_d = 1'b0;
      assign dec_ib3_valid_d = 1'b0;
   end

endmodule
