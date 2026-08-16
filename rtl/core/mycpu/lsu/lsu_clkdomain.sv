

module lsu_clkdomain
   import mycpu_types::*;
(
   input logic      clk,
   input logic      free_clk,
   input logic      rst_l,


   input logic      clk_override,
   input logic      lsu_freeze_dc3,
   input logic      addr_in_dccm_dc2,
   input logic      load_stbuf_reqvld_dc3,
   input logic      store_stbuf_reqvld_dc3,
   input logic      stbuf_reqvld_any,
   input logic      stbuf_reqvld_flushed_any,
   input logic      lsu_busreq_dc5,
   input logic      lsu_bus_buffer_pend_any,
   input logic      lsu_bus_buffer_empty_any,
   input logic      lsu_stbuf_empty_any,


   input logic      lsu_bus_clk_en,

   input lsu_pkt_t  lsu_p,
   input lsu_pkt_t  lsu_pkt_dc1,
   input lsu_pkt_t  lsu_pkt_dc2,
   input lsu_pkt_t  lsu_pkt_dc3,
   input lsu_pkt_t  lsu_pkt_dc4,
   input lsu_pkt_t  lsu_pkt_dc5,


   output logic     lsu_c1_dc3_clk,
   output logic     lsu_c1_dc4_clk,
   output logic     lsu_c1_dc5_clk,

   output logic     lsu_c2_dc3_clk,
   output logic     lsu_c2_dc4_clk,
   output logic     lsu_c2_dc5_clk,

   output logic     lsu_store_c1_dc1_clken,
   output logic     lsu_store_c1_dc2_clken,
   output logic     lsu_store_c1_dc3_clken,
   output logic     lsu_store_c1_dc4_clk,
   output logic     lsu_store_c1_dc5_clk,

   output logic     lsu_freeze_c1_dc1_clken,
   output logic     lsu_freeze_c1_dc2_clken,
   output logic     lsu_freeze_c1_dc3_clken,

   output logic     lsu_freeze_c1_dc2_clk,
   output logic     lsu_freeze_c1_dc3_clk,

   output logic     lsu_freeze_c2_dc1_clk,
   output logic     lsu_freeze_c2_dc2_clk,
   output logic     lsu_freeze_c2_dc3_clk,
   output logic     lsu_freeze_c2_dc4_clk,

   output logic     lsu_freeze_c2_dc1_clken,
   output logic     lsu_freeze_c2_dc2_clken,
   output logic     lsu_freeze_c2_dc3_clken,
   output logic     lsu_freeze_c2_dc4_clken,

   output logic     lsu_dccm_c1_dc3_clk,
   output logic     lsu_dccm_c1_dc3_clken,

   output logic     lsu_stbuf_c1_clk,
   output logic     lsu_bus_obuf_c1_clk,
   output logic     lsu_bus_ibuf_c1_clk,
   output logic     lsu_bus_buf_c1_clk,
   output logic     lsu_busm_clk,

   output logic     lsu_free_c2_clk,

   input  logic     scan_mode
);

   logic lsu_c1_dc1_clken, lsu_c1_dc2_clken, lsu_c1_dc3_clken, lsu_c1_dc4_clken, lsu_c1_dc5_clken;
   logic lsu_c2_dc3_clken, lsu_c2_dc4_clken, lsu_c2_dc5_clken;
   logic lsu_c1_dc1_clken_q, lsu_c1_dc2_clken_q, lsu_c1_dc3_clken_q, lsu_c1_dc4_clken_q, lsu_c1_dc5_clken_q;
   logic lsu_store_c1_dc4_clken, lsu_store_c1_dc5_clken;

   logic lsu_freeze_c1_dc4_clken;

   logic lsu_freeze_c1_dc1_clken_q, lsu_freeze_c1_dc2_clken_q, lsu_freeze_c1_dc3_clken_q, lsu_freeze_c1_dc4_clken_q;

   logic lsu_stbuf_c1_clken;
   logic lsu_bus_ibuf_c1_clken, lsu_bus_obuf_c1_clken, lsu_bus_buf_c1_clken;


   logic lsu_free_c1_clken, lsu_free_c1_clken_q, lsu_free_c2_clken;
   logic lsu_bus_valid_clken;


   assign lsu_c1_dc1_clken = lsu_p.valid | clk_override;
   assign lsu_c1_dc2_clken = lsu_pkt_dc1.valid | lsu_c1_dc1_clken_q | clk_override;
   assign lsu_c1_dc3_clken = lsu_pkt_dc2.valid | lsu_c1_dc2_clken_q | clk_override;
   assign lsu_c1_dc4_clken = lsu_pkt_dc3.valid | lsu_c1_dc3_clken_q | clk_override;
   assign lsu_c1_dc5_clken = lsu_pkt_dc4.valid | lsu_c1_dc4_clken_q | clk_override;

   assign lsu_c2_dc3_clken = lsu_c1_dc3_clken | lsu_c1_dc3_clken_q | clk_override;
   assign lsu_c2_dc4_clken = lsu_c1_dc4_clken | lsu_c1_dc4_clken_q | clk_override;
   assign lsu_c2_dc5_clken = lsu_c1_dc5_clken | lsu_c1_dc5_clken_q | clk_override;

   assign lsu_store_c1_dc1_clken = ((lsu_c1_dc1_clken & lsu_p.store) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc2_clken = ((lsu_c1_dc2_clken & lsu_pkt_dc1.store) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc3_clken = ((lsu_c1_dc3_clken & lsu_pkt_dc2.store) | clk_override) & ~lsu_freeze_dc3;
   assign lsu_store_c1_dc4_clken = (lsu_c1_dc4_clken & lsu_pkt_dc3.store) | clk_override;
   assign lsu_store_c1_dc5_clken = (lsu_c1_dc5_clken & lsu_pkt_dc4.store) | clk_override;

   assign lsu_freeze_c1_dc1_clken = (lsu_p.valid | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc2_clken = (lsu_pkt_dc1.valid | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc3_clken = (lsu_pkt_dc2.valid | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c1_dc4_clken = (lsu_pkt_dc3.valid | clk_override) & ~lsu_freeze_dc3;

   assign lsu_freeze_c2_dc1_clken = (lsu_freeze_c1_dc1_clken | lsu_freeze_c1_dc1_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc2_clken = (lsu_freeze_c1_dc2_clken | lsu_freeze_c1_dc2_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc3_clken = (lsu_freeze_c1_dc3_clken | lsu_freeze_c1_dc3_clken_q | clk_override) & ~lsu_freeze_dc3;
   assign lsu_freeze_c2_dc4_clken = (lsu_freeze_c1_dc4_clken | lsu_freeze_c1_dc4_clken_q | clk_override) & ~lsu_freeze_dc3;


   assign lsu_stbuf_c1_clken = load_stbuf_reqvld_dc3 | store_stbuf_reqvld_dc3 | stbuf_reqvld_any | stbuf_reqvld_flushed_any | clk_override;
   assign lsu_bus_ibuf_c1_clken = lsu_busreq_dc5 | clk_override;
   assign lsu_bus_obuf_c1_clken = ((lsu_bus_buffer_pend_any | lsu_busreq_dc5) & lsu_bus_clk_en) | clk_override;
   assign lsu_bus_buf_c1_clken  = ~lsu_bus_buffer_empty_any | lsu_busreq_dc5 | clk_override;

   assign lsu_dccm_c1_dc3_clken = ((lsu_c1_dc3_clken & addr_in_dccm_dc2) | clk_override) & ~lsu_freeze_dc3;

   assign lsu_free_c1_clken = (lsu_p.valid | lsu_pkt_dc1.valid | lsu_pkt_dc2.valid | lsu_pkt_dc3.valid | lsu_pkt_dc4.valid | lsu_pkt_dc5.valid) |
                              ~lsu_bus_buffer_empty_any | ~lsu_stbuf_empty_any | clk_override;
   assign lsu_free_c2_clken = lsu_free_c1_clken | lsu_free_c1_clken_q | clk_override;


   rvdff #(1) lsu_free_c1_clkenff (.din(lsu_free_c1_clken), .dout(lsu_free_c1_clken_q), .clk(free_clk), .*);

   rvdff #(1) lsu_c1_dc1_clkenff (.din(lsu_c1_dc1_clken), .dout(lsu_c1_dc1_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc2_clkenff (.din(lsu_c1_dc2_clken), .dout(lsu_c1_dc2_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc3_clkenff (.din(lsu_c1_dc3_clken), .dout(lsu_c1_dc3_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc4_clkenff (.din(lsu_c1_dc4_clken), .dout(lsu_c1_dc4_clken_q), .clk(lsu_free_c2_clk), .*);
   rvdff #(1) lsu_c1_dc5_clkenff (.din(lsu_c1_dc5_clken), .dout(lsu_c1_dc5_clken_q), .clk(lsu_free_c2_clk), .*);

   rvdff_fpga #(1) lsu_freeze_c1_dc1_clkenff (.din(lsu_freeze_c1_dc1_clken), .dout(lsu_freeze_c1_dc1_clken_q), .clk(lsu_freeze_c2_dc1_clk), .clken(lsu_freeze_c2_dc1_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc2_clkenff (.din(lsu_freeze_c1_dc2_clken), .dout(lsu_freeze_c1_dc2_clken_q), .clk(lsu_freeze_c2_dc2_clk), .clken(lsu_freeze_c2_dc2_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc3_clkenff (.din(lsu_freeze_c1_dc3_clken), .dout(lsu_freeze_c1_dc3_clken_q), .clk(lsu_freeze_c2_dc3_clk), .clken(lsu_freeze_c2_dc3_clken), .rawclk(clk), .*);
   rvdff_fpga #(1) lsu_freeze_c1_dc4_clkenff (.din(lsu_freeze_c1_dc4_clken), .dout(lsu_freeze_c1_dc4_clken_q), .clk(lsu_freeze_c2_dc4_clk), .clken(lsu_freeze_c2_dc4_clken), .rawclk(clk), .*);


   rvoclkhdr lsu_c1dc3_cgc ( .en(lsu_c1_dc3_clken), .l1clk(lsu_c1_dc3_clk), .* );
   rvoclkhdr lsu_c1dc4_cgc ( .en(lsu_c1_dc4_clken), .l1clk(lsu_c1_dc4_clk), .* );
   rvoclkhdr lsu_c1dc5_cgc ( .en(lsu_c1_dc5_clken), .l1clk(lsu_c1_dc5_clk), .* );

   rvoclkhdr lsu_c2dc3_cgc ( .en(lsu_c2_dc3_clken), .l1clk(lsu_c2_dc3_clk), .* );
   rvoclkhdr lsu_c2dc4_cgc ( .en(lsu_c2_dc4_clken), .l1clk(lsu_c2_dc4_clk), .* );
   rvoclkhdr lsu_c2dc5_cgc ( .en(lsu_c2_dc5_clken), .l1clk(lsu_c2_dc5_clk), .* );

   rvoclkhdr lsu_store_c1dc4_cgc (.en(lsu_store_c1_dc4_clken), .l1clk(lsu_store_c1_dc4_clk), .*);
   rvoclkhdr lsu_store_c1dc5_cgc (.en(lsu_store_c1_dc5_clken), .l1clk(lsu_store_c1_dc5_clk), .*);

   assign lsu_freeze_c1_dc2_clk = 1'b0;
   assign lsu_freeze_c1_dc3_clk = 1'b0;
   assign lsu_freeze_c2_dc1_clk = 1'b0;
   assign lsu_freeze_c2_dc2_clk = 1'b0;
   assign lsu_freeze_c2_dc3_clk = 1'b0;
   assign lsu_freeze_c2_dc4_clk = 1'b0;

   assign lsu_busm_clk = 1'b0;
   assign lsu_dccm_c1_dc3_clk = 1'b0;


   rvoclkhdr lsu_stbuf_c1_cgc ( .en(lsu_stbuf_c1_clken), .l1clk(lsu_stbuf_c1_clk), .* );
   rvoclkhdr lsu_bus_ibuf_c1_cgc ( .en(lsu_bus_ibuf_c1_clken), .l1clk(lsu_bus_ibuf_c1_clk), .* );
   rvoclkhdr lsu_bus_obuf_c1_cgc ( .en(lsu_bus_obuf_c1_clken), .l1clk(lsu_bus_obuf_c1_clk), .* );
   rvoclkhdr lsu_bus_buf_c1_cgc  ( .en(lsu_bus_buf_c1_clken),  .l1clk(lsu_bus_buf_c1_clk), .* );


   rvoclkhdr lsu_free_cgc (.en(lsu_free_c2_clken), .l1clk(lsu_free_c2_clk), .*);

endmodule

