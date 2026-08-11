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
   input logic   free_clk,                    // free clk
   input logic   active_clk,                  // active clk if not halt / pause

   input logic                 dbg_cmd_valid,  // valid dbg cmd

   input logic                 dbg_cmd_write,  // dbg cmd is write
   input logic [1:0]           dbg_cmd_type,   // dbg type
   input logic [1:0]           dbg_cmd_size,   // 00 - 1B, 01 - 2B, 10 - 4B, 11 - reserved
   input logic [31:0]          dbg_cmd_addr,   // expand to 31:0

   input logic exu_flush_final,                // all flush sources: primary/secondary alu's, trap

   input logic          dec_ib0_valid_eff_d,   // effective valid taking decode into account
   input logic          dec_ib1_valid_eff_d,

   input br_pkt_t i0_brp,                      // i0 branch packet from aligner
   input br_pkt_t i1_brp,

   input logic   ifu_i0_pc4,                   // i0 is 4B inst else 2B
   input logic   ifu_i1_pc4,

   input logic   ifu_i0_valid,                 // i0 valid from ifu
   input logic   ifu_i1_valid,

   input logic   ifu_i0_icaf,                  // i0 instruction access fault
   input logic   ifu_i1_icaf,
   input logic   ifu_i0_icaf_second,               // i0 has access fault on second 2B of 4B inst
   input logic   ifu_i1_icaf_second,
   input logic   ifu_i0_perr,                  // i0 instruction parity error
   input logic   ifu_i1_perr,
   input logic   ifu_i0_sbecc,                 // i0 single-bit error
   input logic   ifu_i1_sbecc,
   input logic   ifu_i0_dbecc,                 // i0 double-bit error
   input logic   ifu_i1_dbecc,

   input logic [31:0]  ifu_i0_instr,           // i0 instruction from the aligner
   input logic [31:0]  ifu_i1_instr,

   input logic [31:1]  ifu_i0_pc,              // i0 pc from the aligner
   input logic [31:1] ifu_i1_pc,

   input logic   dec_i0_decode_d,              // i0 decode
   input logic   dec_i1_decode_d,


   input logic   rst_l,                        // test stuff
   input logic   clk,


   output logic dec_ib3_valid_d,               // ib3 valid
   output logic dec_ib2_valid_d,               // ib2 valid
   output logic dec_ib1_valid_d,               // ib1 valid
   output logic dec_ib0_valid_d,               // ib0 valid


   output logic [31:0] dec_i0_instr_d,         // i0 inst at decode
   output logic [31:0] dec_i1_instr_d,         // i1 inst at decode
   output dec_pkt_t    dec_i0_predecode_d,     // registered one-hot decode metadata
   output dec_pkt_t    dec_i1_predecode_d,
   output reg_pkt_t    dec_i0_regs_d,          // registered rs1/rs2/rd metadata
   output reg_pkt_t    dec_i1_regs_d,

   output logic [31:1] dec_i0_pc_d,            // i0 pc at decode
   output logic [31:1] dec_i1_pc_d,

   output logic dec_i0_pc4_d,                  // i0 is 4B inst else 2B
   output logic dec_i1_pc4_d,

   output br_pkt_t dec_i0_brp,                 // i0 branch packet at decode
   output br_pkt_t dec_i1_brp,

   output logic dec_i0_icaf_d,                 // i0 instruction access fault at decode
   output logic dec_i1_icaf_d,
   output logic dec_i0_icaf_second_d,              // i0 instruction access fault on second 2B of 4B inst
   output logic dec_i0_perr_d,                 // i0 instruction parity error at decode
   output logic dec_i1_perr_d,
   output logic dec_i0_sbecc_d,                // i0 single-bit error at decode
   output logic dec_i1_sbecc_d,
   output logic dec_i0_dbecc_d,                // i0 double-bit error at decode
   output logic dec_i1_dbecc_d,
   output logic dec_debug_wdata_rs1_d,         // put debug write data onto rs1 source: machine is halted

   output logic dec_debug_fence_d,             // debug fence inst

   input logic [15:0] ifu_i0_cinst,            // 16b compressed inst from aligner
   input logic [15:0] ifu_i1_cinst,

   output logic [15:0] dec_i0_cinst_d,         // 16b compress inst at decode
   output logic [15:0] dec_i1_cinst_d,

   input  logic scan_mode

   );

`include "global.h"

   logic         flush_final;

   typedef struct packed {
      logic [31:0] instr;
      logic [36:0] pcdata;
      logic [15:0] cinst;
      br_pkt_t     brp;
      dec_pkt_t    predecode;
      reg_pkt_t    regs;
   } ib_payload_t;

   logic [2:0]   ib_count, ib_count_in;
   logic [1:0]   ib_head, ib_head_in, ib_tail;
   logic [1:0]   dequeue_count, enqueue_count;
   logic         enqueue_i0, enqueue_i1, enqueue_debug;
   ib_payload_t  enqueue_payload [0:1];
   ib_payload_t  ib_entry [0:3];
   ib_payload_t  ib_entry_write_data [0:3];
   logic [3:0]   ib_entry_write_en;
   ib_payload_t  ib_front [0:1];
   ib_payload_t  ib_front_in [0:1];

   logic [31:0]  ib0, ib1;
   logic [36:0]  pc0, pc1;
   logic [15:0]  cinst0, cinst1;
   br_pkt_t      bp0, bp1;
   dec_pkt_t     predecode0, predecode1;
   dec_pkt_t     enqueue_predecode [0:1];
   reg_pkt_t     regs0, regs1;


   logic         ifu_i0_val, ifu_i1_val;
   logic         debug_valid;
   logic [4:0]   dreg;
   logic [11:0]  dcsr;
   logic [31:0]  ib0_debug_in;

//   logic                     debug_read_mem;
//   logic                     debug_write_mem;
   logic         debug_read;
   logic         debug_write;
   logic         debug_read_gpr;
   logic         debug_write_gpr;
   logic         debug_read_csr;
   logic         debug_write_csr;



   rvdff #(1) flush_upperff (.*, .clk(free_clk),
                             .din(exu_flush_final), .dout(flush_final));

   wire [2:0] total_count = ib_count;

   // Keep the original conservative admission contract: space freed by a
   // same-cycle dequeue is visible to the aligner on the following cycle.
   if (DEC_INSTBUF_DEPTH==4) begin
      assign ifu_i0_val = ifu_i0_valid & (total_count < 3'd4) & ~flush_final;
      assign ifu_i1_val = ifu_i1_valid & (total_count < 3'd3) & ~flush_final;
   end
   else begin
      assign ifu_i0_val = ifu_i0_valid & (~dec_ib0_valid_eff_d | ~dec_ib1_valid_eff_d) & ~flush_final;
      assign ifu_i1_val = ifu_i1_valid & (~dec_ib0_valid_eff_d & ~dec_ib1_valid_eff_d) & ~flush_final;
   end


   assign enqueue_debug = debug_valid & (total_count == 3'd0) & ~flush_final;
   assign enqueue_i0 = ifu_i0_val | enqueue_debug;
   assign enqueue_i1 = ifu_i1_val & ~enqueue_debug;
   assign enqueue_count = {1'b0, enqueue_i0} + {1'b0, enqueue_i1};
   assign dequeue_count = {1'b0, dec_i0_decode_d} + {1'b0, dec_i1_decode_d};

   logic [36:0]  ifu_i1_pcdata, ifu_i0_pcdata;

   assign ifu_i1_pcdata[36:0] = { ifu_i1_icaf_second, ifu_i1_dbecc, ifu_i1_sbecc, ifu_i1_perr, ifu_i1_icaf,
                                  ifu_i1_pc[31:1], ifu_i1_pc4 };
   assign ifu_i0_pcdata[36:0] = { ifu_i0_icaf_second, ifu_i0_dbecc, ifu_i0_sbecc, ifu_i0_perr, ifu_i0_icaf,
                                  ifu_i0_pc[31:1], ifu_i0_pc4 };

   assign dec_i0_icaf_second_d = pc0[36];   // icaf's can only decode as i0

   assign dec_i1_dbecc_d = pc1[35];
   assign dec_i0_dbecc_d = pc0[35];

   assign dec_i1_sbecc_d = pc1[34];
   assign dec_i0_sbecc_d = pc0[34];

   assign dec_i1_perr_d = pc1[33];
   assign dec_i0_perr_d = pc0[33];

   assign dec_i1_icaf_d = pc1[32];
   assign dec_i0_icaf_d = pc0[32];

   assign dec_i1_pc_d[31:1] = pc1[31:1];
   assign dec_i0_pc_d[31:1] = pc0[31:1];

   assign dec_i1_pc4_d = pc1[0];
   assign dec_i0_pc4_d = pc0[0];

// GPR accesses

// put reg to read on rs1
// read ->   or %x0,  %reg,%x0      {000000000000,reg[4:0],110000000110011}

// put write date on rs1
// write ->  or %reg, %x0, %x0      {00000000000000000110,reg[4:0],0110011}


// CSR accesses
// csr is of form rd, csr, rs1

// read  -> csrrs %x0, %csr, %x0     {csr[11:0],00000010000001110011}

// put write data on rs1
// write -> csrrw %x0, %csr, %x0     {csr[11:0],00000001000001110011}

// abstract memory command not done here
   assign debug_valid = dbg_cmd_valid & (dbg_cmd_type[1:0] != 2'h2);


   assign debug_read  = debug_valid & ~dbg_cmd_write;
   assign debug_write = debug_valid &  dbg_cmd_write;

   assign debug_read_gpr  = debug_read  & (dbg_cmd_type[1:0]==2'h0);
   assign debug_write_gpr = debug_write & (dbg_cmd_type[1:0]==2'h0);
   assign debug_read_csr  = debug_read  & (dbg_cmd_type[1:0]==2'h1);
   assign debug_write_csr = debug_write & (dbg_cmd_type[1:0]==2'h1);

   assign dreg[4:0]  = dbg_cmd_addr[4:0];
   assign dcsr[11:0] = dbg_cmd_addr[11:0];


   assign ib0_debug_in[31:0] = ({32{debug_read_gpr}}  & {12'b000000000000,dreg[4:0],15'b110000000110011}) |
                               ({32{debug_write_gpr}} & {20'b00000000000000000110,dreg[4:0],7'b0110011}) |
                               ({32{debug_read_csr}}  & {dcsr[11:0],20'b00000010000001110011}) |
                               ({32{debug_write_csr}} & {dcsr[11:0],20'b00000001000001110011});


   // machine is in halted state, pipe empty, write will always happen next cycle
   rvdff #(1) debug_wdata_rs1ff (.*, .clk(free_clk), .din(debug_write_gpr | debug_write_csr), .dout(dec_debug_wdata_rs1_d));


   // special fence csr for use only in debug mode

   logic                       debug_fence_in;

   assign debug_fence_in = debug_write_csr & (dcsr[11:0] == 12'h7c4);

   rvdff #(1) debug_fence_ff (.*,  .clk(free_clk), .din(debug_fence_in),  .dout(dec_debug_fence_d));


   assign ib_tail = ib_head + ib_count[1:0];
   assign ib_head_in = flush_final ? 2'd0 : ib_head + dequeue_count;
   assign ib_count_in = flush_final ? 3'd0 :
                        ib_count - {1'b0, dequeue_count} + {1'b0, enqueue_count};
   rvdff #(2) ib_head_ff (.*, .clk(active_clk), .din(ib_head_in), .dout(ib_head));
   rvdff #(3) ib_count_ff (.*, .clk(active_clk), .din(ib_count_in), .dout(ib_count));

   assign enqueue_payload[0].instr = enqueue_debug ? ib0_debug_in : ifu_i0_instr;
   assign enqueue_payload[0].pcdata = ifu_i0_pcdata;
   assign enqueue_payload[0].cinst = ifu_i0_cinst;
   assign enqueue_payload[0].brp = i0_brp;
   assign enqueue_payload[1].instr = ifu_i1_instr;
   assign enqueue_payload[1].pcdata = ifu_i1_pcdata;
   assign enqueue_payload[1].cinst = ifu_i1_cinst;
   assign enqueue_payload[1].brp = i1_brp;
   assign enqueue_payload[0].predecode = enqueue_predecode[0];
   assign enqueue_payload[1].predecode = enqueue_predecode[1];
   assign enqueue_payload[0].regs.rs1 = enqueue_payload[0].instr[19:15];
   assign enqueue_payload[0].regs.rs2 = enqueue_payload[0].instr[24:20];
   assign enqueue_payload[0].regs.rd  = enqueue_payload[0].instr[11:7];
   assign enqueue_payload[1].regs.rs1 = enqueue_payload[1].instr[19:15];
   assign enqueue_payload[1].regs.rs2 = enqueue_payload[1].instr[24:20];
   assign enqueue_payload[1].regs.rd  = enqueue_payload[1].instr[11:7];

   // Move the large generated instruction decoder to the enqueue side of the
   // queue.  Its one-hot result is stored with the instruction and becomes a
   // registered micro-op at the decode boundary.  Raw opcode/funct bits no
   // longer drive dual-issue, LSU, multiply and divide control in one cycle.
   dec_dec_ctl enqueue_i0_decoder (
      .inst(enqueue_debug ? ib0_debug_in : ifu_i0_instr),
      .out (enqueue_predecode[0])
   );
   dec_dec_ctl enqueue_i1_decoder (
      .inst(ifu_i1_instr),
      .out (enqueue_predecode[1])
   );

   // Ring storage never moves resident payloads.  Dequeue changes only the
   // two-bit head pointer; enqueue writes one or two free slots at the tail.
   // This removes the LSU/decode-stall compaction cone from all payload D pins.
   always_comb begin
      for (int slot = 0; slot < 4; slot++) begin
         ib_entry_write_en[slot] = 1'b0;
         ib_entry_write_data[slot] = '0;
         if (enqueue_i0 && (ib_tail == 2'(slot))) begin
            ib_entry_write_en[slot] = 1'b1;
            ib_entry_write_data[slot] = enqueue_payload[0];
         end
         if (enqueue_i1 && ((ib_tail + 2'd1) == 2'(slot))) begin
            ib_entry_write_en[slot] = 1'b1;
            ib_entry_write_data[slot] = enqueue_payload[1];
         end
      end
      if (flush_final)
         ib_entry_write_en = 4'b0;
   end

   for (genvar slot = 0; slot < 4; slot++) begin : gen_ib_slot
      rvdffe #($bits(ib_payload_t)) ib_entry_ff (.*, .clk(active_clk),
         .en(ib_entry_write_en[slot]),
         .din(ib_entry_write_data[slot]), .dout(ib_entry[slot]));
   end

   // Keep the two decode-visible payloads in a registered front window.  The
   // ring still avoids moving resident entries, while decode no longer sees a
   // four-way payload mux followed by its high-fanout control cone.  Write
   // bypasses preserve zero-extra-latency visibility when an empty queue is
   // filled or a dequeue and enqueue land on the same physical slot.
   always_comb begin
      ib_front_in[0] = flush_final ? '0 : ib_entry[ib_head_in];
      ib_front_in[1] = flush_final ? '0 : ib_entry[ib_head_in + 2'd1];
      for (int slot = 0; slot < 4; slot++) begin
         if (ib_entry_write_en[slot] && (ib_head_in == 2'(slot)))
            ib_front_in[0] = ib_entry_write_data[slot];
         if (ib_entry_write_en[slot] && ((ib_head_in + 2'd1) == 2'(slot)))
            ib_front_in[1] = ib_entry_write_data[slot];
      end
   end

   rvdff #($bits(ib_payload_t)) ib_front0_ff (.*, .clk(active_clk),
      .din(ib_front_in[0]), .dout(ib_front[0]));
   rvdff #($bits(ib_payload_t)) ib_front1_ff (.*, .clk(active_clk),
      .din(ib_front_in[1]), .dout(ib_front[1]));

   assign ib0 = ib_front[0].instr;
   assign ib1 = ib_front[1].instr;
   assign pc0 = ib_front[0].pcdata;
   assign pc1 = ib_front[1].pcdata;
   assign cinst0 = ib_front[0].cinst;
   assign cinst1 = ib_front[1].cinst;
   assign bp0 = ib_front[0].brp;
   assign bp1 = ib_front[1].brp;
   assign predecode0 = ib_front[0].predecode;
   assign predecode1 = ib_front[1].predecode;
   assign regs0 = ib_front[0].regs;
   assign regs1 = ib_front[1].regs;

   assign dec_ib3_valid_d = (total_count > 3'd3) & ~flush_final;
   assign dec_ib2_valid_d = (total_count > 3'd2) & ~flush_final;
   assign dec_ib1_valid_d = (total_count > 3'd1) & ~flush_final;
   assign dec_ib0_valid_d = (total_count > 3'd0) & ~flush_final;

   assign dec_i0_instr_d = ib0;
   assign dec_i1_instr_d = ib1;
   assign dec_i0_cinst_d = cinst0;
   assign dec_i1_cinst_d = cinst1;
   assign dec_i0_predecode_d = predecode0;
   assign dec_i1_predecode_d = predecode1;
   assign dec_i0_regs_d = regs0;
   assign dec_i1_regs_d = regs1;

   assign dec_i0_brp = bp0;
   assign dec_i1_brp = bp1;


endmodule
