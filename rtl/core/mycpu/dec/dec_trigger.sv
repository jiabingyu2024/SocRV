

module dec_trigger
   import mycpu_types::*;
(
   input logic         clk,
   input logic         rst_l,

   input trigger_pkt_t [3:0] trigger_pkt_any,
   input logic [31:1]  dec_i0_pc_d,
   input logic [31:1]  dec_i1_pc_d,

   output logic [3:0] dec_i0_trigger_match_d,
   output logic [3:0] dec_i1_trigger_match_d
);

   logic [3:0][31:0]  dec_i0_match_data;
   logic [3:0]        dec_i0_trigger_data_match;
   logic [3:0][31:0]  dec_i1_match_data;
   logic [3:0]        dec_i1_trigger_data_match;

   for (genvar i=0; i<4; i++) begin
      assign dec_i0_match_data[i][31:0] = ({32{~trigger_pkt_any[i].select & trigger_pkt_any[i].execute}} & {dec_i0_pc_d[31:1], trigger_pkt_any[i].tdata2[0]});

      assign dec_i1_match_data[i][31:0] = ({32{~trigger_pkt_any[i].select & trigger_pkt_any[i].execute}} & {dec_i1_pc_d[31:1], trigger_pkt_any[i].tdata2[0]} );

      rvmaskandmatch trigger_i0_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(dec_i0_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(dec_i0_trigger_data_match[i]));
      rvmaskandmatch trigger_i1_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(dec_i1_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(dec_i1_trigger_data_match[i]));

      assign dec_i0_trigger_match_d[i] = trigger_pkt_any[i].execute & trigger_pkt_any[i].m & dec_i0_trigger_data_match[i];
      assign dec_i1_trigger_match_d[i] = trigger_pkt_any[i].execute & trigger_pkt_any[i].m & dec_i1_trigger_data_match[i];
   end

endmodule

