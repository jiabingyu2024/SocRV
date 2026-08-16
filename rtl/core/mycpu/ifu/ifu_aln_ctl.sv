


module ifu_aln_ctl
   import mycpu_types::*;
(

   input logic        active_clk,

   input logic        iccm_rd_ecc_single_err,
   input logic [7:0]  iccm_rd_ecc_double_err,
   input logic        fetch_parity_error,

   input logic        fetch_parity_qualifier_f2,

   input logic [7:0]  fetch_access_fault_f2,
   input logic [`RV_BHT_GHR_RANGE]  ifu_bp_fghr_f2,
   input logic [31:1] ifu_bp_btb_target_f2,
   input logic [11:0] ifu_bp_poffset_f2,

   input logic [7:0]  ifu_bp_hist0_f2,
   input logic [7:0]  ifu_bp_hist1_f2,
   input logic [7:0]  ifu_bp_pc4_f2,
   input logic [7:0]  ifu_bp_way_f2,
   input logic [7:0]  ifu_bp_valid_f2,
   input logic [7:0]  ifu_bp_ret_f2,

   input logic exu_flush_final,

   input logic dec_ib3_valid_d,
   input logic dec_ib2_valid_d,

   input logic dec_ib0_valid_eff_d,
   input logic dec_ib1_valid_eff_d,


   input logic [127:0] ifu_fetch_data,

   input fetch_error_pkt_t fetch_error_f2,


   input logic [7:0]   ifu_fetch_val,
   input logic [31:1]  ifu_fetch_pc,


   input logic   rst_l,
   input logic   clk,
   input logic   dec_tlu_core_ecc_disable,

   output logic ifu_i0_valid,
   output logic ifu_i1_valid,
   output logic ifu_i0_icaf,
   output logic ifu_i1_icaf,
   output logic ifu_i0_icaf_second,
   output logic ifu_i1_icaf_second,
   output logic ifu_i0_perr,
   output logic ifu_i1_perr,
   output logic ifu_i0_sbecc,
   output logic ifu_i1_sbecc,
   output logic ifu_i0_dbecc,
   output logic ifu_i1_dbecc,
   output logic [31:0] ifu_i0_instr,
   output logic [31:0] ifu_i1_instr,
   output logic [31:1] ifu_i0_pc,
   output logic [31:1] ifu_i1_pc,
   output logic ifu_i0_pc4,
   output logic ifu_i1_pc4,

   output logic ifu_fb_consume1,
   output logic ifu_fb_consume2,
   output logic [15:0] ifu_illegal_inst,

   output br_pkt_t i0_brp,
   output br_pkt_t i1_brp,

   output logic [1:0] ifu_pmu_instr_aligned,
   output logic       ifu_pmu_align_stall,

   output logic [16:2] ifu_fetch_error_index,
   output logic        ifu_fetch_parity_error_valid,
   output logic        ifu_fetch_single_bit_error,

   output logic [15:0] ifu_i0_cinst,
   output logic [15:0] ifu_i1_cinst,

   input  logic    scan_mode


   );

`include "core_params.svh"

   logic         ifvalid;
   logic         shift_f1_f0, shift_f2_f0, shift_f2_f1;
   logic         fetch_to_f0, fetch_to_f1, fetch_to_f2;

   logic [7:0]   f2val_in, f2val;
   logic [7:0]   f1val_in, f1val;
   logic [7:0]   f0val_in, f0val;

   logic [7:0]   sf1val, sf0val;

   logic [31:1]  f2pc_in, f2pc;
   logic [31:1]  f1pc_in, f1pc;
   logic [31:1]  f0pc_in, f0pc;
   logic [31:1]  sf1pc, sf0pc;

   logic [63:0]  aligndata;
   logic         first4B, first2B;
   logic         second4B, second2B;

   logic         third4B, third2B;
   logic [31:0]  uncompress0, uncompress1, uncompress2;
   logic         ibuffer_room1_more;
   logic         ibuffer_room2_more;
   logic         i0_shift, i1_shift;
   logic         shift_2B, shift_4B, shift_6B, shift_8B;
   logic         f1_shift_2B, f1_shift_4B, f1_shift_6B;
   logic         f2_valid, sf1_valid, sf0_valid;

   logic [31:0]  ifirst, isecond, ithird;
   logic [31:1]  f0pc_plus1, f0pc_plus2, f0pc_plus3, f0pc_plus4;
   logic [31:1]  f1pc_plus1, f1pc_plus2, f1pc_plus3;
   logic [3:0]   alignval;
   logic [31:1]  firstpc, secondpc, thirdpc, fourthpc;

   logic [11:0]  f1poffset;
   logic [11:0]  f0poffset;
   logic [`RV_BHT_GHR_RANGE]  f1fghr;
   logic [`RV_BHT_GHR_RANGE]  f0fghr;
   logic [7:0]               f1hist1;
   logic [7:0]               f0hist1;
   logic [7:0]               f1hist0;
   logic [7:0]               f0hist0;
   logic [7:0]             f1pc4;
   logic [7:0]             f0pc4;

   logic [7:0]             f1ret;
   logic [7:0]             f0ret;
   logic [7:0]             f1way;
   logic [7:0]             f0way;

   logic [7:0]               f1brend;
   logic [7:0]               f0brend;

   logic [3:0]   alignbrend;
   logic [3:0]   alignpc4;
   logic [3:0]   alignparity;
   logic [3:0]   alignret;
   logic [3:0]   alignway;
   logic [3:0]   alignhist1;

   logic [3:0]   alignhist0;
   logic [3:1]   alignfromf1;
   logic         i0_ends_f1, i1_ends_f1;
   logic         i0_br_start_error, i1_br_start_error;

   logic [31:1]  f1prett;
   logic [31:1]  f0prett;
   logic [7:0]   f1dbecc;
   logic [7:0]   f0dbecc;
   logic         f1sbecc;
   logic         f0sbecc;
   logic         f1perr;
   logic         f0perr;
   logic         f1icfetch;
   logic         f0icfetch;
   logic [7:0]   f1icaf;
   logic [7:0]   f0icaf;

   logic [3:0]   alignicfetch;
   logic [3:0]   aligntagperr;
   logic [3:0]   aligndataperr;
   logic [3:0]   alignsbecc;
   logic [3:0]   aligndbecc;
   logic [3:0]   alignicaf;
   logic         i0_brp_pc4, i1_brp_pc4;

   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] firstpc_hash, secondpc_hash, thirdpc_hash, fourthpc_hash;

   logic         i0_illegal, i1_illegal;
   logic         shift_illegal;
   logic         first_legal, second_legal, third_legal;
   logic [15:0]  illegal_inst;
   logic         illegal_inst_en;
   logic         illegal_lockout_in, illegal_lockout;

   logic [3:0]   alignfinalperr;

   logic f2_wr_en;

   assign f2_wr_en = fetch_to_f2;

   logic f0_shift_wr_en;

   assign f0_shift_wr_en = (fetch_to_f0 | shift_f2_f0 | shift_f1_f0 | shift_2B | shift_4B | shift_6B | shift_8B);

   logic f1_shift_wr_en;

   assign f1_shift_wr_en = (fetch_to_f1 | shift_f2_f1 | f1_shift_2B | f1_shift_4B | f1_shift_6B);

   logic [1:0] wrptr, wrptr_in;
   logic [1:0] rdptr, rdptr_in;
   logic [2:0] qwen;
   logic [127:0] q2,q1,q0;
   logic [2:0]   first_offset, second_offset;
   logic [2:0]   q2off_eff, q2off_in, q2off;
   logic [2:0]   q1off_eff, q1off_in, q1off;
   logic [2:0]   q0off_eff, q0off_in, q0off;
   logic         f0_shift_2B, f0_shift_4B, f0_shift_6B, f0_shift_8B;

   logic [127:0] q0eff;
   logic [127:0] q0final;
   logic [2:0]   q0ptr;
   logic [7:0]   q0sel;

   logic [127:0] q1eff;
   logic [127:0] q1final;
   logic [2:0]   q1ptr;
   logic [7:0]   q1sel;

   logic [2:0]   qren;

   logic         consume_fb1, consume_fb0;
   logic [3:0]   icaf_eff;

   logic [7:0]   q0parity, q1parity, q2parity;
   logic [7:0]   q0parityeff, q1parityeff;
   logic [7:0]   q0parityfinal, q1parityfinal;


   assign wrptr_in[1:0] =  (({2{wrptr[1:0]==2'b00 & ifvalid}} & 2'b01) |
                            ({2{wrptr[1:0]==2'b01 & ifvalid}} & 2'b10) |
                            ({2{wrptr[1:0]==2'b10 & ifvalid}} & 2'b00) |
                            ({2{~ifvalid}} & wrptr[1:0])) & ~{2{exu_flush_final}};

   rvdff #(2) wrpff (.*, .clk(active_clk), .din(wrptr_in[1:0]), .dout(wrptr[1:0]));

   assign rdptr_in[1:0] =  (({2{rdptr[1:0]==2'b00 & ifu_fb_consume1}} & 2'b01) |
                            ({2{rdptr[1:0]==2'b01 & ifu_fb_consume1}} & 2'b10) |
                            ({2{rdptr[1:0]==2'b10 & ifu_fb_consume1}} & 2'b00) |
                            ({2{rdptr[1:0]==2'b00 & ifu_fb_consume2}} & 2'b10) |
                            ({2{rdptr[1:0]==2'b01 & ifu_fb_consume2}} & 2'b00) |
                            ({2{rdptr[1:0]==2'b10 & ifu_fb_consume2}} & 2'b01) |
                            ({2{~ifu_fb_consume1&~ifu_fb_consume2}} & rdptr[1:0])) & ~{2{exu_flush_final}};

   rvdff #(2) rdpff (.*, .clk(active_clk), .din(rdptr_in[1:0]), .dout(rdptr[1:0]));

   assign qren[2:0] = { rdptr[1:0]==2'b10,
                        rdptr[1:0]==2'b01,
                        rdptr[1:0]==2'b00
                        };

   assign qwen[2:0] = { wrptr[1:0]==2'b10 & ifvalid,
                        wrptr[1:0]==2'b01 & ifvalid,
                        wrptr[1:0]==2'b00 & ifvalid
                        };


   assign first_offset[2:0]  = {f0_shift_8B,  f0_shift_6B|f0_shift_4B,  f0_shift_6B|f0_shift_2B };

   assign second_offset[2:0] = {1'b0,         f1_shift_6B|f1_shift_4B,  f1_shift_6B|f1_shift_2B };


   assign q2off_eff[2:0] = (rdptr[1:0]==2'd2) ? (q2off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd1) ? (q2off[2:0] + second_offset[2:0]) :
                                                 q2off[2:0];

   assign q2off_in[2:0] = (qwen[2]) ? ifu_fetch_pc[3:1] : q2off_eff[2:0];

   rvdff #(3) q2offsetff (.*, .clk(active_clk), .din(q2off_in[2:0]), .dout(q2off[2:0]));

   assign q1off_eff[2:0] = (rdptr[1:0]==2'd1) ? (q1off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd0) ? (q1off[2:0] + second_offset[2:0]) :
                                                 q1off[2:0];


   assign q1off_in[2:0] = (qwen[1]) ? ifu_fetch_pc[3:1] : q1off_eff[2:0];

   rvdff #(3) q1offsetff (.*, .clk(active_clk), .din(q1off_in[2:0]), .dout(q1off[2:0]));


   assign q0off_eff[2:0] = (rdptr[1:0]==2'd0) ? (q0off[2:0] + first_offset[2:0])  :
                           (rdptr[1:0]==2'd2) ? (q0off[2:0] + second_offset[2:0]) :
                                                 q0off[2:0];


   assign q0off_in[2:0] = (qwen[0]) ? ifu_fetch_pc[3:1] : q0off_eff[2:0];


   rvdff #(3) q0offsetff (.*, .clk(active_clk), .din(q0off_in[2:0]), .dout(q0off[2:0]));

   assign q0ptr[2:0] = (({3{rdptr[1:0]==2'b00}} & q0off[2:0]) |
                        ({3{rdptr[1:0]==2'b01}} & q1off[2:0]) |
                        ({3{rdptr[1:0]==2'b10}} & q2off[2:0]));

   assign q1ptr[2:0] = (({3{rdptr[1:0]==2'b00}} & q1off[2:0]) |
                        ({3{rdptr[1:0]==2'b01}} & q2off[2:0]) |
                        ({3{rdptr[1:0]==2'b10}} & q0off[2:0]));

   assign q0sel[7:0] = { q0ptr[2:0]==3'b111,
                         q0ptr[2:0]==3'b110,
                         q0ptr[2:0]==3'b101,
                         q0ptr[2:0]==3'b100,
                         q0ptr[2:0]==3'b011,
                         q0ptr[2:0]==3'b010,
                         q0ptr[2:0]==3'b001,
                         q0ptr[2:0]==3'b000
                         };

   assign q1sel[7:0] = { q1ptr[2:0]==3'b111,
                         q1ptr[2:0]==3'b110,
                         q1ptr[2:0]==3'b101,
                         q1ptr[2:0]==3'b100,
                         q1ptr[2:0]==3'b011,
                         q1ptr[2:0]==3'b010,
                         q1ptr[2:0]==3'b001,
                         q1ptr[2:0]==3'b000
                         };


   localparam MHI   = 45+`RV_BHT_GHR_SIZE;
   localparam MSIZE = 46+`RV_BHT_GHR_SIZE;

   logic [MHI:0] misc_data_in, misc2, misc1, misc0;
   logic [MHI:0] misc1eff, misc0eff;

   assign misc_data_in[MHI:0] = {
                                  iccm_rd_ecc_single_err,
                                  fetch_parity_qualifier_f2,
                                  fetch_parity_error,

                                  ifu_bp_btb_target_f2[31:1],
                                  ifu_bp_poffset_f2[11:0],
                                  ifu_bp_fghr_f2[`RV_BHT_GHR_RANGE]
                                  };

   rvdffe #(MSIZE) misc2ff (.*, .en(qwen[2]), .din(misc_data_in[MHI:0]), .dout(misc2[MHI:0]));
   rvdffe #(MSIZE) misc1ff (.*, .en(qwen[1]), .din(misc_data_in[MHI:0]), .dout(misc1[MHI:0]));
   rvdffe #(MSIZE) misc0ff (.*, .en(qwen[0]), .din(misc_data_in[MHI:0]), .dout(misc0[MHI:0]));


   assign {misc1eff[MHI:0],misc0eff[MHI:0]} = (({MSIZE*2{qren[0]}} & {misc1[MHI:0],misc0[MHI:0]}) |
                                               ({MSIZE*2{qren[1]}} & {misc2[MHI:0],misc1[MHI:0]}) |
                                               ({MSIZE*2{qren[2]}} & {misc0[MHI:0],misc2[MHI:0]}));
   assign {
            f1sbecc,
            f1icfetch,
            f1perr,

            f1prett[31:1],
            f1poffset[11:0],
            f1fghr[`RV_BHT_GHR_RANGE]
            } = misc1eff[MHI:0];

   assign {
            f0sbecc,
            f0icfetch,
            f0perr,

            f0prett[31:1],
            f0poffset[11:0],
            f0fghr[`RV_BHT_GHR_RANGE]
            } = misc0eff[MHI:0];


   localparam BRDATA_SIZE=64;
   localparam BRDATA_WIDTH = 8;
   logic [BRDATA_SIZE-1:0] brdata_in, brdata2, brdata1, brdata0;
   logic [BRDATA_SIZE-1:0] brdata1eff, brdata0eff;
   logic [BRDATA_SIZE-1:0] brdata1final, brdata0final;
   assign brdata_in[BRDATA_SIZE-1:0] = {
                              iccm_rd_ecc_double_err[7],fetch_access_fault_f2[7],ifu_bp_hist1_f2[7],ifu_bp_hist0_f2[7],ifu_bp_pc4_f2[7],ifu_bp_way_f2[7],ifu_bp_valid_f2[7],ifu_bp_ret_f2[7],
                              iccm_rd_ecc_double_err[6],fetch_access_fault_f2[6],ifu_bp_hist1_f2[6],ifu_bp_hist0_f2[6],ifu_bp_pc4_f2[6],ifu_bp_way_f2[6],ifu_bp_valid_f2[6],ifu_bp_ret_f2[6],
                              iccm_rd_ecc_double_err[5],fetch_access_fault_f2[5],ifu_bp_hist1_f2[5],ifu_bp_hist0_f2[5],ifu_bp_pc4_f2[5],ifu_bp_way_f2[5],ifu_bp_valid_f2[5],ifu_bp_ret_f2[5],
                              iccm_rd_ecc_double_err[4],fetch_access_fault_f2[4],ifu_bp_hist1_f2[4],ifu_bp_hist0_f2[4],ifu_bp_pc4_f2[4],ifu_bp_way_f2[4],ifu_bp_valid_f2[4],ifu_bp_ret_f2[4],
                              iccm_rd_ecc_double_err[3],fetch_access_fault_f2[3],ifu_bp_hist1_f2[3],ifu_bp_hist0_f2[3],ifu_bp_pc4_f2[3],ifu_bp_way_f2[3],ifu_bp_valid_f2[3],ifu_bp_ret_f2[3],
                              iccm_rd_ecc_double_err[2],fetch_access_fault_f2[2],ifu_bp_hist1_f2[2],ifu_bp_hist0_f2[2],ifu_bp_pc4_f2[2],ifu_bp_way_f2[2],ifu_bp_valid_f2[2],ifu_bp_ret_f2[2],
                              iccm_rd_ecc_double_err[1],fetch_access_fault_f2[1],ifu_bp_hist1_f2[1],ifu_bp_hist0_f2[1],ifu_bp_pc4_f2[1],ifu_bp_way_f2[1],ifu_bp_valid_f2[1],ifu_bp_ret_f2[1],
                              iccm_rd_ecc_double_err[0],fetch_access_fault_f2[0],ifu_bp_hist1_f2[0],ifu_bp_hist0_f2[0],ifu_bp_pc4_f2[0],ifu_bp_way_f2[0],ifu_bp_valid_f2[0],ifu_bp_ret_f2[0]
                              };

   rvdffe #(BRDATA_SIZE) brdata2ff (.*, .en(qwen[2]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata2[BRDATA_SIZE-1:0]));
   rvdffe #(BRDATA_SIZE) brdata1ff (.*, .en(qwen[1]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata1[BRDATA_SIZE-1:0]));
   rvdffe #(BRDATA_SIZE) brdata0ff (.*, .en(qwen[0]), .din(brdata_in[BRDATA_SIZE-1:0]), .dout(brdata0[BRDATA_SIZE-1:0]));


   assign {brdata1eff[BRDATA_SIZE-1:0],brdata0eff[BRDATA_SIZE-1:0]} = (({BRDATA_SIZE*2{qren[0]}} & {brdata1[BRDATA_SIZE-1:0],brdata0[BRDATA_SIZE-1:0]}) |
                                                                       ({BRDATA_SIZE*2{qren[1]}} & {brdata2[BRDATA_SIZE-1:0],brdata1[BRDATA_SIZE-1:0]}) |
                                                                       ({BRDATA_SIZE*2{qren[2]}} & {brdata0[BRDATA_SIZE-1:0],brdata2[BRDATA_SIZE-1:0]}));

   assign brdata0final[BRDATA_SIZE-1:0] = (({BRDATA_SIZE{q0sel[0]}} & {            brdata0eff[BRDATA_SIZE-1:0]}) |
                                ({BRDATA_SIZE{q0sel[1]}} & {{1*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:1*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[2]}} & {{2*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:2*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[3]}} & {{3*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:3*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[4]}} & {{4*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:4*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[5]}} & {{5*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:5*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[6]}} & {{6*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:6*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q0sel[7]}} & {{7*BRDATA_WIDTH{1'b0}},brdata0eff[BRDATA_SIZE-1:7*BRDATA_WIDTH]}));

   assign brdata1final[BRDATA_SIZE-1:0] = (({BRDATA_SIZE{q1sel[0]}} & {            brdata1eff[BRDATA_SIZE-1:0]}) |
                                ({BRDATA_SIZE{q1sel[1]}} & {{1*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:1*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[2]}} & {{2*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:2*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[3]}} & {{3*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:3*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[4]}} & {{4*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:4*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[5]}} & {{5*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:5*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[6]}} & {{6*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:6*BRDATA_WIDTH]}) |
                                ({BRDATA_SIZE{q1sel[7]}} & {{7*BRDATA_WIDTH{1'b0}},brdata1eff[BRDATA_SIZE-1:7*BRDATA_WIDTH]}));

   assign {
            f0dbecc[7],f0icaf[7],f0hist1[7],f0hist0[7],f0pc4[7],f0way[7],f0brend[7],f0ret[7],
            f0dbecc[6],f0icaf[6],f0hist1[6],f0hist0[6],f0pc4[6],f0way[6],f0brend[6],f0ret[6],
            f0dbecc[5],f0icaf[5],f0hist1[5],f0hist0[5],f0pc4[5],f0way[5],f0brend[5],f0ret[5],
            f0dbecc[4],f0icaf[4],f0hist1[4],f0hist0[4],f0pc4[4],f0way[4],f0brend[4],f0ret[4],
            f0dbecc[3],f0icaf[3],f0hist1[3],f0hist0[3],f0pc4[3],f0way[3],f0brend[3],f0ret[3],
            f0dbecc[2],f0icaf[2],f0hist1[2],f0hist0[2],f0pc4[2],f0way[2],f0brend[2],f0ret[2],
            f0dbecc[1],f0icaf[1],f0hist1[1],f0hist0[1],f0pc4[1],f0way[1],f0brend[1],f0ret[1],
            f0dbecc[0],f0icaf[0],f0hist1[0],f0hist0[0],f0pc4[0],f0way[0],f0brend[0],f0ret[0]
            } = brdata0final[BRDATA_SIZE-1:0];

   assign {
            f1dbecc[7],f1icaf[7],f1hist1[7],f1hist0[7],f1pc4[7],f1way[7],f1brend[7],f1ret[7],
            f1dbecc[6],f1icaf[6],f1hist1[6],f1hist0[6],f1pc4[6],f1way[6],f1brend[6],f1ret[6],
            f1dbecc[5],f1icaf[5],f1hist1[5],f1hist0[5],f1pc4[5],f1way[5],f1brend[5],f1ret[5],
            f1dbecc[4],f1icaf[4],f1hist1[4],f1hist0[4],f1pc4[4],f1way[4],f1brend[4],f1ret[4],
            f1dbecc[3],f1icaf[3],f1hist1[3],f1hist0[3],f1pc4[3],f1way[3],f1brend[3],f1ret[3],
            f1dbecc[2],f1icaf[2],f1hist1[2],f1hist0[2],f1pc4[2],f1way[2],f1brend[2],f1ret[2],
            f1dbecc[1],f1icaf[1],f1hist1[1],f1hist0[1],f1pc4[1],f1way[1],f1brend[1],f1ret[1],
            f1dbecc[0],f1icaf[0],f1hist1[0],f1hist0[0],f1pc4[0],f1way[0],f1brend[0],f1ret[0]
            } = brdata1final[BRDATA_SIZE-1:0];


   assign f2_valid = f2val[0];

   assign sf1_valid = sf1val[0];

   assign sf0_valid = sf0val[0];


   assign consume_fb0 = ~sf0val[0] & f0val[0];

   assign consume_fb1 = ~sf1val[0] & f1val[0];

   assign ifu_fb_consume1 = consume_fb0 & ~consume_fb1 & ~exu_flush_final;

   assign ifu_fb_consume2 = consume_fb0 &  consume_fb1 & ~exu_flush_final;

   assign ifvalid = ifu_fetch_val[0];

   assign shift_f1_f0 =  ~sf0_valid & sf1_valid;

   assign shift_f2_f0 =  ~sf0_valid & ~sf1_valid & f2_valid;

   assign shift_f2_f1 =  ~sf0_valid & sf1_valid & f2_valid;

   assign fetch_to_f0 =  ~sf0_valid & ~sf1_valid & ~f2_valid & ifvalid;

   assign fetch_to_f1 =  (~sf0_valid & ~sf1_valid &  f2_valid & ifvalid)  |
                         (~sf0_valid &  sf1_valid & ~f2_valid & ifvalid)  |
                         ( sf0_valid & ~sf1_valid & ~f2_valid & ifvalid);

   assign fetch_to_f2 =  (~sf0_valid &  sf1_valid &  f2_valid & ifvalid)  |
                         ( sf0_valid &  sf1_valid & ~f2_valid & ifvalid);


   assign f0pc_plus1[31:1] = f0pc[31:1] + 31'd1;
   assign f0pc_plus2[31:1] = f0pc[31:1] + 31'd2;
   assign f0pc_plus3[31:1] = f0pc[31:1] + 31'd3;
   assign f0pc_plus4[31:1] = f0pc[31:1] + 31'd4;

   assign f1pc_plus1[31:1] = f1pc[31:1] + 31'd1;
   assign f1pc_plus2[31:1] = f1pc[31:1] + 31'd2;
   assign f1pc_plus3[31:1] = f1pc[31:1] + 31'd3;

   assign f2pc_in[31:1] = ifu_fetch_pc[31:1];

   rvdffe #(31) f2pcff (.*, .en(f2_wr_en), .din(f2pc_in[31:1]), .dout(f2pc[31:1]));

   assign sf1pc[31:1] = ({31{f1_shift_2B}} & (f1pc_plus1[31:1])) |
                        ({31{f1_shift_4B}} & (f1pc_plus2[31:1])) |
                        ({31{f1_shift_6B}} & (f1pc_plus3[31:1])) |
                        ({31{~f1_shift_2B&~f1_shift_4B&~f1_shift_6B}} & f1pc[31:1]);

   assign f1pc_in[31:1] = ({31{fetch_to_f1}} & ifu_fetch_pc[31:1]) |
                          ({31{shift_f2_f1}} & f2pc[31:1]) |
                          ({31{~fetch_to_f1&~shift_f2_f1}} & sf1pc[31:1]);

   rvdffe #(31) f1pcff (.*, .en(f1_shift_wr_en), .din(f1pc_in[31:1]), .dout(f1pc[31:1]));

   assign sf0pc[31:1] = ({31{shift_2B}} & (f0pc_plus1[31:1])) |
                        ({31{shift_4B}} & (f0pc_plus2[31:1])) |
                        ({31{shift_6B}} & (f0pc_plus3[31:1])) |
                        ({31{shift_8B}} & (f0pc_plus4[31:1]));

   assign f0pc_in[31:1] = ({31{fetch_to_f0}} & ifu_fetch_pc[31:1]) |
                          ({31{shift_f2_f0}} & f2pc[31:1]) |
                          ({31{shift_f1_f0}} & sf1pc[31:1]) |
                          ({31{~fetch_to_f0&~shift_f2_f0&~shift_f1_f0}} & sf0pc[31:1]);

   rvdffe #(31) f0pcff (.*, .en(f0_shift_wr_en), .din(f0pc_in[31:1]), .dout(f0pc[31:1]));


   assign f2val_in[7:0] = (({8{fetch_to_f2}} & ifu_fetch_val[7:0]) |
                           ({8{~fetch_to_f2&~shift_f2_f1&~shift_f2_f0}} & f2val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f2valff (.*, .clk(active_clk), .din(f2val_in[7:0]), .dout(f2val[7:0]));

   assign sf1val[7:0] = ({8{f1_shift_2B}} & {1'b0,f1val[7:1]}) |
                        ({8{f1_shift_4B}} & {2'b0,f1val[7:2]}) |
                        ({8{f1_shift_6B}} & {3'b0,f1val[7:3]}) |
                        ({8{~f1_shift_2B&~f1_shift_4B&~f1_shift_6B}} & f1val[7:0]);

   assign f1val_in[7:0] = (({8{fetch_to_f1}} & ifu_fetch_val[7:0]) |
                           ({8{shift_f2_f1}} & f2val[7:0]) |
                           ({8{~fetch_to_f1&~shift_f2_f1&~shift_f1_f0}} & sf1val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f1valff (.*, .clk(active_clk), .din(f1val_in[7:0]), .dout(f1val[7:0]));


   assign sf0val[7:0] = ({8{shift_2B}} & {1'b0,f0val[7:1]}) |
                        ({8{shift_4B}} & {2'b0,f0val[7:2]}) |
                        ({8{shift_6B}} & {3'b0,f0val[7:3]}) |
                        ({8{shift_8B}} & {4'b0,f0val[7:4]}) |
                        ({8{~shift_2B&~shift_4B&~shift_6B&~shift_8B}} & f0val[7:0]);

   assign f0val_in[7:0] = (({8{fetch_to_f0}} & ifu_fetch_val[7:0]) |
                           ({8{shift_f2_f0}} & f2val[7:0]) |
                           ({8{shift_f1_f0}} & sf1val[7:0]) |
                           ({8{~fetch_to_f0&~shift_f2_f0&~shift_f1_f0}} & sf0val[7:0])) & ~{8{exu_flush_final}};

   rvdff #(8) f0valff (.*, .clk(active_clk), .din(f0val_in[7:0]), .dout(f0val[7:0]));


   rvdffe #(8) q2parityff (.*, .en(qwen[2]), .din(fetch_error_f2.parity[7:0]), .dout(q2parity[7:0]));
   rvdffe #(8) q1parityff (.*, .en(qwen[1]), .din(fetch_error_f2.parity[7:0]), .dout(q1parity[7:0]));
   rvdffe #(8) q0parityff (.*, .en(qwen[0]), .din(fetch_error_f2.parity[7:0]), .dout(q0parity[7:0]));


   assign {q1parityeff[7:0],q0parityeff[7:0]} = (({16{qren[0]}} & {q1parity[7:0],q0parity[7:0]}) |
                                                 ({16{qren[1]}} & {q2parity[7:0],q1parity[7:0]}) |
                                                 ({16{qren[2]}} & {q0parity[7:0],q2parity[7:0]}));

   assign q0parityfinal[7:0] =   (({8{q0sel[0]}} & {     q0parityeff[7:0]}) |
                                  ({8{q0sel[1]}} & {1'b0,q0parityeff[7:1]}) |
                                  ({8{q0sel[2]}} & {2'b0,q0parityeff[7:2]}) |
                                  ({8{q0sel[3]}} & {3'b0,q0parityeff[7:3]}) |
                                  ({8{q0sel[4]}} & {4'b0,q0parityeff[7:4]}) |
                                  ({8{q0sel[5]}} & {5'b0,q0parityeff[7:5]}) |
                                  ({8{q0sel[6]}} & {6'b0,q0parityeff[7:6]}) |
                                  ({8{q0sel[7]}} & {7'b0,q0parityeff[7]}));

   assign q1parityfinal[7:0] =   (({8{q1sel[0]}} & {     q1parityeff[7:0]}) |
                                  ({8{q1sel[1]}} & {1'b0,q1parityeff[7:1]}) |
                                  ({8{q1sel[2]}} & {2'b0,q1parityeff[7:2]}) |
                                  ({8{q1sel[3]}} & {3'b0,q1parityeff[7:3]}) |
                                  ({8{q1sel[4]}} & {4'b0,q1parityeff[7:4]}) |
                                  ({8{q1sel[5]}} & {5'b0,q1parityeff[7:5]}) |
                                  ({8{q1sel[6]}} & {6'b0,q1parityeff[7:6]}) |
                                  ({8{q1sel[7]}} & {7'b0,q1parityeff[7]}));

   rvdffe #(128) q2ff (.*, .en(qwen[2]), .din(ifu_fetch_data[127:0]), .dout(q2[127:0]));
   rvdffe #(128) q1ff (.*, .en(qwen[1]), .din(ifu_fetch_data[127:0]), .dout(q1[127:0]));
   rvdffe #(128) q0ff (.*, .en(qwen[0]), .din(ifu_fetch_data[127:0]), .dout(q0[127:0]));


   assign {q1eff[127:0],q0eff[127:0]} = (({256{qren[0]}} & {q1[127:0],q0[127:0]}) |
                                         ({256{qren[1]}} & {q2[127:0],q1[127:0]}) |
                                         ({256{qren[2]}} & {q0[127:0],q2[127:0]}));

   assign q0final[127:0] = (({128{q0sel[0]}} & {             q0eff[8*16-1:16*0]}) |
                            ({128{q0sel[1]}} & {{16*1{1'b0}},q0eff[8*16-1:16*1]}) |
                            ({128{q0sel[2]}} & {{16*2{1'b0}},q0eff[8*16-1:16*2]}) |
                            ({128{q0sel[3]}} & {{16*3{1'b0}},q0eff[8*16-1:16*3]}) |
                            ({128{q0sel[4]}} & {{16*4{1'b0}},q0eff[8*16-1:16*4]}) |
                            ({128{q0sel[5]}} & {{16*5{1'b0}},q0eff[8*16-1:16*5]}) |
                            ({128{q0sel[6]}} & {{16*6{1'b0}},q0eff[8*16-1:16*6]}) |
                            ({128{q0sel[7]}} & {{16*7{1'b0}},q0eff[8*16-1:16*7]}));

   assign q1final[127:0] = (({128{q1sel[0]}} & {             q1eff[8*16-1:16*0]}) |
                            ({128{q1sel[1]}} & {{16*1{1'b0}},q1eff[8*16-1:16*1]}) |
                            ({128{q1sel[2]}} & {{16*2{1'b0}},q1eff[8*16-1:16*2]}) |
                            ({128{q1sel[3]}} & {{16*3{1'b0}},q1eff[8*16-1:16*3]}) |
                            ({128{q1sel[4]}} & {{16*4{1'b0}},q1eff[8*16-1:16*4]}) |
                            ({128{q1sel[5]}} & {{16*5{1'b0}},q1eff[8*16-1:16*5]}) |
                            ({128{q1sel[6]}} & {{16*6{1'b0}},q1eff[8*16-1:16*6]}) |
                            ({128{q1sel[7]}} & {{16*7{1'b0}},q1eff[8*16-1:16*7]}));


   assign aligndata[63:0] = ({64{(f0val[3])}} &                  {q0final[4*16-1:0]}) |
                            ({64{(f0val[2]&~f0val[3])}} &        {q1final[1*16-1:0],q0final[3*16-1:0]}) |
                            ({64{(f0val[1]&~f0val[2])}} &        {q1final[2*16-1:0],q0final[2*16-1:0]}) |
                            ({64{(f0val[0]&~f0val[1])}} &        {q1final[3*16-1:0],q0final[1*16-1:0]});

   assign alignval[3:0] =   ({4{(f0val[3])}} &                   4'b1111) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1val[0],3'b111}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1val[1:0],2'b11}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1val[2:0],1'b1});

   assign alignicaf[3:0] =   ({4{(f0val[3])}} &                   f0icaf[3:0]) |
                             ({4{(f0val[2]&~f0val[3])}} &        {f1icaf[0],f0icaf[2:0]}) |
                             ({4{(f0val[1]&~f0val[2])}} &        {f1icaf[1:0],f0icaf[1:0]}) |
                             ({4{(f0val[0]&~f0val[1])}} &        {f1icaf[2:0],f0icaf[0]});

   assign alignsbecc[3:0] =   ({4{(f0val[3])}} &                  {4{f0sbecc}}) |
                              ({4{(f0val[2]&~f0val[3])}} &        {{1{f1sbecc}},{3{f0sbecc}}}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {{2{f1sbecc}},{2{f0sbecc}}}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {{3{f1sbecc}},{1{f0sbecc}}});


   assign aligndbecc[3:0] =   ({4{(f0val[3])}} &                   f0dbecc[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1dbecc[0],f0dbecc[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1dbecc[1:0],f0dbecc[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1dbecc[2:0],f0dbecc[0]});


   assign alignbrend[3:0] =   ({4{(f0val[3])}} &                   f0brend[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1brend[0],f0brend[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1brend[1:0],f0brend[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1brend[2:0],f0brend[0]});

   assign alignpc4[3:0] =   ({4{(f0val[3])}} &                   f0pc4[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1pc4[0],f0pc4[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1pc4[1:0],f0pc4[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1pc4[2:0],f0pc4[0]});

   assign alignparity[3:0] =   ({4{(f0val[3])}} &                                      q0parityfinal[3:0]) |
                               ({4{(f0val[2]&~f0val[3])}} &        {q1parityfinal[0],  q0parityfinal[2:0]}) |
                               ({4{(f0val[1]&~f0val[2])}} &        {q1parityfinal[1:0],q0parityfinal[1:0]}) |
                               ({4{(f0val[0]&~f0val[1])}} &        {q1parityfinal[2:0],q0parityfinal[0]});

   assign aligntagperr[3:0] =   ({4{(f0val[3])}} &                  {4{f0perr}}) |
                                ({4{(f0val[2]&~f0val[3])}} &        {{1{f1perr}},{3{f0perr}}}) |
                                ({4{(f0val[1]&~f0val[2])}} &        {{2{f1perr}},{2{f0perr}}}) |
                                ({4{(f0val[0]&~f0val[1])}} &        {{3{f1perr}},{1{f0perr}}});

   assign alignicfetch[3:0] =   ({4{(f0val[3])}} &                  {4{f0icfetch}}) |
                                ({4{(f0val[2]&~f0val[3])}} &        {{1{f1icfetch}},{3{f0icfetch}}}) |
                                ({4{(f0val[1]&~f0val[2])}} &        {{2{f1icfetch}},{2{f0icfetch}}}) |
                                ({4{(f0val[0]&~f0val[1])}} &        {{3{f1icfetch}},{1{f0icfetch}}});


   assign alignret[3:0] =   ({4{(f0val[3])}} &                   f0ret[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1ret[0],f0ret[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1ret[1:0],f0ret[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1ret[2:0],f0ret[0]});

   assign alignway[3:0] =   ({4{(f0val[3])}} &                   f0way[3:0]) |
                            ({4{(f0val[2]&~f0val[3])}} &        {f1way[0],f0way[2:0]}) |
                            ({4{(f0val[1]&~f0val[2])}} &        {f1way[1:0],f0way[1:0]}) |
                            ({4{(f0val[0]&~f0val[1])}} &        {f1way[2:0],f0way[0]});
   assign alignhist1[3:0] =   ({4{(f0val[3])}} &                   f0hist1[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1hist1[0],f0hist1[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1hist1[1:0],f0hist1[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1hist1[2:0],f0hist1[0]});

   assign alignhist0[3:0] =   ({4{(f0val[3])}} &                   f0hist0[3:0]) |
                              ({4{(f0val[2]&~f0val[3])}} &        {f1hist0[0],f0hist0[2:0]}) |
                              ({4{(f0val[1]&~f0val[2])}} &        {f1hist0[1:0],f0hist0[1:0]}) |
                              ({4{(f0val[0]&~f0val[1])}} &        {f1hist0[2:0],f0hist0[0]});

   assign alignfromf1[3:1] =     ({3{(f0val[3])}} &                   3'b0) |
                                 ({3{(f0val[2]&~f0val[3])}} &        {1'b1,2'b0}) |
                                 ({3{(f0val[1]&~f0val[2])}} &        {2'b11,1'b0}) |
                                 ({3{(f0val[0]&~f0val[1])}} &        {3'b111});


   assign { secondpc[31:1],
            thirdpc[31:1],
            fourthpc[31:1] } =   ({3*31{(f0val[3])}}           & {f0pc_plus1[31:1], f0pc_plus2[31:1], f0pc_plus3[31:1]}) |
                                 ({3*31{(f0val[2]&~f0val[3])}} & {f0pc_plus1[31:1], f0pc_plus2[31:1], f1pc[31:1]}) |
                                 ({3*31{(f0val[1]&~f0val[2])}} & {f0pc_plus1[31:1], f1pc[31:1],       f1pc_plus1[31:1]})   |
                                 ({3*31{(f0val[0]&~f0val[1])}} & {f1pc[31:1],       f1pc_plus1[31:1], f1pc_plus2[31:1]});


   assign ifu_i0_pc[31:1] = f0pc[31:1];

   assign firstpc[31:1] = f0pc[31:1];


   assign ifu_i1_pc[31:1] = thirdpc[31:1];


   assign ifu_i0_pc4 = 1'b1;

   assign ifu_i1_pc4 = 1'b1;


   assign aligndataperr[3:0] = '0;


   assign ifu_i0_cinst[15:0] = 16'b0;
   assign ifu_i1_cinst[15:0] = 16'b0;


   assign first4B  = 1'b1;
   assign first2B  = 1'b0;
   assign second4B = 1'b1;
   assign second2B = 1'b0;
   assign third4B  = 1'b1;
   assign third2B  = 1'b0;

   assign ifu_i0_valid = ((first4B & alignval[1]) |
                          (first2B & alignval[0])) & ~exu_flush_final;

   assign ifu_i1_valid = ((first4B & third4B & alignval[3])  |
                          (first4B & third2B & alignval[2])  |
                          (first2B & second4B & alignval[2]) |
                          (first2B & second2B & alignval[1])) & ~exu_flush_final;


   assign ifu_i0_icaf = ((first4B & (|alignicaf[1:0])) |
                         (first2B &   alignicaf[0])) & ~exu_flush_final;


   assign icaf_eff[3:0] = alignicaf[3:0] | aligndbecc[3:0];

   assign ifu_i0_icaf_second = first4B & ~icaf_eff[0] & icaf_eff[1];

   assign ifu_i1_icaf = ((first4B & third4B &  (|alignicaf[3:2])) |
                         (first4B & third2B &    alignicaf[2])    |
                         (first2B & second4B & (|alignicaf[2:1])) |
                         (first2B & second2B &   alignicaf[1])) & ~exu_flush_final;

   assign ifu_i1_icaf_second = (first4B & third4B  & ~icaf_eff[2] & icaf_eff[3]) |
                               (first2B & second4B & ~icaf_eff[1] & icaf_eff[2]);


   assign alignfinalperr[3:0] = (aligntagperr[3:0] | aligndataperr[3:0]) & alignicfetch[3:0];

   assign ifu_i0_perr = ((first4B & (|alignfinalperr[1:0])) |
                         (first2B &   alignfinalperr[0])) & ~exu_flush_final;

   assign ifu_i1_perr = ((first4B & third4B &  (|alignfinalperr[3:2])) |
                         (first4B & third2B &    alignfinalperr[2])    |
                         (first2B & second4B & (|alignfinalperr[2:1])) |
                         (first2B & second2B &   alignfinalperr[1])) & ~exu_flush_final;

   assign ifu_i0_sbecc = ((first4B & (|alignsbecc[1:0])) |
                          (first2B &   alignsbecc[0])) & ~exu_flush_final;

   assign ifu_i1_sbecc = ((first4B & third4B &  (|alignsbecc[3:2])) |
                          (first4B & third2B &    alignsbecc[2])    |
                          (first2B & second4B & (|alignsbecc[2:1])) |
                          (first2B & second2B &   alignsbecc[1])) & ~exu_flush_final;

   assign ifu_i0_dbecc = ((first4B & (|aligndbecc[1:0])) |
                          (first2B &   aligndbecc[0])) & ~exu_flush_final;

   assign ifu_i1_dbecc = ((first4B & third4B &  (|aligndbecc[3:2])) |
                          (first4B & third2B &    aligndbecc[2])    |
                          (first2B & second4B & (|aligndbecc[2:1])) |
                          (first2B & second2B &   aligndbecc[1])) & ~exu_flush_final;


   logic [2:0]  alignicerr;

   assign alignicerr[2:0] = alignfinalperr[2:0] | alignsbecc[2:0];

   assign ifu_fetch_error_index[16:2] = (alignicerr[0]) ?  firstpc[16:2] :
                                          (alignicerr[1]) ? secondpc[16:2] :
                                          (alignicerr[2]) ?  thirdpc[16:2] :
                                                            fourthpc[16:2];

   assign ifu_fetch_parity_error_valid = (i0_shift & ifu_i0_perr) |
                                 (i1_shift & ifu_i1_perr & ~ifu_i0_sbecc);

   assign ifu_fetch_single_bit_error = (i0_shift & ifu_i0_sbecc) |
                                    (i1_shift & ifu_i1_sbecc & ~ifu_i0_perr);


   assign ifirst[31:0] =  aligndata[2*16-1:0*16];

   assign isecond[31:0] = aligndata[3*16-1:1*16];

   assign ithird[31:0] =  aligndata[4*16-1:2*16];


   assign ifu_i0_instr[31:0] = ifirst[31:0];


   assign ifu_i1_instr[31:0] = ithird[31:0];


   rvbtb_addr_hash firsthash(.pc(firstpc[31:1]), .hash(firstpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash secondhash(.pc(secondpc[31:1]), .hash(secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash thirdhash(.pc(thirdpc[31:1]), .hash(thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash fourthhash(.pc(fourthpc[31:1]), .hash(fourthpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));

   logic [`RV_BTB_BTAG_SIZE-1:0] firstbrtag_hash, secondbrtag_hash, thirdbrtag_hash, fourthbrtag_hash;

   rvbtb_tag_hash first_brhash(.pc(firstpc[31:1]), .hash(firstbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash second_brhash(.pc(secondpc[31:1]), .hash(secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash third_brhash(.pc(thirdpc[31:1]), .hash(thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));
   rvbtb_tag_hash fourth_brhash(.pc(fourthpc[31:1]), .hash(fourthbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]));


   always_comb begin

      i0_brp = '0;

      i0_br_start_error = (first4B & alignval[1] & alignbrend[0]);

      i0_brp.valid = (first2B & alignbrend[0]) |
                     (first4B & alignbrend[1]) |
                     i0_br_start_error;

      i0_brp_pc4 = (first2B & alignpc4[0]) |
                   (first4B & alignpc4[1]);

      i0_brp.ret = (first2B & alignret[0]) |
                   (first4B & alignret[1]);

      i0_brp.way = (first2B | alignbrend[0]) ? alignway[0] : alignway[1];
      i0_brp.hist[1] = (first2B & alignhist1[0]) |
                       (first4B & alignhist1[1]);

      i0_brp.hist[0] = (first2B & alignhist0[0]) |
                       (first4B & alignhist0[1]);

      i0_ends_f1 = (first4B & alignfromf1[1]);

      i0_brp.toffset[11:0] = (i0_ends_f1) ? f1poffset[11:0] : f0poffset[11:0];

      i0_brp.fghr[`RV_BHT_GHR_RANGE] = (i0_ends_f1) ? f1fghr[`RV_BHT_GHR_RANGE] : f0fghr[`RV_BHT_GHR_RANGE];

      i0_brp.prett[31:1] = (i0_ends_f1) ? f1prett[31:1] : f0prett[31:1];

      i0_brp.br_start_error = i0_br_start_error;

      i0_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = (first2B | alignbrend[0]) ? firstpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]:
                                                                                  secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

      i0_brp.btag[`RV_BTB_BTAG_SIZE-1:0] = (first2B | alignbrend[0]) ? firstbrtag_hash[`RV_BTB_BTAG_SIZE-1:0]:
                                                                       secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0];

      i0_brp.bank[1:0] = (first2B | alignbrend[0]) ? firstpc[3:2] :
                                                     secondpc[3:2];


      i0_brp.br_error = (i0_brp.valid &  i0_brp_pc4 &  first2B) |
                        (i0_brp.valid & ~i0_brp_pc4 &  first4B);

      i1_brp = '0;

      i1_br_start_error = (first2B & second4B & alignval[2] & alignbrend[1]) |
                          (first4B & third4B  & alignval[3] & alignbrend[2]);

      i1_brp.valid = (first4B & third2B & alignbrend[2]) |
                     (first4B & third4B & alignbrend[3]) |
                     (first2B & second2B & alignbrend[1]) |
                     (first2B & second4B & alignbrend[2]) |
                     i1_br_start_error;

      i1_brp_pc4 = (first4B & third2B & alignpc4[2]) |
                   (first4B & third4B & alignpc4[3]) |
                   (first2B & second2B & alignpc4[1]) |
                   (first2B & second4B & alignpc4[2]);

      i1_brp.ret = (first4B & third2B & alignret[2]) |
                   (first4B & third4B & alignret[3]) |
                   (first2B & second2B & alignret[1]) |
                   (first2B & second4B & alignret[2]);
      i1_brp.way = (first4B & third2B                   & alignway[2] ) |
                   (first4B & third4B &  alignbrend[2]  & alignway[2] ) |
                   (first4B & third4B & ~alignbrend[2]  & alignway[3] ) |
                   (first2B & second2B                  & alignway[1] ) |
                   (first2B & second4B &  alignbrend[1] & alignway[1] ) |
                   (first2B & second4B & ~alignbrend[1] & alignway[2] );
      i1_brp.hist[1] = (first4B & third2B & alignhist1[2]) |
                       (first4B & third4B & alignhist1[3]) |
                       (first2B & second2B & alignhist1[1]) |
                       (first2B & second4B & alignhist1[2]);

      i1_brp.hist[0] = (first4B & third2B & alignhist0[2]) |
                       (first4B & third4B & alignhist0[3]) |
                       (first2B & second2B & alignhist0[1]) |
                       (first2B & second4B & alignhist0[2]);

      i1_ends_f1 = (first4B & third2B & alignfromf1[2]) |
                   (first4B & third4B & alignfromf1[3]) |
                   (first2B & second2B & alignfromf1[1]) |
                   (first2B & second4B & alignfromf1[2]);

      i1_brp.toffset[11:0] = (i1_ends_f1) ? f1poffset[11:0] : f0poffset[11:0];

      i1_brp.fghr[`RV_BHT_GHR_RANGE] = (i1_ends_f1) ? f1fghr[`RV_BHT_GHR_RANGE] : f0fghr[`RV_BHT_GHR_RANGE];

      i1_brp.prett[31:1] = (i1_ends_f1) ? f1prett[31:1] : f0prett[31:1];

      i1_brp.br_start_error = i1_br_start_error;

`define RV_BTB_RANGE  `RV_BTB_ADDR_HI-`RV_BTB_ADDR_LO+1

      i1_brp.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = ({`RV_BTB_RANGE{first4B & third2B }}                  & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first4B & third4B &  alignbrend[2] }} & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first4B & third4B & ~alignbrend[2] }} & fourthpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second2B}}                  & secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second4B &  alignbrend[1]}} & secondpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ) |
                                                ({`RV_BTB_RANGE{first2B & second4B & ~alignbrend[1]}} & thirdpc_hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] );

      i1_brp.btag[`RV_BTB_BTAG_SIZE-1:0] = ({`RV_BTB_BTAG_SIZE{first4B & third2B }}                  &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first4B & third4B &  alignbrend[2] }} &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first4B & third4B & ~alignbrend[2] }} & fourthbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second2B}}                  & secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second4B &  alignbrend[1]}} & secondbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] ) |
                                           ({`RV_BTB_BTAG_SIZE{first2B & second4B & ~alignbrend[1]}} &  thirdbrtag_hash[`RV_BTB_BTAG_SIZE-1:0] );

      i1_brp.bank[1:0] = ({2{first4B & third2B }}                  & thirdpc[3:2] ) |
                         ({2{first4B & third4B &  alignbrend[2] }} & thirdpc[3:2] ) |
                         ({2{first4B & third4B & ~alignbrend[2] }} & fourthpc[3:2] ) |
                         ({2{first2B & second2B}}                  & secondpc[3:2] ) |
                         ({2{first2B & second4B &  alignbrend[1]}} & secondpc[3:2] ) |
                         ({2{first2B & second4B & ~alignbrend[1]}} & thirdpc[3:2] );

      i1_brp.br_error = (i1_brp.valid &  i1_brp_pc4 & first4B & third2B ) |
                        (i1_brp.valid & ~i1_brp_pc4 & first4B & third4B ) |
                        (i1_brp.valid &  i1_brp_pc4 & first2B & second2B) |
                        (i1_brp.valid & ~i1_brp_pc4 & first2B & second4B);
   end


   assign i0_illegal = 1'b0;

   assign i1_illegal = 1'b0;

   assign shift_illegal = (i0_shift & i0_illegal) |
                          (i1_shift & i1_illegal);

   assign illegal_inst[15:0] =   (first2B & ~first_legal)             ? aligndata[1*16-1:0*16] :
                                ((first2B & second2B & ~second_legal) ? aligndata[2*16-1:1*16] : aligndata[3*16-1:2*16]);

   assign illegal_inst_en = shift_illegal & ~illegal_lockout;

   rvdffe #(16) illegal_any_ff (.*, .en(illegal_inst_en), .din(illegal_inst[15:0]), .dout(ifu_illegal_inst[15:0]));

   assign illegal_lockout_in = (shift_illegal | illegal_lockout) & ~exu_flush_final;

   rvdff #(1) illegal_lockout_any_ff (.*, .clk(active_clk), .din(illegal_lockout_in), .dout(illegal_lockout));


   assign uncompress0 = 32'b0;
   assign uncompress1 = 32'b0;
   assign uncompress2 = 32'b0;
   assign first_legal  = 1'b1;
   assign second_legal = 1'b1;
   assign third_legal  = 1'b1;


   assign i0_shift = ifu_i0_valid & ibuffer_room1_more;

   assign i1_shift = ifu_i1_valid & ibuffer_room2_more;

   if (DEC_INSTBUF_DEPTH==4) begin
      assign ibuffer_room1_more = ~dec_ib3_valid_d;
      assign ibuffer_room2_more = ~dec_ib2_valid_d;
   end
   else begin
      assign ibuffer_room1_more = ~dec_ib0_valid_eff_d | ~dec_ib1_valid_eff_d;
      assign ibuffer_room2_more = ~dec_ib0_valid_eff_d & ~dec_ib1_valid_eff_d;
   end


   assign ifu_pmu_instr_aligned[1:0] = { i1_shift, i0_shift };

   assign ifu_pmu_align_stall = ifu_i0_valid & ~ibuffer_room1_more;


   assign shift_2B = i0_shift & ~i1_shift & first2B;


   assign shift_4B = (i0_shift & ~i1_shift & first4B) |
                     (i0_shift &  i1_shift & first2B & second2B);

   assign shift_6B = (i0_shift &  i1_shift & first2B & second4B) |
                     (i0_shift &  i1_shift & first4B & third2B);

   assign shift_8B = i0_shift &  i1_shift & first4B & third4B;


   assign f0_shift_2B = (shift_2B & f0val[0]) |
                        ((shift_4B | shift_6B | shift_8B) & f0val[0] & ~f0val[1]);

   assign f0_shift_4B = (shift_4B & f0val[1]) |
                        ((shift_6B & shift_8B) & f0val[1] & ~f0val[2]);


   assign f0_shift_6B = (shift_6B & f0val[2]) |
                        (shift_8B & f0val[2] & ~f0val[3]);

   assign f0_shift_8B =  shift_8B & f0val[3];


   assign f1_shift_2B = (f0val[2] & ~f0val[3] & shift_8B) |
                        (f0val[1] & ~f0val[2] & shift_6B) |
                        (f0val[0] & ~f0val[1] & shift_4B);

   assign f1_shift_4B = (f0val[1] & ~f0val[2] & shift_8B) |
                        (f0val[0] & ~f0val[1] & shift_6B);

   assign f1_shift_6B = (f0val[0] & ~f0val[1] & shift_8B);


endmodule

