// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.


module exu_div_ctl
   import mycpu_types::*;
(
   input logic         clk,
   input logic         active_clk,
   input logic         rst_l,
   input logic         scan_mode,

   input logic         dec_tlu_fast_div_disable,

   input logic  [31:0] dividend,
   input logic  [31:0] divisor,

   input div_pkt_t     dp,

   input logic         flush_lower,


   output logic        valid_ff_e1,
   output logic        finish_early,
   output logic        finish,
   output logic        div_stall,

   output logic [31:0] out
  );


   logic         run_in, run_state;
   logic [5:0]   count_in, count;
   logic [32:0]  m_ff;
   logic         qff_enable;
   logic         aff_enable;
   logic [32:0]  q_in, q_ff;
   logic [32:0]  a_in, a_ff;
   logic [32:0]  m_eff;
   logic [32:0]  a_shift;
   logic         dividend_neg_ff, divisor_neg_ff;
   logic [31:0]  dividend_comp;
   logic [31:0]  dividend_eff;
   logic [31:0]  q_ff_comp;
   logic [31:0]  q_ff_eff;
   logic [31:0]  a_ff_comp;
   logic [31:0]  a_ff_eff;
   logic         sign_ff;
   logic         signed_op_ff;
   logic         rem_ff;
   logic         add;
   logic [32:0]  a_eff;
   logic [64:0]  a_eff_shift;
   logic         rem_correct;
   logic         flush_lower_ff;
   logic         valid_e1;

   logic         smallnum_case, smallnum_case_ff;
   logic [3:0]   smallnum, smallnum_ff;
   logic         m_already_comp;


   rvdff  #(1)  flush_any_ff      (.*, .clk(active_clk), .din(flush_lower),                                .dout(flush_lower_ff));
   rvdff  #(1)  e1val_ff          (.*, .clk(active_clk), .din(dp.valid & ~flush_lower_ff),                 .dout(valid_ff_e1));
   rvdff  #(1)  runff             (.*, .clk(active_clk), .din(run_in),                                     .dout(run_state));
   rvdff  #(6)  countff           (.*, .clk(active_clk), .din(count_in[5:0]),                              .dout(count[5:0]));


   rvdffs #(3)  miscf             (.*, .clk(active_clk), .din({dividend[31],~dp.unsign,dp.rem}),           .dout({dividend_neg_ff,signed_op_ff,rem_ff}), .en(dp.valid));
   rvdff  #(5)  smallnumff        (.*, .clk(active_clk), .din({smallnum_case,smallnum[3:0]}),              .dout({smallnum_case_ff,smallnum_ff[3:0]}));
   rvdffe #(33) mff               (.*, .en(dp.valid),    .din({ ~dp.unsign & divisor[31], divisor[31:0]}), .dout(m_ff[32:0]));
   rvdffe #(33) qff               (.*, .en(qff_enable),  .din(q_in[32:0]),                                 .dout(q_ff[32:0]));
   rvdffe #(33) aff               (.*, .en(aff_enable),  .din(a_in[32:0]),                                 .dout(a_ff[32:0]));

   rvtwoscomp #(32) dividend_c    (.din(q_ff[31:0]), .dout(dividend_comp[31:0]));
   rvtwoscomp #(32) q_ff_c        (.din(q_ff[31:0]), .dout(q_ff_comp[31:0]));
   rvtwoscomp #(32) a_ff_c        (.din(a_ff[31:0]), .dout(a_ff_comp[31:0]));


   assign divisor_neg_ff          = m_ff[31];
   assign sign_ff                 = signed_op_ff & (m_ff[31:0] != 32'b0);

   assign valid_e1                = valid_ff_e1 & ~flush_lower_ff;


   assign smallnum_case           = ((q_ff[31:4] == 28'b0) & (m_ff[31:4] == 28'b0) & (m_ff[31:0] != 32'b0) & ~rem_ff & valid_e1 & ~dec_tlu_fast_div_disable) |
                                    ((q_ff[31:0] == 32'b0) &                         (m_ff[31:0] != 32'b0) & ~rem_ff & valid_e1 & ~dec_tlu_fast_div_disable);


   assign smallnum[3]             = ( q_ff[3] &                                  ~m_ff[3] & ~m_ff[2] & ~m_ff[1]           );


   assign smallnum[2]             = ( q_ff[3] &                                  ~m_ff[3] & ~m_ff[2] &            ~m_ff[0]) |
                                    ( q_ff[2] &                                  ~m_ff[3] & ~m_ff[2] & ~m_ff[1]           ) |
                                    ( q_ff[3] &  q_ff[2] &                       ~m_ff[3] & ~m_ff[2]                      );


   assign smallnum[1]             = ( q_ff[2] &                                  ~m_ff[3] & ~m_ff[2] &            ~m_ff[0]) |
                                    (                       q_ff[1] &            ~m_ff[3] & ~m_ff[2] & ~m_ff[1]           ) |
                                    ( q_ff[3] &                                  ~m_ff[3] &            ~m_ff[1] & ~m_ff[0]) |
                                    ( q_ff[3] & ~q_ff[2] &                       ~m_ff[3] & ~m_ff[2] &  m_ff[1] &  m_ff[0]) |
                                    (~q_ff[3] &  q_ff[2] &  q_ff[1] &            ~m_ff[3] & ~m_ff[2]                      ) |
                                    ( q_ff[3] &  q_ff[2] &                       ~m_ff[3] &                       ~m_ff[0]) |
                                    ( q_ff[3] &  q_ff[2] &                       ~m_ff[3] &  m_ff[2] & ~m_ff[1]           ) |
                                    ( q_ff[3] &             q_ff[1] & ~m_ff[3] &                       ~m_ff[1]           ) |
                                    ( q_ff[3] &  q_ff[2] &  q_ff[1] &            ~m_ff[3] &  m_ff[2]                      );


   assign smallnum[0]             = (            q_ff[2] &  q_ff[1] &  q_ff[0] & ~m_ff[3] &            ~m_ff[1]           ) |
                                    ( q_ff[3] & ~q_ff[2] &  q_ff[0] &            ~m_ff[3] &             m_ff[1] &  m_ff[0]) |
                                    (            q_ff[2] &                       ~m_ff[3] &            ~m_ff[1] & ~m_ff[0]) |
                                    (                       q_ff[1] &            ~m_ff[3] & ~m_ff[2] &            ~m_ff[0]) |
                                    (                                  q_ff[0] & ~m_ff[3] & ~m_ff[2] & ~m_ff[1]           ) |
                                    (~q_ff[3] &  q_ff[2] & ~q_ff[1] &            ~m_ff[3] & ~m_ff[2] &  m_ff[1] &  m_ff[0]) |
                                    (~q_ff[3] &  q_ff[2] &  q_ff[1] &            ~m_ff[3] &                       ~m_ff[0]) |
                                    ( q_ff[3] &                                             ~m_ff[2] & ~m_ff[1] & ~m_ff[0]) |
                                    ( q_ff[3] & ~q_ff[2] &                       ~m_ff[3] &  m_ff[2] &  m_ff[1]           ) |
                                    (~q_ff[3] &  q_ff[2] &  q_ff[1] &            ~m_ff[3] &  m_ff[2] & ~m_ff[1]           ) |
                                    (~q_ff[3] &  q_ff[2] &             q_ff[0] & ~m_ff[3] &            ~m_ff[1]           ) |
                                    ( q_ff[3] & ~q_ff[2] & ~q_ff[1] &            ~m_ff[3] &  m_ff[2] &             m_ff[0]) |
                                    (           ~q_ff[2] &  q_ff[1] &  q_ff[0] & ~m_ff[3] & ~m_ff[2]                      ) |
                                    ( q_ff[3] &  q_ff[2] &                                             ~m_ff[1] & ~m_ff[0]) |
                                    ( q_ff[3] &             q_ff[1] &                       ~m_ff[2] &            ~m_ff[0]) |
                                    (~q_ff[3] &  q_ff[2] &  q_ff[1] &  q_ff[0] & ~m_ff[3] &  m_ff[2]                      ) |
                                    ( q_ff[3] &  q_ff[2] &                        m_ff[3] & ~m_ff[2]                      ) |
                                    ( q_ff[3] &             q_ff[1] &             m_ff[3] & ~m_ff[2] & ~m_ff[1]           ) |
                                    ( q_ff[3] &                        q_ff[0] &            ~m_ff[2] & ~m_ff[1]           ) |
                                    ( q_ff[3] &            ~q_ff[1] &            ~m_ff[3] &  m_ff[2] &  m_ff[1] &  m_ff[0]) |
                                    ( q_ff[3] &  q_ff[2] &  q_ff[1] &             m_ff[3] &                       ~m_ff[0]) |
                                    ( q_ff[3] &  q_ff[2] &  q_ff[1] &             m_ff[3] &            ~m_ff[1]           ) |
                                    ( q_ff[3] &  q_ff[2] &             q_ff[0] &  m_ff[3] &            ~m_ff[1]           ) |
                                    ( q_ff[3] & ~q_ff[2] &  q_ff[1] &            ~m_ff[3] &             m_ff[1]           ) |
                                    ( q_ff[3] &             q_ff[1] &  q_ff[0] &            ~m_ff[2]                      ) |
                                    ( q_ff[3] &  q_ff[2] &  q_ff[1] &  q_ff[0] &  m_ff[3]                                 );


   logic [4:0]   a_cls;
   logic [4:0]   b_cls;
   logic [5:0]   shortq;
   logic [5:0]   shortq_shift;
   logic [5:0]   shortq_shift_ff;
   logic         shortq_enable;
   logic         shortq_enable_ff;
   logic [32:0]  short_dividend;

   assign short_dividend[31:0]    =  q_ff[31:0];
   assign short_dividend[32]      =  sign_ff & q_ff[31];


   logic [3:0]   shortq_raw;
   logic [3:0]   shortq_shift_xx;

   assign a_cls[4:3]              =  2'b0;
   assign a_cls[2]                =  (~short_dividend[32] & (short_dividend[31:24] != {8{1'b0}})) | ( short_dividend[32] & (short_dividend[31:23] != {9{1'b1}}));
   assign a_cls[1]                =  (~short_dividend[32] & (short_dividend[23:16] != {8{1'b0}})) | ( short_dividend[32] & (short_dividend[22:15] != {8{1'b1}}));
   assign a_cls[0]                =  (~short_dividend[32] & (short_dividend[15:08] != {8{1'b0}})) | ( short_dividend[32] & (short_dividend[14:07] != {8{1'b1}}));

   assign b_cls[4:3]              =  2'b0;
   assign b_cls[2]                =  (~m_ff[32]           & (          m_ff[31:24] != {8{1'b0}})) | ( m_ff[32]           & (          m_ff[31:24] != {8{1'b1}}));
   assign b_cls[1]                =  (~m_ff[32]           & (          m_ff[23:16] != {8{1'b0}})) | ( m_ff[32]           & (          m_ff[23:16] != {8{1'b1}}));
   assign b_cls[0]                =  (~m_ff[32]           & (          m_ff[15:08] != {8{1'b0}})) | ( m_ff[32]           & (          m_ff[15:08] != {8{1'b1}}));

   assign shortq_raw[3]           = ( (a_cls[2:1] == 2'b01 ) & (b_cls[2]   == 1'b1  ) ) |
                                    ( (a_cls[2:0] == 3'b001) & (b_cls[2]   == 1'b1  ) ) |
                                    ( (a_cls[2:0] == 3'b000) & (b_cls[2]   == 1'b1  ) ) |
                                    ( (a_cls[2:0] == 3'b001) & (b_cls[2:1] == 2'b01 ) ) |
                                    ( (a_cls[2:0] == 3'b000) & (b_cls[2:1] == 2'b01 ) ) |
                                    ( (a_cls[2:0] == 3'b000) & (b_cls[2:0] == 3'b001) );

   assign shortq_raw[2]           = ( (a_cls[2]   == 1'b1  ) & (b_cls[2]   == 1'b1  ) ) |
                                    ( (a_cls[2:1] == 2'b01 ) & (b_cls[2:1] == 2'b01 ) ) |
                                    ( (a_cls[2:0] == 3'b001) & (b_cls[2:0] == 3'b001) ) |
                                    ( (a_cls[2:0] == 3'b000) & (b_cls[2:0] == 3'b000) );

   assign shortq_raw[1]           = ( (a_cls[2]   == 1'b1  ) & (b_cls[2:1] == 2'b01 ) ) |
                                    ( (a_cls[2:1] == 2'b01 ) & (b_cls[2:0] == 3'b001) ) |
                                    ( (a_cls[2:0] == 3'b001) & (b_cls[2:0] == 3'b000) );

   assign shortq_raw[0]           = ( (a_cls[2]   == 1'b1  ) & (b_cls[2:0] == 3'b001) ) |
                                    ( (a_cls[2:1] == 2'b01 ) & (b_cls[2:0] == 3'b000) );


   assign shortq_enable           =  valid_ff_e1 & (m_ff[31:0] != 32'b0) & (shortq_raw[3:0] != 4'b0);

   assign shortq_shift[3:0]       = ({4{shortq_enable}} & shortq_raw[3:0]);

   rvdff  #(5)  i_shortq_ff       (.*, .clk(active_clk), .din({shortq_enable,shortq_shift[3:0]}), .dout({shortq_enable_ff,shortq_shift_xx[3:0]}));

   assign shortq_shift_ff[5:0]    = ({6{shortq_shift_xx[3]}} & 6'b01_1111) |
                                    ({6{shortq_shift_xx[2]}} & 6'b01_1000) |
                                    ({6{shortq_shift_xx[1]}} & 6'b01_0000) |
                                    ({6{shortq_shift_xx[0]}} & 6'b00_1000);


   assign div_stall               =  run_state;

   assign run_in                  = (dp.valid | run_state) & ~finish & ~flush_lower_ff;

   assign count_in[5:0]           = {6{run_state & ~finish & ~flush_lower_ff & ~shortq_enable}} & (count[5:0] + shortq_shift_ff[5:0] + 6'd1);


   assign finish_early            =  smallnum_case;

   assign finish                  = (smallnum_case | ((~rem_ff) ? (count[5:0] == 6'd32) : (count[5:0] == 6'd33))) & ~flush_lower & ~flush_lower_ff;

   assign q_in[32:0]              = ({33{~run_state                                   }} &  {1'b0,dividend[31:0]}) |
                                    ({33{ run_state &  (valid_ff_e1 | shortq_enable_ff)}} &  ({dividend_eff[31:0], ~a_in[32]} << shortq_shift_ff[5:0])) |
                                    ({33{ run_state & ~(valid_ff_e1 | shortq_enable_ff)}} &  {q_ff[31:0], ~a_in[32]});

   assign qff_enable              =  dp.valid | (run_state & ~shortq_enable);


   assign dividend_eff[31:0]      = (sign_ff & dividend_neg_ff) ? dividend_comp[31:0] : q_ff[31:0];


   assign m_eff[32:0]             = (add) ? m_ff[32:0] : ~m_ff[32:0];

   assign a_eff_shift[64:0]       = {33'b0, dividend_eff[31:0]} << shortq_shift_ff[5:0];

   assign a_eff[32:0]             = ({33{ rem_correct                    }} &  a_ff[32:0]           ) |
                                    ({33{~rem_correct & ~shortq_enable_ff}} & {a_ff[31:0], q_ff[32]}) |
                                    ({33{~rem_correct &  shortq_enable_ff}} &  a_eff_shift[64:32]   );

   assign a_shift[32:0]           = {33{run_state}} & a_eff[32:0];

   assign a_in[32:0]              = {33{run_state}} & (a_shift[32:0] + m_eff[32:0] + {32'b0,~add});

   assign aff_enable              =  dp.valid | (run_state & ~shortq_enable & (count[5:0]!=6'd33)) | rem_correct;


   assign m_already_comp          = (divisor_neg_ff & sign_ff);


   assign add                     = (a_ff[32] | rem_correct) ^ m_already_comp;

   assign rem_correct             = (count[5:0] == 6'd33) & rem_ff & a_ff[32];


   assign q_ff_eff[31:0]          = (sign_ff & (dividend_neg_ff ^ divisor_neg_ff)) ? q_ff_comp[31:0] : q_ff[31:0];

   assign a_ff_eff[31:0]          = (sign_ff &  dividend_neg_ff) ? a_ff_comp[31:0] : a_ff[31:0];

   assign out[31:0]               = ({32{ smallnum_case_ff          }} & {28'b0, smallnum_ff[3:0]}) |
                                    ({32{                     rem_ff}} &  a_ff_eff[31:0]          ) |
                                    ({32{~smallnum_case_ff & ~rem_ff}} &  q_ff_eff[31:0]          );


endmodule
