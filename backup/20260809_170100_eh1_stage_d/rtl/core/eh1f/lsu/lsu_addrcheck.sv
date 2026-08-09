// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
// Stage-D TCM-only address checker.

module lsu_addrcheck
   import veer_types::*;
(
   input  logic        lsu_freeze_c2_dc2_clk,
   input  logic        lsu_freeze_c2_dc3_clk,
   input  logic        lsu_freeze_c2_dc2_clken,
   input  logic        lsu_freeze_c2_dc3_clken,
   input  logic        rst_l,
   input  logic        clk,

   input  logic [31:0] start_addr_dc1,
   input  logic [31:0] end_addr_dc1,
   input  lsu_pkt_t    lsu_pkt_dc1,
   input  logic [31:0] dec_tlu_mrac_ff,

   output logic        is_sideeffects_dc2,
   output logic        is_sideeffects_dc3,
   output logic        addr_in_dccm_dc1,
   output logic        addr_in_pic_dc1,
   output logic        addr_external_dc1,
   output logic        access_fault_dc1,
   output logic        misaligned_fault_dc1,

   input  logic        scan_mode
);

`include "global.h"

   localparam logic [31:0] DCCM_FIRST = `RV_DCCM_SADR;
   // Generated EH1 sizes are expressed in KiB.
   localparam logic [31:0] DCCM_LAST  =
      `RV_DCCM_SADR + (`RV_DCCM_SIZE * 32'd1024) - 1;
   localparam logic [31:0] MMIO_FIRST = 32'h1000_0000;
   localparam logic [31:0] MMIO_LAST  = 32'h1000_3fff;

   logic start_in_dccm, end_in_dccm;
   logic start_in_mmio, end_in_mmio;
   logic addr_in_mmio_dc1;
   logic is_sideeffects_dc1;
   logic is_aligned_dc1;

   assign start_in_dccm = (start_addr_dc1 >= DCCM_FIRST) &&
                           (start_addr_dc1 <= DCCM_LAST);
   assign end_in_dccm   = (end_addr_dc1 >= DCCM_FIRST) &&
                           (end_addr_dc1 <= DCCM_LAST);
   assign start_in_mmio = (start_addr_dc1 >= MMIO_FIRST) &&
                           (start_addr_dc1 <= MMIO_LAST);
   assign end_in_mmio   = (end_addr_dc1 >= MMIO_FIRST) &&
                           (end_addr_dc1 <= MMIO_LAST);

   assign addr_in_dccm_dc1 = start_in_dccm && end_in_dccm;
   assign addr_in_mmio_dc1 = start_in_mmio && end_in_mmio;
   assign addr_external_dc1 = addr_in_mmio_dc1;

   // The EH1 PIC is not part of the TCM-only SoC.  Keep this compatibility
   // output low until the remaining PIC ports are removed from the hierarchy.
   assign addr_in_pic_dc1 = 1'b0;

   assign is_aligned_dc1 = lsu_pkt_dc1.by ||
                           (lsu_pkt_dc1.half && !start_addr_dc1[0]) ||
                           (lsu_pkt_dc1.word && !(|start_addr_dc1[1:0]));
   assign is_sideeffects_dc1 = addr_in_mmio_dc1;

   // There is no external-memory escape path.  Every non-DCCM, non-MMIO data
   // access is rejected before it reaches the local peripheral request port.
   assign access_fault_dc1 = lsu_pkt_dc1.valid &&
                             !(addr_in_dccm_dc1 || addr_in_mmio_dc1);
   assign misaligned_fault_dc1 = lsu_pkt_dc1.valid &&
                                 addr_in_mmio_dc1 && !is_aligned_dc1;

   rvdff_fpga #(.WIDTH(1)) is_sideeffects_dc2ff (
      .din(is_sideeffects_dc1),
      .dout(is_sideeffects_dc2),
      .clk(lsu_freeze_c2_dc2_clk),
      .clken(lsu_freeze_c2_dc2_clken),
      .rawclk(clk),
      .rst_l(rst_l),
      .scan_mode(scan_mode)
   );

   rvdff_fpga #(.WIDTH(1)) is_sideeffects_dc3ff (
      .din(is_sideeffects_dc2),
      .dout(is_sideeffects_dc3),
      .clk(lsu_freeze_c2_dc3_clk),
      .clken(lsu_freeze_c2_dc3_clken),
      .rawclk(clk),
      .rst_l(rst_l),
      .scan_mode(scan_mode)
   );

   // These legacy inputs intentionally have no effect in the fixed map.
   logic unused_ok;
   assign unused_ok = &{1'b0, dec_tlu_mrac_ff};

endmodule
