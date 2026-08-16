


module ifu_bp_ctl
   import mycpu_types::*;
(

   input logic clk,
   input logic active_clk,
   input logic clk_override,
   input logic rst_l,

   input logic tcm_fetch_valid_f2,

   input logic [31:1] ifc_fetch_addr_f1,
   input logic [31:1] ifc_fetch_addr_f2,
   input logic ifc_fetch_req_f1,
   input logic ifc_fetch_req_f2,

   input br_tlu_pkt_t dec_tlu_br0_wb_pkt,
   input br_tlu_pkt_t dec_tlu_br1_wb_pkt,

   input logic dec_tlu_flush_lower_wb,
   input logic dec_tlu_flush_leak_one_wb,

   input logic dec_tlu_bpred_disable,

   input logic        exu_i0_br_ret_e4,
   input logic        exu_i1_br_ret_e4,
   input logic        exu_i0_br_call_e4,
   input logic        exu_i1_br_call_e4,

   input predict_pkt_t  exu_mp_pkt,

   input rets_pkt_t exu_rets_e1_pkt,
   input rets_pkt_t exu_rets_e4_pkt,


   input logic [`RV_BHT_GHR_RANGE] exu_mp_eghr,

   input logic exu_flush_final,
   input logic exu_flush_upper_e2,

   output logic ifu_bp_kill_next_f2,
   output logic [31:1] ifu_bp_btb_target_f2,
   output logic [7:1] ifu_bp_inst_mask_f2,

   output logic [`RV_BHT_GHR_RANGE] ifu_bp_fghr_f2,

   output logic [7:0] ifu_bp_way_f2,
   output logic [7:0] ifu_bp_ret_f2,
   output logic [7:0] ifu_bp_hist1_f2,
   output logic [7:0] ifu_bp_hist0_f2,
   output logic [11:0] ifu_bp_poffset_f2,
   output logic [7:0] ifu_bp_pc4_f2,
   output logic [7:0] ifu_bp_valid_f2,

   input  logic       scan_mode
   );

`define TAG 16+`RV_BTB_BTAG_SIZE:17

   localparam PC4=4;
   localparam BOFF=3;
   localparam CALL=2;
   localparam RET=1;
   localparam BV=0;

   localparam LRU_SIZE=`RV_BTB_ARRAY_DEPTH;
   localparam NUM_BHT_LOOP = (`RV_BHT_ARRAY_DEPTH > 16 ) ? 16 : `RV_BHT_ARRAY_DEPTH;
   localparam NUM_BHT_LOOP_INNER_HI =  (`RV_BHT_ARRAY_DEPTH > 16 ) ?`RV_BHT_ADDR_LO+3 : `RV_BHT_ADDR_HI;
   localparam NUM_BHT_LOOP_OUTER_LO =  (`RV_BHT_ARRAY_DEPTH > 16 ) ?`RV_BHT_ADDR_LO+4 : `RV_BHT_ADDR_LO;
   localparam BHT_NO_ADDR_MATCH  = ( `RV_BHT_ARRAY_DEPTH <= 16 );
   localparam BTB_ADDR_WIDTH = `RV_BTB_ADDR_HI-`RV_BTB_ADDR_LO+1;

   logic exu_mp_valid_write;
   logic exu_mp_ataken;
   logic exu_mp_valid;
   logic exu_mp_boffset;
   logic exu_mp_pc4;
   logic exu_mp_call;
   logic exu_mp_ret;
   logic exu_mp_ja;
   logic [1:0] exu_mp_hist;
   logic [11:0] exu_mp_tgt;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] exu_mp_addr;
   logic [1:0]                             exu_mp_bank;
   logic [`RV_BTB_BTAG_SIZE-1:0]           exu_mp_btag;
   logic [`RV_BHT_GHR_RANGE]               exu_mp_fghr;
   logic                                   dec_tlu_br0_v_wb;
   logic [1:0]                             dec_tlu_br0_hist_wb;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] dec_tlu_br0_addr_wb;
   logic [1:0]                             dec_tlu_br0_bank_wb;
   logic                                   dec_tlu_br0_error_wb;
   logic                                   dec_tlu_br0_start_error_wb;
   logic [`RV_BHT_GHR_RANGE]               dec_tlu_br0_fghr_wb;

   logic                                   dec_tlu_br1_v_wb;
   logic [1:0]                             dec_tlu_br1_hist_wb;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] dec_tlu_br1_addr_wb;
   logic [1:0]                             dec_tlu_br1_bank_wb;
   logic                                   dec_tlu_br1_error_wb;
   logic                                   dec_tlu_br1_start_error_wb;
   logic [`RV_BHT_GHR_RANGE]               dec_tlu_br1_fghr_wb;

   logic [3:0]        use_mp_way;
   logic [`RV_RET_STACK_SIZE-1:0][31:1] rets_out, rets_in, e1_rets_out, e1_rets_in, e4_rets_out, e4_rets_in;
   logic [`RV_RET_STACK_SIZE-1:0]       rsenable;


   logic [11:0]       btb_rd_tgt_f2;
   logic              btb_rd_pc4_f2, btb_rd_boffset_f2,  btb_rd_call_f2, btb_rd_ret_f2;
   logic [3:1]        bp_total_branch_offset_f2;

   logic [31:1]       bp_btb_target_adder_f2;
   logic [31:1]       bp_rs_call_target_f2;
   logic              rs_push, rs_pop, rs_hold;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] btb_rd_addr_f1, btb_wr_addr, btb_rd_addr_f2;
   logic [`RV_BTB_BTAG_SIZE-1:0] btb_wr_tag, fetch_rd_tag_f1, fetch_rd_tag_f2;
   logic [16+`RV_BTB_BTAG_SIZE:0]        btb_wr_data;
   logic [3:0]         btb_wr_en_way0, btb_wr_en_way1;


   logic               dec_tlu_error_wb, dec_tlu_all_banks_error_wb, btb_valid, dec_tlu_br0_middle_wb, dec_tlu_br1_middle_wb;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]        btb_error_addr_wb;
   logic [1:0]         dec_tlu_error_bank_wb;
   logic               btb_error_pending;
   logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] btb_error_addr_q;
   logic [3:0]         btb_error_wr_en_way0_d, btb_error_wr_en_way0_q;
   logic [3:0]         btb_error_wr_en_way1_d, btb_error_wr_en_way1_q;
   logic branch_error_collision_f1, fetch_mp_collision_f1, fetch_mp_collision_f2;

   logic [6:0] fgmask_f2;
   logic [3:0] branch_error_bank_conflict_f1, branch_error_bank_conflict_f2;
   logic [`RV_BHT_GHR_RANGE] merged_ghr, fghr_ns, fghr;
   logic [3:0] num_valids;
   logic [LRU_SIZE-1:0] btb_lru_b0_f, btb_lru_b0_hold, btb_lru_b0_ns, btb_lru_b1_f, btb_lru_b1_hold, btb_lru_b1_ns,
                        btb_lru_b2_f, btb_lru_b2_hold, btb_lru_b2_ns, btb_lru_b3_f, btb_lru_b3_hold, btb_lru_b3_ns,
                        fetch_wrindex_dec, fetch_wrlru_b0, fetch_wrlru_b1, fetch_wrlru_b2, fetch_wrlru_b3,
                        mp_wrindex_dec, mp_wrlru_b0, mp_wrlru_b1, mp_wrlru_b2, mp_wrlru_b3;
   logic [3:0]          btb_lru_rd_f2, mp_bank_decoded, mp_bank_decoded_f, lru_update_valid_f2;
   logic [3:0] tag_match_way0_f2, tag_match_way1_f2;
   logic [7:0] way_raw, bht_dir_f2, btb_sel_f2, wayhit_f2;
   logic [7:0] btb_sel_mask_f2, bht_valid_f2, bht_force_taken_f2;

   logic leak_one_f1, leak_one_f2, ifc_fetch_req_f2_raw;

   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank0_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank1_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank2_rd_data_way0_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank3_rd_data_way0_out ;

   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank0_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank1_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank2_rd_data_way1_out ;
   logic [LRU_SIZE-1:0][16+`RV_BTB_BTAG_SIZE:0]  btb_bank3_rd_data_way1_out ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way0_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way0_f2_in ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way1_f2_in ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way1_f2_in ;


   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way0_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way0_f2 ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2_rd_data_way1_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3_rd_data_way1_f2 ;

   logic                                         final_h;
   logic                                         btb_fg_crossing_f2;
   logic                                         rs_correct;
   logic                                         middle_of_bank;

   logic exu_mp_way, exu_mp_way_f, dec_tlu_br0_way_wb, dec_tlu_br1_way_wb, dec_tlu_way_wb, dec_tlu_way_wb_f;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2e_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3e_rd_data_f2 ;

   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank0o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank1o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank2o_rd_data_f2 ;
   logic                [16+`RV_BTB_BTAG_SIZE:0] btb_bank3o_rd_data_f2 ;

   logic [7:0] tag_match_way0_expanded_f2, tag_match_way1_expanded_f2;


    logic [1:0]                                  bht_bank0_rd_data_f2 ;
    logic [1:0]                                  bht_bank1_rd_data_f2 ;
    logic [1:0]                                  bht_bank2_rd_data_f2 ;
    logic [1:0]                                  bht_bank3_rd_data_f2 ;
    logic [1:0]                                  bht_bank4_rd_data_f2 ;
    logic [1:0]                                  bht_bank5_rd_data_f2 ;
    logic [1:0]                                  bht_bank6_rd_data_f2 ;
    logic [1:0]                                  bht_bank7_rd_data_f2 ;

   assign exu_mp_valid = exu_mp_pkt.misp & ~leak_one_f2;
   assign exu_mp_boffset = exu_mp_pkt.boffset;
   assign exu_mp_pc4 = exu_mp_pkt.pc4;
   assign exu_mp_call = exu_mp_pkt.pcall;
   assign exu_mp_ret = exu_mp_pkt.pret;
   assign exu_mp_ja = exu_mp_pkt.pja;
   assign exu_mp_way = exu_mp_pkt.way;
   assign exu_mp_hist[1:0] = exu_mp_pkt.hist[1:0];
   assign exu_mp_tgt[11:0]  = exu_mp_pkt.toffset[11:0] ;
   assign exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]  = exu_mp_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] ;
   assign exu_mp_bank[1:0]  = exu_mp_pkt.bank[1:0] ;
   assign exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0]  = exu_mp_pkt.btag[`RV_BTB_BTAG_SIZE-1:0] ;
   assign exu_mp_fghr[`RV_BHT_GHR_RANGE]  = exu_mp_pkt.fghr[`RV_BHT_GHR_RANGE] ;
   assign exu_mp_ataken = exu_mp_pkt.ataken;

   assign dec_tlu_br0_v_wb = dec_tlu_br0_wb_pkt.valid;
   assign dec_tlu_br0_hist_wb[1:0]  = dec_tlu_br0_wb_pkt.hist[1:0];
   assign dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_tlu_br0_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br0_bank_wb[1:0]  = dec_tlu_br0_wb_pkt.bank[1:0];
   assign dec_tlu_br0_error_wb = dec_tlu_br0_wb_pkt.br_error;
   assign dec_tlu_br0_middle_wb = dec_tlu_br0_wb_pkt.middle;
   assign dec_tlu_br0_way_wb = dec_tlu_br0_wb_pkt.way;
   assign dec_tlu_br0_start_error_wb = dec_tlu_br0_wb_pkt.br_start_error;
   assign dec_tlu_br0_fghr_wb[`RV_BHT_GHR_RANGE] = dec_tlu_br0_wb_pkt.fghr[`RV_BHT_GHR_RANGE];

   assign dec_tlu_br1_v_wb = dec_tlu_br1_wb_pkt.valid;
   assign dec_tlu_br1_hist_wb[1:0]  = dec_tlu_br1_wb_pkt.hist[1:0];
   assign dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = dec_tlu_br1_wb_pkt.index[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];
   assign dec_tlu_br1_bank_wb[1:0]  = dec_tlu_br1_wb_pkt.bank[1:0];
   assign dec_tlu_br1_middle_wb = dec_tlu_br1_wb_pkt.middle;
   assign dec_tlu_br1_error_wb = dec_tlu_br1_wb_pkt.br_error;
   assign dec_tlu_br1_way_wb = dec_tlu_br1_wb_pkt.way;
   assign dec_tlu_br1_start_error_wb = dec_tlu_br1_wb_pkt.br_start_error;
   assign  dec_tlu_br1_fghr_wb[`RV_BHT_GHR_RANGE] = dec_tlu_br1_wb_pkt.fghr[`RV_BHT_GHR_RANGE];


   rvbtb_addr_hash f1hash(.pc(ifc_fetch_addr_f1[31:1]), .hash(btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));
   rvbtb_addr_hash f2hash(.pc(ifc_fetch_addr_f2[31:1]), .hash(btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]));


assign btb_sel_f2[7] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]) | (
    ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]);
assign btb_sel_f2[6] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6]);
assign btb_sel_f2[5] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[5]);
assign btb_sel_f2[4] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4]);
assign btb_sel_f2[3] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]
     & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[3]);
assign btb_sel_f2[2] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[2]);
assign btb_sel_f2[1] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[1]);
assign btb_sel_f2[0] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[0]);


logic [7:0] btb_vmask_raw_f2;
assign btb_vmask_raw_f2[7] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[6] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[5] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]
     & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]);
assign btb_vmask_raw_f2[4] = (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1] & bht_dir_f2[6]
     & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]
     & ~bht_dir_f2[1]);
assign btb_vmask_raw_f2[3] = (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]);
assign btb_vmask_raw_f2[2] = (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ifc_fetch_addr_f2[1] & ~bht_dir_f2[6] & ~bht_dir_f2[5]) | (
    ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[6] & ~bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1] & ~bht_dir_f2[0]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[5] & ~bht_dir_f2[4] & ~bht_dir_f2[3]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[3] & ~bht_dir_f2[2] & ~bht_dir_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[4] & ~bht_dir_f2[3] & ~bht_dir_f2[2]);
assign btb_vmask_raw_f2[1] = (ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & ~bht_dir_f2[6]) | (ifc_fetch_addr_f2[3]
     & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[6]
     & ~bht_dir_f2[5]) | (ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[5] & ~bht_dir_f2[4]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]
     & bht_dir_f2[1] & ~bht_dir_f2[0]) | (~ifc_fetch_addr_f2[3]
     & ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1] & bht_dir_f2[4]
     & ~bht_dir_f2[3]) | (~ifc_fetch_addr_f2[3] & ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1] & bht_dir_f2[3] & ~bht_dir_f2[2]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2] & ifc_fetch_addr_f2[1]
     & bht_dir_f2[2] & ~bht_dir_f2[1]);


   logic[7:1] btb_vmask_f2;
   assign btb_vmask_f2[7:1] = {btb_vmask_raw_f2[7],
                              |btb_vmask_raw_f2[7:6],
                              |btb_vmask_raw_f2[7:5],
                              |btb_vmask_raw_f2[7:4],
                              |btb_vmask_raw_f2[7:3],
                              |btb_vmask_raw_f2[7:2],
                              |btb_vmask_raw_f2[7:1]};


   assign branch_error_collision_f1 = dec_tlu_error_wb & (btb_error_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]);
   assign branch_error_bank_conflict_f1[3:0] = {4{branch_error_collision_f1}} & (decode2_4(dec_tlu_error_bank_wb[1:0]) | {4{dec_tlu_all_banks_error_wb}});

   assign fetch_mp_collision_f1 = ( (exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0] == fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]) &
                                    exu_mp_valid & ifc_fetch_req_f1 &
                                    (exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO])
                                    );

   assign leak_one_f1 = (dec_tlu_flush_leak_one_wb & dec_tlu_flush_lower_wb) | (leak_one_f2 & ~dec_tlu_flush_lower_wb);

   rvdff #(13) coll_ff (.*, .clk(active_clk),
                         .din({branch_error_bank_conflict_f1[3:0], fetch_mp_collision_f1, mp_bank_decoded[3:0], exu_mp_way, dec_tlu_way_wb, leak_one_f1, ifc_fetch_req_f1}),
                        .dout({branch_error_bank_conflict_f2[3:0], fetch_mp_collision_f2, mp_bank_decoded_f[3:0], exu_mp_way_f, dec_tlu_way_wb_f, leak_one_f2, ifc_fetch_req_f2_raw}));

   assign tag_match_way0_f2[3:0] = {btb_bank3_rd_data_way0_f2[BV] & (btb_bank3_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way0_f2[BV] & (btb_bank2_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way0_f2[BV] & (btb_bank1_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way0_f2[BV] & (btb_bank0_rd_data_way0_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} &
                                   ~({4{~dec_tlu_way_wb_f}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};

   assign tag_match_way1_f2[3:0] = {btb_bank3_rd_data_way1_f2[BV] & (btb_bank3_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank2_rd_data_way1_f2[BV] & (btb_bank2_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank1_rd_data_way1_f2[BV] & (btb_bank1_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]),
                                    btb_bank0_rd_data_way1_f2[BV] & (btb_bank0_rd_data_way1_f2[`TAG] == fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0])} &
                                   ~({4{dec_tlu_way_wb_f}} & branch_error_bank_conflict_f2[3:0]) & {4{ifc_fetch_req_f2_raw & ~leak_one_f2}};


   assign tag_match_way0_expanded_f2[7:0] = {tag_match_way0_f2[3] &  (btb_bank3_rd_data_way0_f2[BOFF] ^ btb_bank3_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[3] & ~(btb_bank3_rd_data_way0_f2[BOFF] ^ btb_bank3_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[2] &  (btb_bank2_rd_data_way0_f2[BOFF] ^ btb_bank2_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[2] & ~(btb_bank2_rd_data_way0_f2[BOFF] ^ btb_bank2_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[1] &  (btb_bank1_rd_data_way0_f2[BOFF] ^ btb_bank1_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[1] & ~(btb_bank1_rd_data_way0_f2[BOFF] ^ btb_bank1_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[0] &  (btb_bank0_rd_data_way0_f2[BOFF] ^ btb_bank0_rd_data_way0_f2[PC4]),
                                             tag_match_way0_f2[0] & ~(btb_bank0_rd_data_way0_f2[BOFF] ^ btb_bank0_rd_data_way0_f2[PC4])};

   assign tag_match_way1_expanded_f2[7:0] = {tag_match_way1_f2[3] &  (btb_bank3_rd_data_way1_f2[BOFF] ^ btb_bank3_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[3] & ~(btb_bank3_rd_data_way1_f2[BOFF] ^ btb_bank3_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[2] &  (btb_bank2_rd_data_way1_f2[BOFF] ^ btb_bank2_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[2] & ~(btb_bank2_rd_data_way1_f2[BOFF] ^ btb_bank2_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[1] &  (btb_bank1_rd_data_way1_f2[BOFF] ^ btb_bank1_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[1] & ~(btb_bank1_rd_data_way1_f2[BOFF] ^ btb_bank1_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[0] &  (btb_bank0_rd_data_way1_f2[BOFF] ^ btb_bank0_rd_data_way1_f2[PC4]),
                                             tag_match_way1_f2[0] & ~(btb_bank0_rd_data_way1_f2[BOFF] ^ btb_bank0_rd_data_way1_f2[PC4])};


   assign wayhit_f2[7:0] = tag_match_way0_expanded_f2[7:0] | tag_match_way1_expanded_f2[7:0];
   assign btb_bank3o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[7]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[7]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank3e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[6]}} & btb_bank3_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[6]}} & btb_bank3_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank2o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[5]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[5]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank2e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[4]}} & btb_bank2_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[4]}} & btb_bank2_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank1o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[3]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[3]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank1e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[2]}} & btb_bank1_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[2]}} & btb_bank1_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );

   assign btb_bank0o_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[1]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[1]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );
   assign btb_bank0e_rd_data_f2[16+`RV_BTB_BTAG_SIZE:0] = ( ({17+`RV_BTB_BTAG_SIZE{tag_match_way0_expanded_f2[0]}} & btb_bank0_rd_data_way0_f2[16+`RV_BTB_BTAG_SIZE:0]) |
                                                            ({17+`RV_BTB_BTAG_SIZE{tag_match_way1_expanded_f2[0]}} & btb_bank0_rd_data_way1_f2[16+`RV_BTB_BTAG_SIZE:0]) );


   assign mp_bank_decoded[3:0] = decode2_4(exu_mp_bank[1:0]);

   assign mp_wrindex_dec[LRU_SIZE-1:0] = {{LRU_SIZE-1{1'b0}},1'b1} <<  exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];


   assign fetch_wrindex_dec[LRU_SIZE-1:0] = {{LRU_SIZE-1{1'b0}},1'b1} <<  btb_rd_addr_f2[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign mp_wrlru_b0[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[0] & exu_mp_valid}};
   assign mp_wrlru_b1[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[1] & exu_mp_valid}};
   assign mp_wrlru_b2[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[2] & exu_mp_valid}};
   assign mp_wrlru_b3[LRU_SIZE-1:0] = mp_wrindex_dec[LRU_SIZE-1:0] & {LRU_SIZE{mp_bank_decoded[3] & exu_mp_valid}};

   genvar     j, i;


   assign lru_update_valid_f2[3:0] = {((bht_valid_f2[6] & btb_sel_mask_f2[6]) | (bht_valid_f2[7] & btb_sel_mask_f2[7])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[4] & btb_sel_mask_f2[4]) | (bht_valid_f2[5] & btb_sel_mask_f2[5])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[2] & btb_sel_mask_f2[2]) | (bht_valid_f2[3] & btb_sel_mask_f2[3])) & ifc_fetch_req_f2 & ~leak_one_f2,
                                      ((bht_valid_f2[0] & btb_sel_mask_f2[0]) | (bht_valid_f2[1] & btb_sel_mask_f2[1])) & ifc_fetch_req_f2 & ~leak_one_f2};

   assign fetch_wrlru_b0[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] &
                                         {LRU_SIZE{lru_update_valid_f2[0]}};
   assign fetch_wrlru_b1[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] &
                                         {LRU_SIZE{lru_update_valid_f2[1]}};
   assign fetch_wrlru_b2[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] &
                                         {LRU_SIZE{lru_update_valid_f2[2]}};
   assign fetch_wrlru_b3[LRU_SIZE-1:0] = fetch_wrindex_dec[LRU_SIZE-1:0] &
                                         {LRU_SIZE{lru_update_valid_f2[3]}};


   assign btb_lru_b0_hold[LRU_SIZE-1:0] = ~mp_wrlru_b0[LRU_SIZE-1:0] & ~fetch_wrlru_b0[LRU_SIZE-1:0];
   assign btb_lru_b1_hold[LRU_SIZE-1:0] = ~mp_wrlru_b1[LRU_SIZE-1:0] & ~fetch_wrlru_b1[LRU_SIZE-1:0];
   assign btb_lru_b2_hold[LRU_SIZE-1:0] = ~mp_wrlru_b2[LRU_SIZE-1:0] & ~fetch_wrlru_b2[LRU_SIZE-1:0];
   assign btb_lru_b3_hold[LRU_SIZE-1:0] = ~mp_wrlru_b3[LRU_SIZE-1:0] & ~fetch_wrlru_b3[LRU_SIZE-1:0];


   assign use_mp_way[3:0] = {4{fetch_mp_collision_f2}} & mp_bank_decoded_f[3:0];


   assign btb_lru_b0_ns[LRU_SIZE-1:0] = ( (btb_lru_b0_hold[LRU_SIZE-1:0] & btb_lru_b0_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b0[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b0[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[0]}}) );

   assign btb_lru_b1_ns[LRU_SIZE-1:0] = ( (btb_lru_b1_hold[LRU_SIZE-1:0] & btb_lru_b1_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b1[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b1[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[1]}}) );

   assign btb_lru_b2_ns[LRU_SIZE-1:0] = ( (btb_lru_b2_hold[LRU_SIZE-1:0] & btb_lru_b2_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b2[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b2[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[2]}}) );

   assign btb_lru_b3_ns[LRU_SIZE-1:0] = ( (btb_lru_b3_hold[LRU_SIZE-1:0] & btb_lru_b3_f[LRU_SIZE-1:0]) |
                                          (mp_wrlru_b3[LRU_SIZE-1:0] & {LRU_SIZE{~exu_mp_way}}) |
                                          (fetch_wrlru_b3[LRU_SIZE-1:0] & {LRU_SIZE{tag_match_way0_f2[3]}}) );

   assign btb_lru_rd_f2[0] = use_mp_way[0] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b0_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[1] = use_mp_way[1] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b1_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[2] = use_mp_way[2] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b2_f[LRU_SIZE-1:0]);
   assign btb_lru_rd_f2[3] = use_mp_way[3] ? exu_mp_way_f : |(fetch_wrindex_dec[LRU_SIZE-1:0] & btb_lru_b3_f[LRU_SIZE-1:0]);

   assign way_raw[7:0] =  tag_match_way1_expanded_f2[7:0] | (~wayhit_f2[7:0] & {{2{btb_lru_rd_f2[3]}}, {2{btb_lru_rd_f2[2]}}, {2{btb_lru_rd_f2[1]}}, {2{btb_lru_rd_f2[0]}}});

   rvdffe #(LRU_SIZE*4) btb_lru_ff (.*, .en(ifc_fetch_req_f2 | exu_mp_valid),
                                   .din({btb_lru_b0_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b1_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b2_ns[(LRU_SIZE)-1:0],
                                         btb_lru_b3_ns[(LRU_SIZE)-1:0]}),
                                   .dout({btb_lru_b0_f[(LRU_SIZE)-1:0],
                                          btb_lru_b1_f[(LRU_SIZE)-1:0],
                                          btb_lru_b2_f[(LRU_SIZE)-1:0],
                                          btb_lru_b3_f[(LRU_SIZE)-1:0]}));


   logic [16:1] btb_sel_data_f2;
   assign {
           btb_rd_tgt_f2[11:0],
           btb_rd_pc4_f2,
           btb_rd_boffset_f2,
           btb_rd_call_f2,
           btb_rd_ret_f2} = btb_sel_data_f2[16:1];

   assign btb_sel_data_f2[16:1] = ( ({16{btb_sel_f2[7]}} & btb_bank3o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[6]}} & btb_bank3e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[5]}} & btb_bank2o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[4]}} & btb_bank2e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[3]}} & btb_bank1o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[2]}} & btb_bank1e_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[1]}} & btb_bank0o_rd_data_f2[16:1]) |
                                    ({16{btb_sel_f2[0]}} & btb_bank0e_rd_data_f2[16:1]) );


   logic [7:0] bp_valid_f2, bp_hist1_f2;


   assign ifu_bp_kill_next_f2 = |(bp_valid_f2[7:0] & bp_hist1_f2[7:0]) & ifc_fetch_req_f2 & ~leak_one_f2 & ~dec_tlu_bpred_disable;


   assign bht_force_taken_f2[7:0] = {(btb_bank3o_rd_data_f2[CALL] | btb_bank3o_rd_data_f2[RET]),
                                     (btb_bank3e_rd_data_f2[CALL] | btb_bank3e_rd_data_f2[RET]),
                                     (btb_bank2o_rd_data_f2[CALL] | btb_bank2o_rd_data_f2[RET]),
                                     (btb_bank2e_rd_data_f2[CALL] | btb_bank2e_rd_data_f2[RET]),
                                     (btb_bank1o_rd_data_f2[CALL] | btb_bank1o_rd_data_f2[RET]),
                                     (btb_bank1e_rd_data_f2[CALL] | btb_bank1e_rd_data_f2[RET]),
                                     (btb_bank0o_rd_data_f2[CALL] | btb_bank0o_rd_data_f2[RET]),
                                     (btb_bank0e_rd_data_f2[CALL] | btb_bank0e_rd_data_f2[RET])};


   assign bht_valid_f2[7:0] = wayhit_f2[7:0];

   assign bht_dir_f2[7:0] = {(bht_force_taken_f2[7] | bht_bank7_rd_data_f2[1]) & bht_valid_f2[7],
                             (bht_force_taken_f2[6] | bht_bank6_rd_data_f2[1]) & bht_valid_f2[6],
                             (bht_force_taken_f2[5] | bht_bank5_rd_data_f2[1]) & bht_valid_f2[5],
                             (bht_force_taken_f2[4] | bht_bank4_rd_data_f2[1]) & bht_valid_f2[4],
                             (bht_force_taken_f2[3] | bht_bank3_rd_data_f2[1]) & bht_valid_f2[3],
                             (bht_force_taken_f2[2] | bht_bank2_rd_data_f2[1]) & bht_valid_f2[2],
                             (bht_force_taken_f2[1] | bht_bank1_rd_data_f2[1]) & bht_valid_f2[1],
                             (bht_force_taken_f2[0] | bht_bank0_rd_data_f2[1]) & bht_valid_f2[0]};


   logic       minus1, plus1;

   assign plus1 = ( (~btb_rd_pc4_f2 &   btb_rd_boffset_f2 &  ~ifc_fetch_addr_f2[1]) |
                    ( btb_rd_pc4_f2 &  ~btb_rd_boffset_f2 &  ~ifc_fetch_addr_f2[1]) );

   assign minus1 = ( (~btb_rd_pc4_f2 &  ~btb_rd_boffset_f2 &   ifc_fetch_addr_f2[1]) |
                     ( btb_rd_pc4_f2 &   btb_rd_boffset_f2 &   ifc_fetch_addr_f2[1]) );

   assign ifu_bp_inst_mask_f2[7:1] = ( ({7{ ifu_bp_kill_next_f2}} & btb_vmask_f2[7:1]) |
                                       ({7{~ifu_bp_kill_next_f2}} & 7'b1111111) );

   logic [7:0] hist0_raw, hist1_raw, pc4_raw, pret_raw;


    assign hist1_raw[7:0] = bht_force_taken_f2[7:0] | {bht_bank7_rd_data_f2[1],
                                                      bht_bank6_rd_data_f2[1],
                                                      bht_bank5_rd_data_f2[1],
                                                      bht_bank4_rd_data_f2[1],
                                                      bht_bank3_rd_data_f2[1],
                                                      bht_bank2_rd_data_f2[1],
                                                      bht_bank1_rd_data_f2[1],
                                                      bht_bank0_rd_data_f2[1]};

   assign hist0_raw[7:0] = {bht_bank7_rd_data_f2[0],
                            bht_bank6_rd_data_f2[0],
                            bht_bank5_rd_data_f2[0],
                            bht_bank4_rd_data_f2[0],
                            bht_bank3_rd_data_f2[0],
                            bht_bank2_rd_data_f2[0],
                            bht_bank1_rd_data_f2[0],
                            bht_bank0_rd_data_f2[0]};


   assign pc4_raw[7:0] = wayhit_f2[7:0];

   assign pret_raw[7:0] = {wayhit_f2[3] & ~btb_bank3o_rd_data_f2[CALL] & btb_bank3o_rd_data_f2[RET],
                           wayhit_f2[3] & ~btb_bank3e_rd_data_f2[CALL] & btb_bank3e_rd_data_f2[RET],
                           wayhit_f2[2] & ~btb_bank2o_rd_data_f2[CALL] & btb_bank2o_rd_data_f2[RET],
                           wayhit_f2[2] & ~btb_bank2e_rd_data_f2[CALL] & btb_bank2e_rd_data_f2[RET],
                           wayhit_f2[1] & ~btb_bank1o_rd_data_f2[CALL] & btb_bank1o_rd_data_f2[RET],
                           wayhit_f2[1] & ~btb_bank1e_rd_data_f2[CALL] & btb_bank1e_rd_data_f2[RET],
                           wayhit_f2[0] & ~btb_bank0o_rd_data_f2[CALL] & btb_bank0o_rd_data_f2[RET],
                           wayhit_f2[0] & ~btb_bank0e_rd_data_f2[CALL] & btb_bank0e_rd_data_f2[RET]};


assign fgmask_f2[6] = (~ifc_fetch_addr_f2[1]) | (~ifc_fetch_addr_f2[2]) | (
    ~ifc_fetch_addr_f2[3]);
assign fgmask_f2[5] = (~ifc_fetch_addr_f2[2]) | (~ifc_fetch_addr_f2[3]);
assign fgmask_f2[4] = (~ifc_fetch_addr_f2[2] & ~ifc_fetch_addr_f2[1]) | (
    ~ifc_fetch_addr_f2[3]);
assign fgmask_f2[3] = (~ifc_fetch_addr_f2[3]);
assign fgmask_f2[2] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[1]) | (
    ~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]);
assign fgmask_f2[1] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]);
assign fgmask_f2[0] = (~ifc_fetch_addr_f2[3] & ~ifc_fetch_addr_f2[2]
     & ~ifc_fetch_addr_f2[1]);

   assign btb_sel_mask_f2[7:0] = {btb_sel_f2[7],
                                  |btb_sel_f2[7:6] & fgmask_f2[6],
                                  |btb_sel_f2[7:5] & fgmask_f2[5],
                                  |btb_sel_f2[7:4] & fgmask_f2[4],
                                  |btb_sel_f2[7:3] & fgmask_f2[3],
                                  |btb_sel_f2[7:2] & fgmask_f2[2],
                                  |btb_sel_f2[7:1] & fgmask_f2[1],
                                  |btb_sel_f2[7:0] & fgmask_f2[0]};


   assign num_valids[3:0] = countones(bht_valid_f2[7:0] & btb_sel_mask_f2[7:0]);


   assign final_h = |(btb_sel_f2[7:0] & bht_dir_f2[7:0]);

    assign merged_ghr[`RV_BHT_GHR_RANGE] = ( ({`RV_BHT_GHR_SIZE{num_valids[3:0] >= 4'h4}} & {`RV_BHT_GHR_PAD,  final_h }) |
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h3}} & {`RV_BHT_GHR_PAD2, final_h}) |
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h2}} & {fghr[`RV_BHT_GHR_SIZE-3:0], 1'b0, final_h}) |
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h1}} & {fghr[`RV_BHT_GHR_SIZE-2:0], final_h}) |
                                            ({`RV_BHT_GHR_SIZE{num_valids[3:0] == 4'h0}} & {fghr[`RV_BHT_GHR_RANGE]}) );

   logic [`RV_BHT_GHR_RANGE] exu_flush_ghr;
   assign exu_flush_ghr[`RV_BHT_GHR_RANGE] = exu_mp_fghr[`RV_BHT_GHR_RANGE];

   assign fghr_ns[`RV_BHT_GHR_RANGE] = ( ({`RV_BHT_GHR_SIZE{exu_flush_final}} & exu_flush_ghr[`RV_BHT_GHR_RANGE]) |
                                         ({`RV_BHT_GHR_SIZE{~exu_flush_final & ifc_fetch_req_f2_raw & ~leak_one_f2}} & merged_ghr[`RV_BHT_GHR_RANGE]) |
                                         ({`RV_BHT_GHR_SIZE{~exu_flush_final & ~(ifc_fetch_req_f2_raw & ~leak_one_f2)}} & fghr[`RV_BHT_GHR_RANGE]));

   rvdff #(`RV_BHT_GHR_SIZE) fetchghr (.*, .clk(active_clk), .din(fghr_ns[`RV_BHT_GHR_RANGE]), .dout(fghr[`RV_BHT_GHR_RANGE]));
   assign ifu_bp_fghr_f2[`RV_BHT_GHR_RANGE] = fghr[`RV_BHT_GHR_RANGE];


   assign ifu_bp_way_f2[7:0] = way_raw[7:0];
   assign ifu_bp_hist1_f2[7:0]    = hist1_raw[7:0];
   assign ifu_bp_hist0_f2[7:0]    = hist0_raw[7:0];
   assign ifu_bp_pc4_f2[7:0]     = pc4_raw[7:0];
   assign ifu_bp_valid_f2[7:0]   = wayhit_f2[7:0] & ~{8{dec_tlu_bpred_disable}};
   assign ifu_bp_ret_f2[7:0]     = pret_raw[7:0];


    always_comb begin
       casez(ifc_fetch_addr_f2[3:1])
        3'b000 : begin
           bp_hist1_f2[7:0]    = hist1_raw[7:0];
           bp_valid_f2[7:0]   = wayhit_f2[7:0];
        end
        3'b001 : begin
           bp_hist1_f2[7:0]    = {1'b0, hist1_raw[7:1]};
           bp_valid_f2[7:0]   = {1'b0, wayhit_f2[7:1]};
        end
        3'b010 : begin
           bp_hist1_f2[7:0]    = {2'b0, hist1_raw[7:2]};
           bp_valid_f2[7:0]   = {2'b0, wayhit_f2[7:2]};
        end
        3'b011 : begin
           bp_hist1_f2[7:0]    = {3'b0, hist1_raw[7:3]};
           bp_valid_f2[7:0]   = {3'b0, wayhit_f2[7:3]};
        end
        3'b100 : begin
           bp_hist1_f2[7:0]    = {4'b0, hist1_raw[7:4]};
           bp_valid_f2[7:0]   = {4'b0, wayhit_f2[7:4]};
        end
        3'b101 : begin
           bp_hist1_f2[7:0]    = {5'b0, hist1_raw[7:5]};
           bp_valid_f2[7:0]   = {5'b0, wayhit_f2[7:5]};
        end
        3'b110 : begin
           bp_hist1_f2[7:0]    = {6'b0, hist1_raw[7:6]};
           bp_valid_f2[7:0]   = {6'b0, wayhit_f2[7:6]};
           end
        3'b111 : begin
           bp_hist1_f2[7:0]    = {7'b0, hist1_raw[7]};
           bp_valid_f2[7:0]   = {7'b0, wayhit_f2[7]};
        end
        default: begin
          bp_hist1_f2[7:0] = hist1_raw[7:0];
          bp_valid_f2[7:0] = wayhit_f2[7:0];
        end
    endcase

    end


    assign btb_fg_crossing_f2 = btb_sel_f2[0] & btb_rd_pc4_f2;

   wire [2:0] btb_sel_f2_enc, btb_sel_f2_enc_shift;
   assign btb_sel_f2_enc[2:0] = encode8_3(btb_sel_f2[7:0]);
   assign btb_sel_f2_enc_shift[2:0] = encode8_3({1'b0,btb_sel_f2[7:1]});

   assign bp_total_branch_offset_f2[3:1] =  (({3{ btb_rd_pc4_f2}} &  btb_sel_f2_enc_shift[2:0]) |
                                             ({3{~btb_rd_pc4_f2}} &  btb_sel_f2_enc[2:0]) |
                                             ({3{btb_fg_crossing_f2}}));


   logic [31:4] adder_pc_in_f2, ifc_fetch_adder_prior;
   rvdffe #(28) faddrf2_ff (.*, .en(ifc_fetch_req_f2 & ~ifu_bp_kill_next_f2 & tcm_fetch_valid_f2), .din(ifc_fetch_addr_f2[31:4]), .dout(ifc_fetch_adder_prior[31:4]));

   assign ifu_bp_poffset_f2[11:0] = btb_rd_tgt_f2[11:0];

   assign adder_pc_in_f2[31:4] = ( ({28{ btb_fg_crossing_f2}} & ifc_fetch_adder_prior[31:4]) |
                                   ({28{~btb_fg_crossing_f2}} & ifc_fetch_addr_f2[31:4]));

   rvbradder predtgt_addr (.pc({adder_pc_in_f2[31:4], bp_total_branch_offset_f2[3:1]}),
                         .offset(btb_rd_tgt_f2[11:0]),
                         .dout(bp_btb_target_adder_f2[31:1])
                         );

   assign ifu_bp_btb_target_f2[31:1] = btb_rd_ret_f2 & ~btb_rd_call_f2 ? rets_out[0][31:1] : bp_btb_target_adder_f2[31:1];


   rvbradder rs_addr (.pc({adder_pc_in_f2[31:4], bp_total_branch_offset_f2[3:1]}),
                    .offset({10'b0, btb_rd_pc4_f2, ~btb_rd_pc4_f2}),
                    .dout(bp_rs_call_target_f2[31:1])
                         );


   logic rs_overpop_correct, rsoverpop_valid_ns, rsoverpop_valid_f;
   logic [31:1] rsoverpop_ns, rsoverpop_f;
   logic rsunderpop_valid_ns, rsunderpop_valid_f, rs_underpop_correct;
   assign rs_overpop_correct = 1'b0;
   assign rs_underpop_correct = 1'b0;
   assign rsoverpop_f[31:1]  = 'b0;

   logic e4_rs_correct;
   assign e4_rs_correct = 1'b0;
   assign rs_correct = 1'b0;

   assign rs_push = ((btb_rd_call_f2 & ~btb_rd_ret_f2 & ifu_bp_kill_next_f2) | (rs_overpop_correct & ~rs_underpop_correct)) & ~rs_correct & ~e4_rs_correct;
   assign rs_pop = ((btb_rd_ret_f2 & ~btb_rd_call_f2 & ifu_bp_kill_next_f2) | (rs_underpop_correct & ~rs_overpop_correct)) & ~rs_correct & ~e4_rs_correct;
   assign rs_hold = ~rs_push & ~rs_pop & ~rs_overpop_correct & ~rs_underpop_correct & ~rs_correct & ~e4_rs_correct;


   assign rets_in[0][31:1] = ( ({31{rs_overpop_correct & rs_underpop_correct}} & rsoverpop_f[31:1]) |
                               ({31{rs_push & rs_overpop_correct}} & rsoverpop_f[31:1]) |
                               ({31{rs_push & ~rs_overpop_correct}} & bp_rs_call_target_f2[31:1]) |
                               ({31{rs_pop}}  & rets_out[1][31:1]) );

   assign rsenable[0] = ~rs_hold;

   for (i=0; i<`RV_RET_STACK_SIZE; i++) begin : retstack


      if(i==`RV_RET_STACK_SIZE-1) begin
         assign rets_in[i][31:1] = rets_out[i-1][31:1];
         assign rsenable[i] = rs_push | rs_correct | e4_rs_correct;
      end
      else if(i>0) begin
        assign rets_in[i][31:1] = ( ({31{rs_push}} & rets_out[i-1][31:1]) |
                                    ({31{rs_pop}}  & rets_out[i+1][31:1]) );
         assign rsenable[i] = rs_push | rs_pop | rs_correct | e4_rs_correct;
      end
      rvdffe #(31) rets_ff (.*, .en(rsenable[i]), .din(rets_in[i][31:1]), .dout(rets_out[i][31:1]));

   end : retstack


   assign dec_tlu_error_wb = dec_tlu_br0_start_error_wb | dec_tlu_br0_error_wb | dec_tlu_br1_start_error_wb | dec_tlu_br1_error_wb;
   assign dec_tlu_all_banks_error_wb = dec_tlu_br0_start_error_wb | (~dec_tlu_br0_error_wb & dec_tlu_br1_start_error_wb);

   assign dec_tlu_error_bank_wb[1:0] = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_bank_wb[1:0] : dec_tlu_br1_bank_wb[1:0];
   assign btb_error_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] : dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   assign dec_tlu_way_wb = (dec_tlu_br0_error_wb | dec_tlu_br0_start_error_wb) ? dec_tlu_br0_way_wb : dec_tlu_br1_way_wb;


   assign btb_error_wr_en_way0_d[3:0] = {4{dec_tlu_error_wb & ~dec_tlu_way_wb}} &
                                         (dec_tlu_all_banks_error_wb ? 4'b1111 : decode2_4(dec_tlu_error_bank_wb[1:0]));
   assign btb_error_wr_en_way1_d[3:0] = {4{dec_tlu_error_wb & dec_tlu_way_wb}} &
                                         (dec_tlu_all_banks_error_wb ? 4'b1111 : decode2_4(dec_tlu_error_bank_wb[1:0]));

   rvdff #(1+BTB_ADDR_WIDTH+8) btb_error_pipe_ff (.*, .clk(active_clk),
      .din({dec_tlu_error_wb, btb_error_addr_wb, btb_error_wr_en_way0_d,
            btb_error_wr_en_way1_d}),
      .dout({btb_error_pending, btb_error_addr_q, btb_error_wr_en_way0_q,
             btb_error_wr_en_way1_q}));

   assign btb_valid = exu_mp_valid & ~btb_error_pending;

   assign btb_wr_tag[`RV_BTB_BTAG_SIZE-1:0] = exu_mp_btag[`RV_BTB_BTAG_SIZE-1:0];
   rvbtb_tag_hash rdtagf1(.hash(fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]), .pc({ifc_fetch_addr_f1[31:4], 3'b0}));
   rvdff #(`RV_BTB_BTAG_SIZE) rdtagf (.*, .clk(active_clk), .din({fetch_rd_tag_f1[`RV_BTB_BTAG_SIZE-1:0]}), .dout({fetch_rd_tag_f2[`RV_BTB_BTAG_SIZE-1:0]}));

   assign btb_wr_data[16+`RV_BTB_BTAG_SIZE:0] = {btb_wr_tag[`RV_BTB_BTAG_SIZE-1:0], exu_mp_tgt[11:0], exu_mp_pc4, exu_mp_boffset, exu_mp_call | exu_mp_ja, exu_mp_ret | exu_mp_ja, btb_valid} ;

   assign exu_mp_valid_write = exu_mp_valid & exu_mp_ataken;
   assign btb_wr_en_way0[3:0] = ({4{~exu_mp_way & exu_mp_valid_write & ~btb_error_pending}} & decode2_4(exu_mp_bank[1:0])) |
                                  btb_error_wr_en_way0_q[3:0];

   assign btb_wr_en_way1[3:0] = ({4{exu_mp_way & exu_mp_valid_write & ~btb_error_pending}} & decode2_4(exu_mp_bank[1:0])) |
                                  btb_error_wr_en_way1_q[3:0];


   assign btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = btb_error_pending ? btb_error_addr_q[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] : exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO];

   logic [1:0] bht_wr_data0, bht_wr_data1, bht_wr_data2;
   logic [7:0] bht_wr_en0, bht_wr_en1, bht_wr_en2;

   assign middle_of_bank = exu_mp_pc4 ^ exu_mp_boffset;
   assign bht_wr_en0[7:0] = {8{exu_mp_valid & ~exu_mp_call & ~exu_mp_ret & ~exu_mp_ja}} & decode3_8({exu_mp_bank[1:0], middle_of_bank});
   assign bht_wr_en1[7:0] = {8{dec_tlu_br1_v_wb}} & decode3_8({dec_tlu_br1_bank_wb[1:0], dec_tlu_br1_middle_wb});
   assign bht_wr_en2[7:0] = {8{dec_tlu_br0_v_wb}} & decode3_8({dec_tlu_br0_bank_wb[1:0], dec_tlu_br0_middle_wb});


   assign bht_wr_data0[1:0] = exu_mp_hist[1:0];
   assign bht_wr_data1[1:0] = dec_tlu_br1_hist_wb[1:0];
   assign bht_wr_data2[1:0] = dec_tlu_br0_hist_wb[1:0];


   logic [`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] bht_rd_addr_f1, bht_wr_addr0, bht_wr_addr1, bht_wr_addr2;

   logic [`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] mp_hashed, br0_hashed_wb, br1_hashed_wb, bht_rd_addr_hashed_f1;
   rvbtb_ghr_hash mpghrhs  (.hashin(exu_mp_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(exu_mp_eghr[`RV_BHT_GHR_RANGE]), .hash(mp_hashed[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash br0ghrhs (.hashin(dec_tlu_br0_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(dec_tlu_br0_fghr_wb[`RV_BHT_GHR_RANGE]), .hash(br0_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash br1ghrhs (.hashin(dec_tlu_br1_addr_wb[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(dec_tlu_br1_fghr_wb[`RV_BHT_GHR_RANGE]), .hash(br1_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));
   rvbtb_ghr_hash fghrhs (.hashin(btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO]), .ghr(fghr_ns[`RV_BHT_GHR_RANGE]), .hash(bht_rd_addr_hashed_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO]));

   assign bht_wr_addr0[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = mp_hashed[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_wr_addr1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = br1_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_wr_addr2[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = br0_hashed_wb[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];
   assign bht_rd_addr_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = bht_rd_addr_hashed_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO];


    for (j=0 ; j<LRU_SIZE ; j++) begin : BTB_FLOPS

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way0 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[0])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way0 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[1])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way0 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[2])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way0_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way0 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way0[3])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way0_out[j]));


          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way1 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[0])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way1 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[1])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way1 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[2])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way1_out[j]));

          rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way1 (.*,
                    .en(((btb_wr_addr[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == j) & btb_wr_en_way1[3])),
                    .din        (btb_wr_data[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way1_out[j]));
    end

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way0_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way0_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way0_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way0_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way0_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank0_way1_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank0_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank1_way1_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank1_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank2_way1_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank2_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));

   rvdffe #(17+`RV_BTB_BTAG_SIZE) btb_bank3_way1_data_out (.*,
                    .en(ifc_fetch_req_f1),
                    .din        (btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0]),
                    .dout       (btb_bank3_rd_data_way1_f2   [16+`RV_BTB_BTAG_SIZE:0]));


    always_comb begin : BTB_rd_mux
        btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;

        btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;
        btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] = '0 ;

        for (int j=0; j< LRU_SIZE; j++) begin
          if (btb_rd_addr_f1[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] == (`RV_BTB_ADDR_HI-`RV_BTB_ADDR_LO+1)'(j)) begin

           btb_bank0_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank0_rd_data_way0_out[j];
           btb_bank1_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank1_rd_data_way0_out[j];
           btb_bank2_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank2_rd_data_way0_out[j];
           btb_bank3_rd_data_way0_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank3_rd_data_way0_out[j];

           btb_bank0_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank0_rd_data_way1_out[j];
           btb_bank1_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank1_rd_data_way1_out[j];
           btb_bank2_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank2_rd_data_way1_out[j];
           btb_bank3_rd_data_way1_f2_in[16+`RV_BTB_BTAG_SIZE:0] =  btb_bank3_rd_data_way1_out[j];


          end
        end
    end


   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0][NUM_BHT_LOOP-1:0][1:0]      bht_bank_wr_data ;
   logic [7:0] [`RV_BHT_ARRAY_DEPTH-1:0] [1:0]                bht_bank_rd_data_out ;
   logic [1:0]                                                bht_bank0_rd_data_f2_in, bht_bank1_rd_data_f2_in, bht_bank2_rd_data_f2_in, bht_bank3_rd_data_f2_in;
   logic [1:0]                                                bht_bank4_rd_data_f2_in, bht_bank5_rd_data_f2_in, bht_bank6_rd_data_f2_in, bht_bank7_rd_data_f2_in;
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0]                 bht_bank_clken ;
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0]                 bht_bank_clk   ;
   logic [7:0] [(`RV_BHT_ARRAY_DEPTH/NUM_BHT_LOOP)-1:0][NUM_BHT_LOOP-1:0]           bht_bank_sel   ;

   for ( i=0; i<8; i++) begin : BANKS
     for (genvar k=0 ; k < (`RV_BHT_ARRAY_DEPTH)/NUM_BHT_LOOP ; k++) begin : BHT_CLK_GROUP
     assign bht_bank_clken[i][k]  = (bht_wr_en0[i] & ((bht_wr_addr0[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH)) |
                                    (bht_wr_en1[i] & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH)) |
                                    (bht_wr_en2[i] & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) |  BHT_NO_ADDR_MATCH));

     assign bht_bank_clk[i][k] = '0;

     for (j=0 ; j<NUM_BHT_LOOP ; j++) begin : BHT_FLOPS
       assign   bht_bank_sel[i][k][j]    = (bht_wr_en0[i] & (bht_wr_addr0[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr0[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) |
                                           (bht_wr_en1[i] & (bht_wr_addr1[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) |
                                           (bht_wr_en2[i] & (bht_wr_addr2[NUM_BHT_LOOP_INNER_HI :`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ;

       assign bht_bank_wr_data[i][k][j]  = (bht_wr_en2[i] & (bht_wr_addr2[NUM_BHT_LOOP_INNER_HI:`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr2[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ? bht_wr_data2[1:0] :
                                           (bht_wr_en1[i] & (bht_wr_addr1[NUM_BHT_LOOP_INNER_HI:`RV_BHT_ADDR_LO] == j) & ((bht_wr_addr1[`RV_BHT_ADDR_HI: NUM_BHT_LOOP_OUTER_LO]==k) | BHT_NO_ADDR_MATCH)) ? bht_wr_data1[1:0] :
                                                                                                                      bht_wr_data0[1:0]   ;

          rvdffs_fpga #(2) bht_bank (.*,
                    .clk        (bht_bank_clk[i][k]),
                    .clken      (bht_bank_sel[i][k][j]),
                    .rawclk     (clk),
                    .en         (bht_bank_sel[i][k][j]),
                    .din        (bht_bank_wr_data[i][k][j]),
                    .dout       (bht_bank_rd_data_out[i][(16*k)+j]));

      end
   end
 end

    always_comb begin : BHT_rd_mux
     bht_bank0_rd_data_f2_in[1:0] = '0 ;
     bht_bank1_rd_data_f2_in[1:0] = '0 ;
     bht_bank2_rd_data_f2_in[1:0] = '0 ;
     bht_bank3_rd_data_f2_in[1:0] = '0 ;
     bht_bank4_rd_data_f2_in[1:0] = '0 ;
     bht_bank5_rd_data_f2_in[1:0] = '0 ;
     bht_bank6_rd_data_f2_in[1:0] = '0 ;
     bht_bank7_rd_data_f2_in[1:0] = '0 ;
     for (int j=0; j< `RV_BHT_ARRAY_DEPTH; j++) begin
       if (bht_rd_addr_f1[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] == (`RV_BHT_ADDR_HI-`RV_BHT_ADDR_LO+1)'(j)) begin
         bht_bank0_rd_data_f2_in[1:0] = bht_bank_rd_data_out[0][j];
         bht_bank1_rd_data_f2_in[1:0] = bht_bank_rd_data_out[1][j];
         bht_bank2_rd_data_f2_in[1:0] = bht_bank_rd_data_out[2][j];
         bht_bank3_rd_data_f2_in[1:0] = bht_bank_rd_data_out[3][j];
         bht_bank4_rd_data_f2_in[1:0] = bht_bank_rd_data_out[4][j];
         bht_bank5_rd_data_f2_in[1:0] = bht_bank_rd_data_out[5][j];
         bht_bank6_rd_data_f2_in[1:0] = bht_bank_rd_data_out[6][j];
         bht_bank7_rd_data_f2_in[1:0] = bht_bank_rd_data_out[7][j];
       end
      end
    end


   rvdffe #(16) bht_dataoutf (.*, .en         (ifc_fetch_req_f1),
                                 .din        ({bht_bank0_rd_data_f2_in[1:0],
                                               bht_bank1_rd_data_f2_in[1:0],
                                               bht_bank2_rd_data_f2_in[1:0],
                                               bht_bank3_rd_data_f2_in[1:0],
                                               bht_bank4_rd_data_f2_in[1:0],
                                               bht_bank5_rd_data_f2_in[1:0],
                                               bht_bank6_rd_data_f2_in[1:0],
                                               bht_bank7_rd_data_f2_in[1:0]
                                               }),
                                 .dout       ({bht_bank0_rd_data_f2   [1:0],
                                               bht_bank1_rd_data_f2   [1:0],
                                               bht_bank2_rd_data_f2   [1:0],
                                               bht_bank3_rd_data_f2   [1:0],
                                               bht_bank4_rd_data_f2   [1:0],
                                               bht_bank5_rd_data_f2   [1:0],
                                               bht_bank6_rd_data_f2   [1:0],
                                               bht_bank7_rd_data_f2   [1:0]
                                               }));


     function [2:0] encode8_3;
      input [7:0] in;

      encode8_3[2] = |in[7:4];
      encode8_3[1] = in[7] | in[6] | in[3] | in[2];
      encode8_3[0] = in[7] | in[5] | in[3] | in[1];

   endfunction
   function [7:0] decode3_8;
      input [2:0] in;

      decode3_8[7] =  in[2] &  in[1] &  in[0];
      decode3_8[6] =  in[2] &  in[1] & ~in[0];
      decode3_8[5] =  in[2] & ~in[1] &  in[0];
      decode3_8[4] =  in[2] & ~in[1] & ~in[0];
      decode3_8[3] = ~in[2] &  in[1] &  in[0];
      decode3_8[2] = ~in[2] &  in[1] & ~in[0];
      decode3_8[1] = ~in[2] & ~in[1] &  in[0];
      decode3_8[0] = ~in[2] & ~in[1] & ~in[0];

   endfunction
   function [3:0] decode2_4;
      input [1:0] in;

      decode2_4[3] =  in[1] &  in[0];
      decode2_4[2] =  in[1] & ~in[0];
      decode2_4[1] = ~in[1] &  in[0];
      decode2_4[0] = ~in[1] & ~in[0];

   endfunction

   function [3:0] countones;
      input [7:0] valid;

      begin

countones[3:0] = {3'b0, valid[7]} +
                 {3'b0, valid[6]} +
                 {3'b0, valid[5]} +
                 {3'b0, valid[4]} +
                 {3'b0, valid[3]} +
                 {3'b0, valid[2]} +
                 {3'b0, valid[1]} +
                 {3'b0, valid[0]};
      end
   endfunction
   function [2:0] newlru;
      input [2:0] lru;
      input [1:0] used;
      begin
newlru[2] = (lru[2] & ~used[0]) | (~used[1] & ~used[0]);
newlru[1] = (~used[1] & ~used[0]) | (used[0]);
newlru[0] = (~lru[2] & lru[1] & ~used[1] & ~used[0]) | (~lru[1] & ~lru[0] & used[0]) | (
    ~lru[2] & lru[0] & used[0]) | (lru[0] & ~used[1] & ~used[0]);
      end
   endfunction

   function [1:0] lru2way;
      input [2:0] lru;
      input [2:0] v;
      begin
         lru2way[1] = (~lru[2] & lru[1] & ~lru[0] & v[1] & v[0]) | (lru[2] & lru[0] & v[1] & v[0]) | (~v[2] & v[1] & v[0]);
         lru2way[0] = (lru[2] & ~lru[0] & v[2] & v[0]) | (~v[1] & v[0]);
      end
   endfunction

endmodule

