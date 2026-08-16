

module rvdff #( parameter WIDTH=1 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );


   always_ff @(posedge clk or negedge rst_l) begin
      if (rst_l == 0)
        dout[WIDTH-1:0] <= 0;
      else
        dout[WIDTH-1:0] <= din[WIDTH-1:0];
   end


endmodule


module rvdffs #( parameter WIDTH=1 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

   rvdff #(WIDTH) dffs (.din((en) ? din[WIDTH-1:0] : dout[WIDTH-1:0]), .*);

endmodule


module rvdffsc #( parameter WIDTH=1 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

   logic [WIDTH-1:0]          din_new;
   assign din_new = {WIDTH{~clear}} & (en ? din[WIDTH-1:0] : dout[WIDTH-1:0]);
   rvdff #(WIDTH) dffsc (.din(din_new[WIDTH-1:0]), .*);

endmodule


module rvdff_fpga #( parameter WIDTH=1 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,
     input logic           scan_mode,

     output logic [WIDTH-1:0] dout
     );

    rvdffs #(WIDTH) dffs (.clk(rawclk), .en(clken), .*);


endmodule


module rvdffs_fpga #( parameter WIDTH=1 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,
     input logic           scan_mode,
     output logic [WIDTH-1:0] dout
     );

   rvdffs #(WIDTH)   dffs (.clk(rawclk), .en(clken & en), .*);

endmodule


module `TEC_RV_ICG
  (
   input logic TE, E, CP,
   output Q
   );

   logic  en_ff;
   logic  enable;

   assign      enable = E | TE;

`ifdef VERILATOR
   always @(negedge CP) begin
      en_ff <= enable;
   end
`else
   always @(CP, enable) begin
      if(!CP)
        en_ff = enable;
   end
`endif
   assign Q = CP & en_ff;

endmodule


module rvoclkhdr
  (
   input  logic en,
   input  logic clk,
   input  logic scan_mode,
   output logic l1clk
   );

   logic        TE;
   assign       TE = scan_mode;

   assign l1clk = clk;

endmodule

module rvdffe #( parameter WIDTH=1, parameter OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic           en,
     input  logic           clk,
     input  logic           rst_l,
     input  logic             scan_mode,
     output logic [WIDTH-1:0] dout
     );

   logic                      l1clk;


   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock

      rvdffs #(WIDTH) dff ( .* );

   end
   else
      $error("%m: rvdffe width must be >= 8");


endmodule

module rvsyncss #(parameter WIDTH = 251)
   (
     input  logic                 clk,
     input  logic                 rst_l,
     input  logic [WIDTH-1:0]     din,
     output logic [WIDTH-1:0]     dout
     );

   logic [WIDTH-1:0]              din_ff1;

   rvdff #(WIDTH) sync_ff1  (.*, .din (din[WIDTH-1:0]),     .dout(din_ff1[WIDTH-1:0]));
   rvdff #(WIDTH) sync_ff2  (.*, .din (din_ff1[WIDTH-1:0]), .dout(dout[WIDTH-1:0]));

endmodule

module rvlsadder
  (
    input logic [31:0] rs1,
    input logic [11:0] offset,

    output logic [31:0] dout
    );

   logic                cout;
   logic                sign;

   logic [31:12]        rs1_inc;
   logic [31:12]        rs1_dec;

   assign {cout,dout[11:0]} = {1'b0,rs1[11:0]} + {1'b0,offset[11:0]};

   assign rs1_inc[31:12] = rs1[31:12] + 1;

   assign rs1_dec[31:12] = rs1[31:12] - 1;

   assign sign = offset[11];

   assign dout[31:12] = ({20{  sign ^~  cout}} &     rs1[31:12]) |
                        ({20{ ~sign &   cout}}  & rs1_inc[31:12]) |
                        ({20{  sign &  ~cout}}  & rs1_dec[31:12]);

endmodule


module rvbradder
  (
    input [31:1] pc,
    input [12:1] offset,

    output [31:1] dout
    );

   logic          cout;
   logic          sign;

   logic [31:13]  pc_inc;
   logic [31:13]  pc_dec;

   assign {cout,dout[12:1]} = {1'b0,pc[12:1]} + {1'b0,offset[12:1]};

   assign pc_inc[31:13] = pc[31:13] + 1;

   assign pc_dec[31:13] = pc[31:13] - 1;

   assign sign = offset[12];


   assign dout[31:13] = ({19{  sign ^~  cout}} &     pc[31:13]) |
                        ({19{ ~sign &   cout}}  & pc_inc[31:13]) |
                        ({19{  sign &  ~cout}}  & pc_dec[31:13]);


endmodule


module rvtwoscomp #( parameter WIDTH=32 )
   (
     input logic [WIDTH-1:0] din,

     output logic [WIDTH-1:0] dout
     );

   logic [WIDTH-1:1]          dout_temp;

   genvar                     i;

   for ( i = 1; i < WIDTH; i++ )  begin : flip_after_first_one
      assign dout_temp[i] = (|din[i-1:0]) ? ~din[i] : din[i];
   end : flip_after_first_one

   assign dout[WIDTH-1:0]  = { dout_temp[WIDTH-1:1], din[0] };

endmodule


module rvmaskandmatch #( parameter WIDTH=32 )
   (
     input  logic [WIDTH-1:0] mask,
     input  logic [WIDTH-1:0] data,
     input  logic             masken,
     output logic             match
     );

   logic [WIDTH-1:0]          matchvec;
   logic                      masken_or_fullmask;

   assign masken_or_fullmask = masken &  ~(&mask[WIDTH-1:0]);

   assign matchvec[0]        = masken_or_fullmask | (mask[0] == data[0]);
   genvar                     i;

   for ( i = 1; i < WIDTH; i++ )  begin : match_after_first_zero
      assign matchvec[i] = (&mask[i-1:0] & masken_or_fullmask) ? 1'b1 : (mask[i] == data[i]);
   end : match_after_first_zero

   assign match  = &matchvec[WIDTH-1:0];

endmodule

module rvbtb_tag_hash (
                       input logic [31:1] pc,
                       output logic [`RV_BTB_BTAG_SIZE-1:0] hash
                       );
    assign hash = {(pc[`RV_BTB_ADDR_HI+`RV_BTB_BTAG_SIZE+`RV_BTB_BTAG_SIZE+`RV_BTB_BTAG_SIZE:`RV_BTB_ADDR_HI+`RV_BTB_BTAG_SIZE+`RV_BTB_BTAG_SIZE+1] ^
                   pc[`RV_BTB_ADDR_HI+`RV_BTB_BTAG_SIZE+`RV_BTB_BTAG_SIZE:`RV_BTB_ADDR_HI+`RV_BTB_BTAG_SIZE+1] ^
                   pc[`RV_BTB_ADDR_HI+`RV_BTB_BTAG_SIZE:`RV_BTB_ADDR_HI+1])};


endmodule

module rvbtb_addr_hash (
                        input logic [31:1] pc,
                        output logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] hash
                        );

   assign hash[`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] = pc[`RV_BTB_INDEX1_HI:`RV_BTB_INDEX1_LO] ^

                                                  pc[`RV_BTB_INDEX2_HI:`RV_BTB_INDEX2_LO] ^

                                                  pc[`RV_BTB_INDEX3_HI:`RV_BTB_INDEX3_LO];

endmodule

module rvbtb_ghr_hash (
                       input logic [`RV_BTB_ADDR_HI:`RV_BTB_ADDR_LO] hashin,
                       input logic [`RV_BHT_GHR_RANGE] ghr,
                       output logic [`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] hash
                       );


   assign hash[`RV_BHT_ADDR_HI:`RV_BHT_ADDR_LO] = `RV_BHT_HASH_STRING;

endmodule


module rvrangecheck  #(CCM_SADR = 32'h0,
                       CCM_SIZE  = 128) (
   input  logic [31:0]   addr,
   output logic          in_range,
   output logic          in_region
);

   localparam REGION_BITS = 4;
   localparam MASK_BITS = 10 + $clog2(CCM_SIZE);

   logic [31:0]          start_addr;
   logic [3:0]           region;

   assign start_addr[31:0]        = CCM_SADR;
   assign region[REGION_BITS-1:0] = start_addr[31:(32-REGION_BITS)];

   assign in_region = (addr[31:(32-REGION_BITS)] == region[REGION_BITS-1:0]);
   if (CCM_SIZE  == 48)
    assign in_range  = (addr[31:MASK_BITS] == start_addr[31:MASK_BITS]) & ~(&addr[MASK_BITS-1 : MASK_BITS-2]);
   else
    assign in_range  = (addr[31:MASK_BITS] == start_addr[31:MASK_BITS]);

endmodule
