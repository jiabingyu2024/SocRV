
//********************************************************************************
// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//********************************************************************************


//********************************************************************************
// Function: Icache , iccm  control
// BFF -> F1 -> F2 -> A
//********************************************************************************

module ifu_mem_ctl
   import veer_types::*;
(
   input logic clk,
   input logic free_clk,                                            // free clock always except during pause
   input logic active_clk,                                          // Active always except during pause
   input logic rst_l,

   input logic                       exu_flush_final,               // Flush from the pipeline.
   input logic                       dec_tlu_flush_err_wb,          // Flush from the pipeline due to perr.

   input logic [31:1]                fetch_addr_f1,                 // Fetch Address byte aligned always.      F1 stage.
   input logic                       ifc_fetch_uncacheable_f1,      // The fetch request is uncacheable space. F1 stage
   input logic                       ifc_fetch_req_f1,              // Fetch request. Comes with the address.  F1 stage
   input logic                       ifc_fetch_req_f1_raw,          // Fetch request without some qualifications. Used for clock-gating. F1 stage
   input logic                       ifc_iccm_access_f1,            // This request is to the ICCM. Do not generate misses to the bus.
   input logic                       ifc_region_acc_fault_f1,       // Access fault. in ICCM region but offset is outside defined ICCM.
   input logic                       ifc_dma_access_ok,             // It is OK to give dma access to the ICCM. (ICCM is not busy this cycle).
   input logic                       dec_tlu_fence_i_wb,            // Fence.i instruction is committing. Clear all Icache valids.


   input logic [16:6]                ifu_icache_error_index,        //  Index with parity/ecc error
   input logic                       ifu_icache_error_val,          //  Parity/Ecc  error
   input logic                       ifu_icache_sb_error_val,       //  single bit iccm  error
   input logic [7:1]                 ifu_bp_inst_mask_f2,           // tell ic which valids to kill because of a taken branch, right justified

   output logic                      ifu_miss_state_idle,           // No icache misses are outstanding.
   output logic                      ifu_ic_mb_empty,               // Continue with normal fetching. This does not mean that miss is finished.
   output logic                      ic_dma_active  ,               // In the middle of servicing dma request to ICCM. Do not make any new requests.
   output logic                      ic_write_stall,                // Stall fetch the cycle we are writing the cache.

/// PMU signals
   output logic                      ifu_pmu_ic_miss,               // IC miss event
   output logic                      ifu_pmu_ic_hit,                // IC hit event
   output logic                      ifu_pmu_bus_error,             // Bus error event
   output logic                      ifu_pmu_bus_busy,              // Bus busy event
   output logic                      ifu_pmu_bus_trxn,              // Bus transaction

   // AXI Write Channels - IFU never writes. So, 0 out mostly
   output logic                           ifu_axi_awvalid,
   input  logic                           ifu_axi_awready,
   output logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_awid,
   output logic [31:0]                    ifu_axi_awaddr,
   output logic [3:0]                     ifu_axi_awregion,
   output logic [7:0]                     ifu_axi_awlen,
   output logic [2:0]                     ifu_axi_awsize,
   output logic [1:0]                     ifu_axi_awburst,
   output logic                           ifu_axi_awlock,
   output logic [3:0]                     ifu_axi_awcache,
   output logic [2:0]                     ifu_axi_awprot,
   output logic [3:0]                     ifu_axi_awqos,

   output logic                           ifu_axi_wvalid,
   input  logic                           ifu_axi_wready,
   output logic [63:0]                    ifu_axi_wdata,
   output logic [7:0]                     ifu_axi_wstrb,
   output logic                           ifu_axi_wlast,

   input  logic                           ifu_axi_bvalid,
   output logic                           ifu_axi_bready,
   input  logic [1:0]                     ifu_axi_bresp,
   input  logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_bid,

   // AXI Read Channels
   output logic                           ifu_axi_arvalid,
   input  logic                           ifu_axi_arready,
   output logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_arid,
   output logic [31:0]                    ifu_axi_araddr,
   output logic [3:0]                     ifu_axi_arregion,
   output logic [7:0]                     ifu_axi_arlen,
   output logic [2:0]                     ifu_axi_arsize,
   output logic [1:0]                     ifu_axi_arburst,
   output logic                           ifu_axi_arlock,
   output logic [3:0]                     ifu_axi_arcache,
   output logic [2:0]                     ifu_axi_arprot,
   output logic [3:0]                     ifu_axi_arqos,

   input  logic                           ifu_axi_rvalid,
   output logic                           ifu_axi_rready,
   input  logic [`RV_IFU_BUS_TAG-1:0]     ifu_axi_rid,
   input  logic [63:0]                    ifu_axi_rdata,
   input  logic [1:0]                     ifu_axi_rresp,
   input  logic                           ifu_axi_rlast,

    /// SCVI Bus interface
    input  logic                     ifu_bus_clk_en,


   input  logic                      dma_iccm_req,      //  dma iccm command (read or write)
   input  logic [31:0]               dma_mem_addr,      //  dma address
   input  logic [2:0]                dma_mem_sz,        //  size
   input  logic                      dma_mem_write,     //  write
   input  logic [63:0]               dma_mem_wdata,     //  write data

   output logic                      iccm_dma_ecc_error,//   Data read from iccm has an ecc error
   output logic                      iccm_dma_rvalid,   //   Data read from iccm is valid
   output logic [63:0]               iccm_dma_rdata,    //   dma data read from iccm
   output logic                      iccm_ready,        //   iccm ready to accept new command.


//   I$ & ITAG Ports
   output logic [31:2]               ic_rw_addr,         // Read/Write addresss to the Icache.
   output logic [3:0]                ic_wr_en,           // Icache write enable, when filling the Icache.
   output logic                      ic_rd_en,           // Icache read  enable.

`ifdef RV_ICACHE_ECC
   output logic [83:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [167:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [24:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [41:0]               ic_debug_wr_data,   // Debug wr cache.
   output logic [41:0]               ifu_ic_debug_rd_data,       // debug data read
`else
   output logic [67:0]               ic_wr_data,         // Data to fill to the Icache. With Parity
   input  logic [135:0]              ic_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With Parity
   input  logic [20:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [33:0]               ic_debug_wr_data,   // Debug wr cache.
   output logic [33:0]               ifu_ic_debug_rd_data,       // debug data read
`endif

   output logic [15:2]               ic_debug_addr,      // Read/Write addresss to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [3:0]                ic_debug_way,       // Debug way. Rd or Wr.


   output logic [3:0]                ic_tag_valid,       // Valid bits when accessing the Icache. One valid bit per way. F2 stage

   input  logic [3:0]                ic_rd_hit,          // Compare hits from Icache tags. Per way.  F2 stage
   input  logic                      ic_tag_perr,        // Icache Tag parity error

`ifdef RV_ICCM_ENABLE
   // ICCM ports
   output logic [`RV_ICCM_BITS-1:2]  iccm_rw_addr,       // ICCM read/write address.
   output logic                      iccm_wren,          // ICCM write enable (through the DMA)
   output logic                      iccm_rden,          // ICCM read enable.
   output logic [63:0]               iccm_wr_data,       // ICCM write data, no ECC.
   output logic [2:0]                iccm_wr_size,       // ICCM write location within DW.

   input  logic [127:0]              iccm_rd_data,       // 128-bit ICCM line, no ECC.
`endif


   // IFU control signals
   output logic                      ic_hit_f2,              // Hit in Icache(if Icache access) or ICCM access( ICCM always has ic_hit_f2)
   output logic                      ic_crit_wd_rdy,         // Critical fetch is ready to be bypassed.
   output logic  [7:0]               ic_access_fault_f2,     // Access fault (bus error or ICCM access in region but out of offset range).
   output logic                      ic_rd_parity_final_err, // This fetch has an tag parity error.
   output logic                      iccm_rd_ecc_single_err, // This fetch has a single ICCM ecc  error.
   output logic  [7:0]               iccm_rd_ecc_double_err, // This fetch has a double ICCM ecc  error.
   output logic                      iccm_dma_sb_error,      // Single Bit ECC error from a DMA access
   output logic [7:0]                ic_fetch_val_f2,        // valid bytes for fetch. To the Aligner.
   output logic [127:0]              ic_data_f2,             // Data read from Icache or ICCM. To the Aligner.
   output icache_err_pkt_t           ic_error_f2 ,           // Parity or ECC bits for the Icache Data
   output logic                      ifu_icache_fetch_f2  ,
   output logic [127:0]              ic_premux_data,         // Premuxed data to be muxed with Icache data
   output logic                      ic_sel_premux_data,     // Select premux data.

/////  Debug
   input  cache_debug_pkt_t          dec_tlu_ic_diag_pkt ,       // Icache/tag debug read/write packet
   input  logic                      dec_tlu_core_ecc_disable,   // disable the ecc checking and flagging
   output logic                      ifu_ic_debug_rd_data_valid, // debug data valid.


   input  logic         scan_mode
   );

`include "global.h"


   // -----------------------------------------------------------------------
   // SocRv cacheless/no-ECC instruction memory path
   // -----------------------------------------------------------------------
   logic       tcm_fetch_req_f2;
   logic       tcm_iccm_access_f2;
   logic       tcm_access_fault_f2;
   logic [2:0] tcm_vaddr_f2;
   logic       tcm_fetch_req_f3;
   logic       tcm_iccm_access_f3;
   logic       tcm_access_fault_f3;
   logic [2:0] tcm_vaddr_f3;
   logic [7:1] tcm_bp_inst_mask_f3;
   logic       tcm_fetch_resp_valid;
   logic       tcm_dma_grant_f1;
   logic       tcm_dma_read_f1;
   logic       tcm_dma_read_f2;
   logic       tcm_dma_upper_f2;
   logic       tcm_dma_read_f3;
   logic       tcm_dma_upper_f3;
   logic [63:0] tcm_dma_read_data;

   rvdff #(6) tcm_fetch_f1_f2_ff (.*,
                                   .clk(active_clk),
                                   .din({ifc_fetch_req_f1, ifc_iccm_access_f1,
                                         ~ifc_iccm_access_f1, fetch_addr_f1[3:1]}),
                                   .dout({tcm_fetch_req_f2, tcm_iccm_access_f2,
                                          tcm_access_fault_f2, tcm_vaddr_f2[2:0]}));

   // ICCM BRAMs use their optional output register.  Carry the complete fetch
   // response token across the same boundary; a flush in either response
   // cycle invalidates the token without delaying the predictor redirect.
   rvdff #(13) tcm_fetch_f2_f3_ff (.*,
                                    .clk(active_clk),
                                    .din({tcm_fetch_req_f2 & ~exu_flush_final,
                                          tcm_iccm_access_f2,
                                          tcm_access_fault_f2,
                                          tcm_vaddr_f2[2:0],
                                          ifu_bp_inst_mask_f2[7:1]}),
                                    .dout({tcm_fetch_req_f3,
                                           tcm_iccm_access_f3,
                                           tcm_access_fault_f3,
                                           tcm_vaddr_f3[2:0],
                                           tcm_bp_inst_mask_f3[7:1]}));

   assign tcm_dma_grant_f1 = dma_iccm_req & ifc_dma_access_ok;
   assign tcm_dma_read_f1  = tcm_dma_grant_f1 & ~dma_mem_write;

   rvdff #(2) tcm_dma_req_f2_ff (.*,
                                  .clk(free_clk),
                                  .din({tcm_dma_read_f1, dma_mem_addr[3]}),
                                  .dout({tcm_dma_read_f2, tcm_dma_upper_f2}));

   rvdff #(2) tcm_dma_req_f3_ff (.*,
                                  .clk(free_clk),
                                  .din({tcm_dma_read_f2, tcm_dma_upper_f2}),
                                  .dout({tcm_dma_read_f3, tcm_dma_upper_f3}));

   assign tcm_dma_read_data[63:0] = tcm_dma_upper_f3 ?
                                      iccm_rd_data[127:64] : iccm_rd_data[63:0];

   rvdff #(65) tcm_dma_response_ff (.*,
                                     .clk(free_clk),
                                     .din({tcm_dma_read_f3, tcm_dma_read_data[63:0]}),
                                     .dout({iccm_dma_rvalid, iccm_dma_rdata[63:0]}));

   assign iccm_rw_addr[`RV_ICCM_BITS-1:2] = tcm_dma_grant_f1 ?
                                               dma_mem_addr[`RV_ICCM_BITS-1:2] :
                                               fetch_addr_f1[`RV_ICCM_BITS-1:2];
   assign iccm_wren         = tcm_dma_grant_f1 & dma_mem_write;
   assign iccm_rden         = tcm_dma_read_f1 |
                              (ifc_fetch_req_f1 & ifc_iccm_access_f1);
   assign iccm_wr_size[2:0] = dma_mem_sz[2:0];
   assign iccm_wr_data[63:0] = dma_mem_wdata[63:0];
   assign iccm_ready        = ifc_dma_access_ok;

   // `ic_hit_f2` is the request-accept indication consumed by IFC/BP; ICCM
   // remains hit-always and must not make the fetch controller wait for the
   // new BRAM response stage.  The separate response-valid token below owns
   // aligner delivery one cycle later.
   assign ic_hit_f2 = 1'b1;
   assign tcm_fetch_resp_valid = tcm_fetch_req_f3 & ~exu_flush_final;
   assign ic_data_f2[127:0] = iccm_rd_data[127:0];
   assign ic_access_fault_f2[7:0] = {8{tcm_fetch_req_f3 &
                                          tcm_access_fault_f3 &
                                          ~exu_flush_final}};

   // Preserve EH1's right-justified fetch-valid convention while removing all
   // cache hit/refill selection.  Each bit represents one 16-bit position in
   // the 128-bit line; Stage B consumes them only in 32-bit pairs.
   assign ic_fetch_val_f2[7] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[7] &
                               ~tcm_vaddr_f3[2] & ~tcm_vaddr_f3[1] & ~tcm_vaddr_f3[0];
   assign ic_fetch_val_f2[6] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[6] &
                               ~tcm_vaddr_f3[2] & ~tcm_vaddr_f3[1];
   assign ic_fetch_val_f2[5] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[5] &
                               ~tcm_vaddr_f3[2] & (~tcm_vaddr_f3[0] | ~tcm_vaddr_f3[1]);
   assign ic_fetch_val_f2[4] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[4] & ~tcm_vaddr_f3[2];
   assign ic_fetch_val_f2[3] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[3] &
                               (~tcm_vaddr_f3[1] & ~tcm_vaddr_f3[0] | ~tcm_vaddr_f3[2]);
   assign ic_fetch_val_f2[2] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[2] &
                               (~tcm_vaddr_f3[1] | ~tcm_vaddr_f3[2]);
   assign ic_fetch_val_f2[1] = tcm_fetch_resp_valid & tcm_bp_inst_mask_f3[1] &
                               (~tcm_vaddr_f3[0] | ~tcm_vaddr_f3[1] | ~tcm_vaddr_f3[2]);
   assign ic_fetch_val_f2[0] = tcm_fetch_resp_valid;

   assign ifu_miss_state_idle = 1'b1;
   assign ifu_ic_mb_empty     = 1'b1;
   assign ic_dma_active       = tcm_dma_grant_f1;
   assign ic_write_stall      = iccm_wren;
   assign ic_crit_wd_rdy      = 1'b0;

   assign ifu_pmu_ic_miss   = 1'b0;
   assign ifu_pmu_ic_hit    = tcm_fetch_req_f3 & tcm_iccm_access_f3 & ~exu_flush_final;
   assign ifu_pmu_bus_error = 1'b0;
   assign ifu_pmu_bus_busy  = 1'b0;
   assign ifu_pmu_bus_trxn  = 1'b0;

   assign ifu_axi_awvalid  = 1'b0;
   assign ifu_axi_awid     = '0;
   assign ifu_axi_awaddr   = '0;
   assign ifu_axi_awregion = '0;
   assign ifu_axi_awlen    = '0;
   assign ifu_axi_awsize   = '0;
   assign ifu_axi_awburst  = '0;
   assign ifu_axi_awlock   = 1'b0;
   assign ifu_axi_awcache  = '0;
   assign ifu_axi_awprot   = '0;
   assign ifu_axi_awqos    = '0;
   assign ifu_axi_wvalid   = 1'b0;
   assign ifu_axi_wdata    = '0;
   assign ifu_axi_wstrb    = '0;
   assign ifu_axi_wlast    = 1'b0;
   assign ifu_axi_bready   = 1'b0;
   assign ifu_axi_arvalid  = 1'b0;
   assign ifu_axi_arid     = '0;
   assign ifu_axi_araddr   = '0;
   assign ifu_axi_arregion = '0;
   assign ifu_axi_arlen    = '0;
   assign ifu_axi_arsize   = '0;
   assign ifu_axi_arburst  = '0;
   assign ifu_axi_arlock   = 1'b0;
   assign ifu_axi_arcache  = '0;
   assign ifu_axi_arprot   = '0;
   assign ifu_axi_arqos    = '0;
   assign ifu_axi_rready   = 1'b0;

   assign ic_rw_addr              = '0;
   assign ic_wr_en                = '0;
   assign ic_rd_en                = 1'b0;
   assign ic_wr_data              = '0;
   assign ic_debug_wr_data        = '0;
   assign ifu_ic_debug_rd_data    = '0;
   assign ic_debug_addr           = '0;
   assign ic_debug_rd_en          = 1'b0;
   assign ic_debug_wr_en          = 1'b0;
   assign ic_debug_tag_array      = 1'b0;
   assign ic_debug_way            = '0;
   assign ic_tag_valid            = '0;
   assign ifu_ic_debug_rd_data_valid = 1'b0;

   assign ic_rd_parity_final_err  = 1'b0;
   assign iccm_rd_ecc_single_err  = 1'b0;
   assign iccm_rd_ecc_double_err  = '0;
   assign iccm_dma_sb_error       = 1'b0;
   assign iccm_dma_ecc_error      = 1'b0;
   assign ic_error_f2             = '0;
   assign ifu_icache_fetch_f2     = 1'b0;
   assign ic_premux_data          = '0;
   assign ic_sel_premux_data      = 1'b0;

endmodule  // ifu_mem_ctl
