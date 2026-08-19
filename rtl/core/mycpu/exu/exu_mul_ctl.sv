

module exu_mul_ctl
   import mycpu_types::*;
(
   input logic         clk,
   input logic         active_clk,
   input logic         clk_override,
   input logic         rst_l,
   input logic         scan_mode,

   input logic [31:0]  a,
   input logic [31:0]  b,

   input logic [31:0]  lsu_result_dc3,

   input logic         freeze,

   input mul_pkt_t     mp,


   output logic [31:0] out

   );


   logic                valid_e1, valid_e2;
   logic                mul_c1_e1_clken,   mul_c1_e2_clken,   mul_c1_e3_clken;
   logic                exu_mul_c1_e1_clk, exu_mul_c1_e2_clk, exu_mul_c1_e3_clk;

   logic        [31:0]  a_ff_e1, a_e1;
   logic        [31:0]  b_ff_e1, b_e1;
   logic                load_mul_rs1_bypass_e1, load_mul_rs2_bypass_e1;
   logic                rs1_sign_e1, rs1_neg_e1;
   logic                rs2_sign_e1, rs2_neg_e1;
   logic signed [32:0]  a_ff_e2, b_ff_e2;
   logic        [63:0]  prod_e3;
   logic                low_e1, low_e2, low_e3;
   logic        [2:0]   cm_op_e1, cm_op_e2, cm_op_e3;
   logic signed [31:0]  bf_prod_e2;
   logic signed [31:0]  bf_prod_e3;
   logic        [15:0]  crc_mid_e1, crc_mid_e2;
   logic        [15:0]  crc_result_e3;

   function automatic logic [15:0] crc_round4(
      input logic [15:0] crc_in,
      input logic [7:0] data_in
   );
      logic [15:0] crc;
      logic [7:0] data;
      logic feedback;
      integer k;
      begin
         crc = crc_in;
         data = data_in;
         for (k = 0; k < 4; k = k + 1) begin
            feedback = data[0] ^ crc[0];
            data = data >> 1;
            crc = (crc >> 1) ^ (feedback ? 16'hA001 : 16'h0000);
         end
         crc_round4 = crc;
      end
   endfunction

   function automatic logic [15:0] crc_round8(
      input logic [15:0] crc_in,
      input logic [7:0] data_in
   );
      logic [15:0] crc;
      logic [7:0] data;
      logic feedback;
      integer k;
      begin
         crc = crc_in;
         data = data_in;
         for (k = 0; k < 8; k = k + 1) begin
            feedback = data[0] ^ crc[0];
            data = data >> 1;
            crc = (crc >> 1) ^ (feedback ? 16'hA001 : 16'h0000);
         end
         crc_round8 = crc;
      end
   endfunction


   assign mul_c1_e1_clken        = (mp.valid | clk_override) & ~freeze;
   assign mul_c1_e2_clken        = (valid_e1 | clk_override) & ~freeze;
   assign mul_c1_e3_clken        = (valid_e2 | clk_override) & ~freeze;


   rvdffs      #(1)  valid_e1_ff      (.*, .din(mp.valid),                  .dout(valid_e1),               .clk(active_clk),        .en(~freeze));

   rvdff_fpga  #(1)  rs1_sign_e1_ff   (.*, .din(mp.rs1_sign),               .dout(rs1_sign_e1),            .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  rs2_sign_e1_ff   (.*, .din(mp.rs2_sign),               .dout(rs2_sign_e1),            .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  low_e1_ff        (.*, .din(mp.low),                    .dout(low_e1),                 .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(3)  cm_op_e1_ff      (.*, .din(mp.cm_op),                  .dout(cm_op_e1),               .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  ld_rs1_byp_e1_ff (.*, .din(mp.load_mul_rs1_bypass_e1), .dout(load_mul_rs1_bypass_e1), .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));
   rvdff_fpga  #(1)  ld_rs2_byp_e1_ff (.*, .din(mp.load_mul_rs2_bypass_e1), .dout(load_mul_rs2_bypass_e1), .clk(exu_mul_c1_e1_clk), .clken(mul_c1_e1_clken), .rawclk(clk));

   rvdffe  #(32) a_e1_ff          (.*, .din(a[31:0]),                   .dout(a_ff_e1[31:0]),          .en(mul_c1_e1_clken));
   rvdffe  #(32) b_e1_ff          (.*, .din(b[31:0]),                   .dout(b_ff_e1[31:0]),          .en(mul_c1_e1_clken));


   assign a_e1[31:0]             = (load_mul_rs1_bypass_e1)  ?  lsu_result_dc3[31:0]  :  a_ff_e1[31:0];
   assign b_e1[31:0]             = (load_mul_rs2_bypass_e1)  ?  lsu_result_dc3[31:0]  :  b_ff_e1[31:0];

   assign rs1_neg_e1             =  rs1_sign_e1 & a_e1[31];
   assign rs2_neg_e1             =  rs2_sign_e1 & b_e1[31];
   assign crc_mid_e1             = (cm_op_e1 == 3'd3) ?
                                    crc_round8(a_e1[15:0], b_e1[7:0]) :
                                    crc_round4(a_e1[15:0], b_e1[7:0]);


   rvdffs       #(1)  valid_e2_ff      (.*, .din(valid_e1),                  .dout(valid_e2),          .clk(active_clk),        .en(~freeze));

   rvdff_fpga   #(1)    low_e2_ff      (.*, .din(low_e1),                    .dout(low_e2),            .clk(exu_mul_c1_e2_clk), .clken(mul_c1_e2_clken), .rawclk(clk));
   rvdff_fpga   #(3)    cm_op_e2_ff    (.*, .din(cm_op_e1),                  .dout(cm_op_e2),          .clk(exu_mul_c1_e2_clk), .clken(mul_c1_e2_clken), .rawclk(clk));

   rvdffe  #(33) a_e2_ff          (.*, .din({rs1_neg_e1, a_e1[31:0]}),  .dout(a_ff_e2[32:0]),          .en(mul_c1_e2_clken));
   rvdffe  #(33) b_e2_ff          (.*, .din({rs2_neg_e1, b_e1[31:0]}),  .dout(b_ff_e2[32:0]),          .en(mul_c1_e2_clken));
   rvdffe  #(16) crc_mid_e2_ff    (.*, .din(crc_mid_e1),                 .dout(crc_mid_e2),             .en(mul_c1_e2_clken));


   logic signed [65:0]  prod_e2;

   assign prod_e2[65:0]          =  a_ff_e2  *  b_ff_e2;
   assign bf_prod_e2 = $signed(a_ff_e2[15:0]) * $signed(b_ff_e2[15:0]);
   rvdff_fpga  #(1)    low_e3_ff      (.*, .din(low_e2),                    .dout(low_e3),                 .clk(exu_mul_c1_e3_clk), .clken(mul_c1_e3_clken), .rawclk(clk));
   rvdff_fpga  #(3)    cm_op_e3_ff    (.*, .din(cm_op_e2),                  .dout(cm_op_e3),               .clk(exu_mul_c1_e3_clk), .clken(mul_c1_e3_clken), .rawclk(clk));

   rvdffe      #(64) prod_e3_ff       (.*, .din(prod_e2[63:0]),             .dout(prod_e3[63:0]),          .en(mul_c1_e3_clken));
   rvdffe      #(32) bf_prod_e3_ff    (.*, .din(bf_prod_e2),                .dout(bf_prod_e3),             .en(mul_c1_e3_clken));
   rvdffe      #(16) crc_result_e3_ff (.*, .din((cm_op_e2 == 3'd3) ?
                                                crc_round8(crc_mid_e2, b_ff_e2[15:8]) :
                                                crc_round4(crc_mid_e2, {4'b0, b_ff_e2[7:4]})),
                                      .dout(crc_result_e3), .en(mul_c1_e3_clken));


   always_comb begin
      unique case (cm_op_e3)
         3'd1: out = (($signed(bf_prod_e3) >>> 2) & 32'd15) *
                      (($signed(bf_prod_e3) >>> 5) & 32'd127);
         3'd2, 3'd3: out = {16'b0, crc_result_e3};
         default: out = low_e3 ? prod_e3[31:0] : prod_e3[63:32];
      endcase
   end


endmodule
