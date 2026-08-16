

module ifu_ifc_ctl
  (
   input logic clk,
   input logic free_clk,
   input logic active_clk,

   input logic clk_override,
   input logic rst_l,
   input logic scan_mode,

   input logic tcm_fetch_valid_f2,
   input logic critical_word_ready,
   input logic ifu_ic_mb_empty,

   input logic ifu_fb_consume1,
   input logic ifu_fb_consume2,

   input logic dec_tlu_flush_noredir_wb,
   input logic dec_tlu_dbg_halted,
   input logic dec_tlu_pmu_fw_halted,
   input logic exu_flush_final,
   input logic [31:1] exu_flush_path_final,

   input logic ifu_bp_kill_next_f2,
   input logic [31:1] ifu_bp_btb_target_f2,

   input logic [31:0]  dec_tlu_mrac_ff ,

   output logic  ifc_fetch_uncacheable_f1,

   output logic [31:1] ifc_fetch_addr_f1,
   output logic [31:1] ifc_fetch_addr_f2,

   output logic  ifc_fetch_req_f1,
   output logic  ifc_fetch_req_f1_raw,
   output logic  ifc_fetch_req_f2,

   output logic  ifu_pmu_fetch_stall,

   output logic  ifc_iccm_access_f1,
   output logic  ifc_region_acc_fault_f1

   );


   logic [31:1]  fetch_addr_bf,  miss_addr, ifc_fetch_addr_f1_raw;
   logic [31:1]  fetch_addr_next;
   logic [31:1]  miss_addr_ns;
   logic [4:0]   cacheable_select;
   logic [3:0]   fb_write_f1, fb_write_ns;

   logic         ifc_fetch_req_bf;
   logic         overflow_nc;
   logic         fb_full_f1_ns, fb_full_f1;
   logic         fb_right, fb_right2, fb_right3, fb_left, wfm, fetch_ns, idle;
   logic         fetch_req_f2_ns;
   logic         missff_en;
   logic         fetch_crit_word, critical_word_ready_d1, fetch_crit_word_d1, fetch_crit_word_d2;
   logic         reset_delayed, reset_detect, reset_detected;
   logic         sel_last_addr_bf, sel_miss_addr_bf, sel_btb_addr_bf, sel_next_addr_bf;
   logic         miss_f2, miss_a;
   logic         flush_fb;
   logic         dec_tlu_halted_f;
   logic         mb_empty_mod, goto_idle, leave_idle;
   logic         critical_word_ready_mod;
   logic         miss_sel_flush;
   logic         miss_sel_f2;
   logic         miss_sel_f1;
   logic         miss_sel_bf;
   logic         fetch_bf_en;
   logic         ifc_fetch_req_f2_raw;

   logic ifc_f2_clk;
   rvoclkhdr ifu_fa2_cgc ( .en(ifc_fetch_req_f1 | clk_override), .l1clk(ifc_f2_clk), .* );


   typedef enum  logic [1:0] { IDLE=2'b00, FETCH=2'b01, STALL=2'b10, WFM=2'b11} state_t;
   state_t state, next_state;


   rvdff #(2) reset_ff (.*, .clk(free_clk), .din({1'b1, reset_detect}), .dout({reset_detect, reset_detected}));

   assign reset_delayed = reset_detect ^ reset_detected;

   rvdff #(2) ran_ff (.*, .clk(free_clk), .din({dec_tlu_dbg_halted | dec_tlu_pmu_fw_halted, miss_f2}), .dout({dec_tlu_halted_f, miss_a}));


   assign critical_word_ready_mod = critical_word_ready & ~(fetch_crit_word_d2 & ~ifc_fetch_req_f2);


   assign fetch_crit_word = critical_word_ready_mod & ~critical_word_ready_d1 & ~exu_flush_final;

   assign missff_en = exu_flush_final | (~tcm_fetch_valid_f2 & ifc_fetch_req_f2) | ifu_bp_kill_next_f2 | fetch_crit_word_d1 | ifu_bp_kill_next_f2 | (ifc_fetch_req_f2 & ~ifc_fetch_req_f1 & ~fetch_crit_word_d2);
   assign miss_sel_flush = exu_flush_final & ((wfm | idle) & ~fetch_crit_word_d1);
   assign miss_sel_f2 = ~exu_flush_final & ~tcm_fetch_valid_f2 & ifc_fetch_req_f2;
   assign miss_sel_f1 = ~exu_flush_final & ~miss_sel_f2 & ~ifc_fetch_req_f1 & ifc_fetch_req_f2 & ~fetch_crit_word_d2 & ~ifu_bp_kill_next_f2;
   assign miss_sel_bf = ~miss_sel_f2 & ~miss_sel_f1 & ~miss_sel_flush;

   assign miss_addr_ns[31:1] = ( ({31{miss_sel_flush}} & exu_flush_path_final[31:1]) |
                                 ({31{miss_sel_f2}} & ifc_fetch_addr_f2[31:1]) |
                                 ({31{miss_sel_f1}} & ifc_fetch_addr_f1[31:1]) |
                                 ({31{miss_sel_bf}} & fetch_addr_bf[31:1]));


   rvdffe #(31) faddmiss_ff (.*, .en(missff_en), .din(miss_addr_ns[31:1]), .dout(miss_addr[31:1]));


   assign sel_last_addr_bf = ~miss_sel_flush & ~ifc_fetch_req_f1 & ifc_fetch_req_f2 & ~ifu_bp_kill_next_f2;
   assign sel_miss_addr_bf = ~miss_sel_flush & ~ifu_bp_kill_next_f2 & ~ifc_fetch_req_f1 & ~ifc_fetch_req_f2;
   assign sel_btb_addr_bf  = ~miss_sel_flush & ifu_bp_kill_next_f2;
   assign sel_next_addr_bf = ~miss_sel_flush & ifc_fetch_req_f1;


   assign fetch_addr_bf[31:1] = ( ({31{miss_sel_flush}} &  exu_flush_path_final[31:1]) |
                                   ({31{sel_miss_addr_bf}} & miss_addr[31:1]) |
                                   ({31{sel_btb_addr_bf}} & {ifu_bp_btb_target_f2[31:1]})|
                                   ({31{sel_last_addr_bf}} & {ifc_fetch_addr_f1[31:1]})|
                                   ({31{sel_next_addr_bf}} & {fetch_addr_next[31:1]}));

   assign {overflow_nc, fetch_addr_next[31:1]} = {({1'b0, ifc_fetch_addr_f1[31:4]} + 29'b1), 3'b0};

   assign ifc_fetch_req_bf = (fetch_ns | fetch_crit_word) ;
   assign fetch_bf_en = (fetch_ns | fetch_crit_word);

   assign miss_f2 = ifc_fetch_req_f2 & ~tcm_fetch_valid_f2;

   assign mb_empty_mod = (ifu_ic_mb_empty | exu_flush_final) & ~miss_f2 & ~miss_a;


   assign goto_idle = exu_flush_final & dec_tlu_flush_noredir_wb;

   assign leave_idle = exu_flush_final & ~dec_tlu_flush_noredir_wb & idle;


   assign next_state[1] = (~state[1] & state[0] & ~reset_delayed & miss_f2 & ~goto_idle) |
                          (state[1] & ~reset_delayed & ~mb_empty_mod & ~goto_idle);

   assign next_state[0] = (~goto_idle & leave_idle) | (state[0] & ~goto_idle) |
                          (reset_delayed);

   assign flush_fb = exu_flush_final;


   assign fb_right = (~ifu_fb_consume1 & ~ifu_fb_consume2 & miss_f2) |
                     ( ifu_fb_consume1 & ~ifu_fb_consume2 & ~ifc_fetch_req_f1 & ~miss_f2) |
                      (ifu_fb_consume2 &  ifc_fetch_req_f1 & ~miss_f2);


   assign fb_right2 = (ifu_fb_consume1 & ~ifu_fb_consume2 & miss_f2) |
                      (ifu_fb_consume2 & ~ifc_fetch_req_f1);

   assign fb_right3 = (ifu_fb_consume2 & miss_f2);

   assign fb_left = ifc_fetch_req_f1 & ~(ifu_fb_consume1 | ifu_fb_consume2) & ~miss_f2;

   assign fb_write_ns[3:0] = ( ({4{(flush_fb & ~ifc_fetch_req_f1)}} & 4'b0001) |
                               ({4{(flush_fb & ifc_fetch_req_f1)}} & 4'b0010) |
                               ({4{~flush_fb & fb_right }} & {1'b0, fb_write_f1[3:1]}) |
                               ({4{~flush_fb & fb_right2}} & {2'b0, fb_write_f1[3:2]}) |
                               ({4{~flush_fb & fb_right3}} & {3'b0, fb_write_f1[3]}  ) |
                               ({4{~flush_fb & fb_left  }} & {fb_write_f1[2:0], 1'b0}) |
                               ({4{~flush_fb & ~fb_right & ~fb_right2 & ~fb_left & ~fb_right3}}  & fb_write_f1[3:0]));


   assign fb_full_f1_ns = fb_write_ns[3];

   assign idle = state[1:0] == IDLE;
   assign wfm = state[1:0] == WFM;
   assign fetch_ns = next_state[1:0] == FETCH;

   rvdff #(2) fsm_ff (.*, .clk(active_clk), .din({next_state[1:0]}), .dout({state[1:0]}));
   rvdff #(5) fbwrite_ff (.*, .clk(active_clk), .din({fb_full_f1_ns, fb_write_ns[3:0]}), .dout({fb_full_f1, fb_write_f1[3:0]}));

   assign ifu_pmu_fetch_stall = wfm |
                                (ifc_fetch_req_f1_raw &
                                (fb_full_f1 & ~(ifu_fb_consume2 | ifu_fb_consume1 | exu_flush_final)));

   assign ifc_fetch_req_f1 = ( ifc_fetch_req_f1_raw &
                               ~ifu_bp_kill_next_f2 &
                               ~(fb_full_f1 & ~(ifu_fb_consume2 | ifu_fb_consume1 | exu_flush_final)) &
                               ~dec_tlu_flush_noredir_wb );


   assign fetch_req_f2_ns = ifc_fetch_req_f1 & ~miss_f2;

   rvdff #(2) req_ff (.*, .clk(active_clk), .din({ifc_fetch_req_bf, fetch_req_f2_ns}), .dout({ifc_fetch_req_f1_raw, ifc_fetch_req_f2_raw}));

   assign ifc_fetch_req_f2 = ifc_fetch_req_f2_raw & ~exu_flush_final;

   rvdffe #(31) faddrf1_ff  (.*, .en(fetch_bf_en), .din(fetch_addr_bf[31:1]), .dout(ifc_fetch_addr_f1_raw[31:1]));
   rvdff #(31) faddrf2_ff (.*,  .clk(ifc_f2_clk), .din(ifc_fetch_addr_f1[31:1]), .dout(ifc_fetch_addr_f2[31:1]));

   assign ifc_fetch_addr_f1[31:1] = ( ({31{exu_flush_final}} & exu_flush_path_final[31:1]) |
                                      ({31{~exu_flush_final}} & ifc_fetch_addr_f1_raw[31:1]));

   rvdff #(3) iccrit_ff (.*, .clk(active_clk), .din({critical_word_ready_mod, fetch_crit_word,    fetch_crit_word_d1}),
                                              .dout({critical_word_ready_d1,  fetch_crit_word_d1, fetch_crit_word_d2}));

   logic iccm_acc_in_region_f1;
   logic iccm_acc_in_range_f1;
   rvrangecheck #( .CCM_SADR    (`RV_ICCM_SADR),
                   .CCM_SIZE    (`RV_ICCM_SIZE) ) iccm_rangecheck (
                                                                     .addr     ({ifc_fetch_addr_f1[31:1],1'b0}) ,
                                                                     .in_range (iccm_acc_in_range_f1) ,
                                                                     .in_region(iccm_acc_in_region_f1)
                                                                     );

   assign ifc_iccm_access_f1 = iccm_acc_in_range_f1 ;

   assign ifc_region_acc_fault_f1 = ~iccm_acc_in_range_f1 & iccm_acc_in_region_f1 ;

   assign cacheable_select[4:0]    =  {ifc_fetch_addr_f1[31:28] , 1'b0 } ;
   assign ifc_fetch_uncacheable_f1 =  ~dec_tlu_mrac_ff[cacheable_select]  ;

endmodule

