

module lsu_bus_intf
   import mycpu_types::*;
(
   input  logic                         clk,
   input  logic                         rst_l,
   input  logic                         scan_mode,
   input  logic                         dec_tlu_wb_coalescing_disable,
   input  logic                         dec_tlu_ld_miss_byp_wb_disable,
   input  logic                         dec_tlu_sideeffect_posted_disable,

   input  logic                         lsu_c1_dc3_clk,
   input  logic                         lsu_c1_dc4_clk,
   input  logic                         lsu_c1_dc5_clk,
   input  logic                         lsu_c2_dc3_clk,
   input  logic                         lsu_c2_dc4_clk,
   input  logic                         lsu_c2_dc5_clk,
   input  logic                         lsu_freeze_c1_dc2_clk,
   input  logic                         lsu_freeze_c1_dc3_clk,
   input  logic                         lsu_freeze_c2_dc2_clk,
   input  logic                         lsu_freeze_c2_dc3_clk,
   input  logic                         lsu_freeze_c1_dc2_clken,
   input  logic                         lsu_freeze_c1_dc3_clken,
   input  logic                         lsu_freeze_c2_dc2_clken,
   input  logic                         lsu_freeze_c2_dc3_clken,
   input  logic                         lsu_bus_ibuf_c1_clk,
   input  logic                         lsu_bus_obuf_c1_clk,
   input  logic                         lsu_bus_buf_c1_clk,
   input  logic                         lsu_free_c2_clk,
   input  logic                         free_clk,
   input  logic                         lsu_busm_clk,

   input  logic                         lsu_busreq_dc2,
   input  lsu_pkt_t                     lsu_pkt_dc1,
   input  lsu_pkt_t                     lsu_pkt_dc2,
   input  lsu_pkt_t                     lsu_pkt_dc3,
   input  lsu_pkt_t                     lsu_pkt_dc4,
   input  lsu_pkt_t                     lsu_pkt_dc5,
   input  logic [31:0]                  lsu_addr_dc1,
   input  logic [31:0]                  lsu_addr_dc2,
   input  logic [31:0]                  lsu_addr_dc3,
   input  logic [31:0]                  lsu_addr_dc4,
   input  logic [31:0]                  lsu_addr_dc5,
   input  logic [31:0]                  end_addr_dc1,
   input  logic [31:0]                  end_addr_dc2,
   input  logic [31:0]                  end_addr_dc3,
   input  logic [31:0]                  end_addr_dc4,
   input  logic [31:0]                  end_addr_dc5,
   input  logic                         addr_external_dc1,
   input  logic                         addr_external_dc2,
   input  logic                         addr_external_dc3,
   input  logic                         addr_external_dc4,
   input  logic                         addr_external_dc5,
   input  logic [63:0]                  store_data_dc2,
   input  logic [63:0]                  store_data_dc3,
   input  logic [31:0]                  store_data_dc4,
   input  logic [31:0]                  store_data_dc5,
   input  logic                         lsu_commit_dc5,
   input  logic                         is_sideeffects_dc2,
   input  logic                         is_sideeffects_dc3,
   input  logic                         flush_dc2_up,
   input  logic                         flush_dc3,
   input  logic                         flush_dc4,
   input  logic                         flush_dc5,
   input  logic                         dec_tlu_cancel_e4,

   output logic                         lsu_freeze_dc3,
   output logic                         lsu_busreq_dc5,
   output logic                         lsu_bus_buffer_pend_any,
   output logic                         lsu_bus_buffer_full_any,
   output logic                         lsu_bus_buffer_empty_any,
   output logic [31:0]                  bus_read_data_dc3,
   output logic                         ld_bus_error_dc3,
   output logic [31:0]                  ld_bus_error_addr_dc3,
   output logic                         lsu_imprecise_error_load_any,
   output logic                         lsu_imprecise_error_store_any,
   output logic [31:0]                  lsu_imprecise_error_addr_any,

   input  logic                                dec_nonblock_load_freeze_dc2,
   output logic                                lsu_nonblock_load_valid_dc3,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_dc3,
   output logic                                lsu_nonblock_load_inv_dc5,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_dc5,
   output logic                                lsu_nonblock_load_data_valid,
   output logic                                lsu_nonblock_load_data_error,
   output logic [`RV_LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,
   output logic [31:0]                         lsu_nonblock_load_data,

   output logic                         lsu_pmu_bus_trxn,
   output logic                         lsu_pmu_bus_misaligned,
   output logic                         lsu_pmu_bus_error,
   output logic                         lsu_pmu_bus_busy,

   output logic                         lsu_mmio_valid,
   output logic                         lsu_mmio_write,
   output logic [31:0]                  lsu_mmio_addr,
   output logic [31:0]                  lsu_mmio_wdata,
   output logic [3:0]                   lsu_mmio_wstrb,
   input  logic                         lsu_mmio_ready,
   input  logic [31:0]                  lsu_mmio_rdata,
   input  logic                         lsu_mmio_error,

   input  logic                         lsu_bus_clk_en
);

   logic        load_pending;
   logic        store_pending;
   logic [31:0] load_addr_q;
   logic [31:0] store_addr_q;
   logic [31:0] store_wdata_q;
   logic [3:0]  store_wstrb_q;
   logic [3:0]  store_mask_dc5;
   logic [31:0] store_shifted_dc5;
   logic        external_in_pipe;
   logic        load_request_dc2;

   assign store_mask_dc5 = ({4{lsu_pkt_dc5.by}}   & 4'b0001) |
                            ({4{lsu_pkt_dc5.half}} & 4'b0011) |
                            ({4{lsu_pkt_dc5.word}} & 4'b1111);
   assign store_shifted_dc5 = store_data_dc5 << {lsu_addr_dc5[1:0], 3'b000};

   assign external_in_pipe =
      (lsu_pkt_dc1.valid && addr_external_dc1) ||
      (lsu_pkt_dc2.valid && addr_external_dc2) ||
      (lsu_pkt_dc3.valid && addr_external_dc3) ||
      (lsu_pkt_dc4.valid && addr_external_dc4) ||
      (lsu_pkt_dc5.valid && addr_external_dc5);

   assign lsu_busreq_dc5 = lsu_pkt_dc5.valid && addr_external_dc5 &&
                           (lsu_pkt_dc5.load || lsu_pkt_dc5.store);
   assign load_request_dc2 = lsu_busreq_dc2 && lsu_pkt_dc2.load &&
                             !flush_dc2_up;

   always_ff @(posedge clk or negedge rst_l) begin
      if (!rst_l) begin
         load_pending  <= 1'b0;
         store_pending <= 1'b0;
         load_addr_q   <= 32'b0;
         store_addr_q  <= 32'b0;
         store_wdata_q <= 32'b0;
         store_wstrb_q <= 4'b0;
      end else begin
         if (load_pending) begin
            if ((lsu_mmio_ready && lsu_mmio_valid) || dec_tlu_cancel_e4 ||
                flush_dc3 || flush_dc4 || flush_dc5)
               load_pending <= 1'b0;
         end else if (load_request_dc2) begin
            load_pending <= 1'b1;
            load_addr_q  <= lsu_addr_dc2;
         end

         if (store_pending) begin
            if (lsu_mmio_ready && lsu_mmio_valid)
               store_pending <= 1'b0;
         end else if (lsu_busreq_dc5 && lsu_pkt_dc5.store && lsu_commit_dc5) begin
            store_pending <= 1'b1;
            store_addr_q  <= lsu_addr_dc5;
            store_wdata_q <= store_shifted_dc5;
            store_wstrb_q <= store_mask_dc5 << lsu_addr_dc5[1:0];
         end
      end
   end

   assign lsu_mmio_valid = load_pending || store_pending;
   assign lsu_mmio_write = store_pending;
   assign lsu_mmio_addr  = store_pending ? store_addr_q  : load_addr_q;
   assign lsu_mmio_wdata = store_pending ? store_wdata_q : 32'b0;
   assign lsu_mmio_wstrb = store_pending ? store_wstrb_q : 4'b0;

   assign lsu_freeze_dc3 = (load_request_dc2 || load_pending) &&
                           !(load_pending && lsu_mmio_ready);
   assign bus_read_data_dc3 = lsu_mmio_rdata >> {load_addr_q[1:0], 3'b000};
   assign ld_bus_error_dc3 = load_pending && lsu_mmio_ready && lsu_mmio_error;
   assign ld_bus_error_addr_dc3 = load_addr_q;

   assign lsu_bus_buffer_pend_any  = load_pending || store_pending;
   assign lsu_bus_buffer_full_any  = external_in_pipe || load_pending || store_pending;
   assign lsu_bus_buffer_empty_any = !(external_in_pipe || load_pending || store_pending);
   assign lsu_imprecise_error_load_any  = 1'b0;
   assign lsu_imprecise_error_store_any = store_pending && lsu_mmio_ready && lsu_mmio_error;
   assign lsu_imprecise_error_addr_any  = store_addr_q;

   assign lsu_nonblock_load_valid_dc3   = 1'b0;
   assign lsu_nonblock_load_tag_dc3     = '0;
   assign lsu_nonblock_load_inv_dc5     = 1'b0;
   assign lsu_nonblock_load_inv_tag_dc5 = '0;
   assign lsu_nonblock_load_data_valid  = 1'b0;
   assign lsu_nonblock_load_data_error  = 1'b0;
   assign lsu_nonblock_load_data_tag    = '0;
   assign lsu_nonblock_load_data        = 32'b0;

   assign lsu_pmu_bus_trxn       = lsu_mmio_valid && lsu_mmio_ready;
   assign lsu_pmu_bus_misaligned = 1'b0;
   assign lsu_pmu_bus_error      = lsu_mmio_valid && lsu_mmio_ready && lsu_mmio_error;
   assign lsu_pmu_bus_busy       = lsu_mmio_valid && !lsu_mmio_ready;

endmodule
