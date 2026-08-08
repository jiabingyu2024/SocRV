//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.6.0
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module biriscv_dcache
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input  [ 31:0]  mem_addr_i
    ,input  [ 31:0]  mem_data_wr_i
    ,input           mem_rd_i
    ,input  [  3:0]  mem_wr_i
    ,input           mem_cacheable_i
    ,input  [ 10:0]  mem_req_tag_i
    ,input           mem_invalidate_i
    ,input           mem_writeback_i
    ,input           mem_flush_i
    ,input           hxi_req_ready_i
    ,input           hxi_rsp_valid_i
    ,input  [ 31:0]  hxi_rsp_rdata_i
    ,input           hxi_rsp_err_i

    // Outputs
    ,output [ 31:0]  mem_data_rd_o
    ,output          mem_accept_o
    ,output          mem_ack_o
    ,output          mem_error_o
    ,output [ 10:0]  mem_resp_tag_o
    ,output          hxi_req_valid_o
    ,output [ 31:0]  hxi_req_addr_o
    ,output          hxi_req_write_o
    ,output [ 31:0]  hxi_req_wdata_o
    ,output [  3:0]  hxi_req_wstrb_o
    ,output          hxi_rsp_ready_o
);

wire           mem_uncached_invalidate_w;
wire           pmem_cache_accept_w;
wire           mem_uncached_accept_w;
wire  [  7:0]  pmem_cache_len_w;
wire  [  3:0]  mem_cached_wr_w;
wire  [ 31:0]  pmem_cache_read_data_w;
wire           mem_cached_invalidate_w;
wire           pmem_uncached_ack_w;
wire  [  7:0]  pmem_len_w;
wire           pmem_uncached_accept_w;
wire           mem_cached_accept_w;
wire           pmem_cache_ack_w;
wire  [ 31:0]  pmem_cache_addr_w;
wire           pmem_cache_rd_w;
wire           pmem_error_w;
wire  [ 31:0]  pmem_addr_w;
wire  [ 10:0]  mem_cached_req_tag_w;
wire           mem_uncached_ack_w;
wire           pmem_ack_w;
wire  [ 31:0]  mem_uncached_data_wr_w;
wire  [ 31:0]  pmem_uncached_addr_w;
wire  [ 31:0]  mem_cached_data_rd_w;
wire  [ 31:0]  pmem_uncached_read_data_w;
wire           mem_uncached_flush_w;
wire           pmem_uncached_error_w;
wire  [ 31:0]  mem_uncached_data_rd_w;
wire  [ 31:0]  pmem_write_data_w;
wire  [  3:0]  pmem_uncached_wr_w;
wire           mem_cached_rd_w;
wire  [ 10:0]  mem_cached_resp_tag_w;
wire  [  7:0]  pmem_uncached_len_w;
wire  [ 31:0]  mem_cached_data_wr_w;
wire  [  3:0]  pmem_wr_w;
wire           pmem_select_w;
wire           mem_cached_flush_w;
wire           mem_uncached_cacheable_w;
wire  [ 31:0]  mem_cached_addr_w;
wire           mem_uncached_writeback_w;
wire  [  3:0]  pmem_cache_wr_w;
wire           pmem_cache_error_w;
wire  [ 10:0]  mem_uncached_req_tag_w;
wire  [ 31:0]  pmem_uncached_write_data_w;
wire  [ 10:0]  mem_uncached_resp_tag_w;
wire           pmem_rd_w;
wire           mem_cached_cacheable_w;
wire  [  3:0]  mem_uncached_wr_w;
wire           mem_uncached_error_w;
wire           mem_uncached_rd_w;
wire           pmem_accept_w;
wire  [ 31:0]  pmem_cache_write_data_w;
wire           mem_cached_error_w;
wire  [ 31:0]  mem_uncached_addr_w;
wire           pmem_uncached_rd_w;
wire  [ 31:0]  pmem_read_data_w;
wire           mem_cached_ack_w;
wire           mem_cached_writeback_w;


dcache_if_pmem
u_uncached
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.mem_addr_i(mem_uncached_addr_w)
    ,.mem_data_wr_i(mem_uncached_data_wr_w)
    ,.mem_rd_i(mem_uncached_rd_w)
    ,.mem_wr_i(mem_uncached_wr_w)
    ,.mem_cacheable_i(mem_uncached_cacheable_w)
    ,.mem_req_tag_i(mem_uncached_req_tag_w)
    ,.mem_invalidate_i(mem_uncached_invalidate_w)
    ,.mem_writeback_i(mem_uncached_writeback_w)
    ,.mem_flush_i(mem_uncached_flush_w)
    ,.outport_accept_i(pmem_uncached_accept_w)
    ,.outport_ack_i(pmem_uncached_ack_w)
    ,.outport_error_i(pmem_uncached_error_w)
    ,.outport_read_data_i(pmem_uncached_read_data_w)

    // Outputs
    ,.mem_data_rd_o(mem_uncached_data_rd_w)
    ,.mem_accept_o(mem_uncached_accept_w)
    ,.mem_ack_o(mem_uncached_ack_w)
    ,.mem_error_o(mem_uncached_error_w)
    ,.mem_resp_tag_o(mem_uncached_resp_tag_w)
    ,.outport_wr_o(pmem_uncached_wr_w)
    ,.outport_rd_o(pmem_uncached_rd_w)
    ,.outport_len_o(pmem_uncached_len_w)
    ,.outport_addr_o(pmem_uncached_addr_w)
    ,.outport_write_data_o(pmem_uncached_write_data_w)
);


dcache_pmem_mux
u_pmem_mux
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.outport_accept_i(pmem_accept_w)
    ,.outport_ack_i(pmem_ack_w)
    ,.outport_error_i(pmem_error_w)
    ,.outport_read_data_i(pmem_read_data_w)
    ,.select_i(pmem_select_w)
    ,.inport0_wr_i(pmem_uncached_wr_w)
    ,.inport0_rd_i(pmem_uncached_rd_w)
    ,.inport0_len_i(pmem_uncached_len_w)
    ,.inport0_addr_i(pmem_uncached_addr_w)
    ,.inport0_write_data_i(pmem_uncached_write_data_w)
    ,.inport1_wr_i(pmem_cache_wr_w)
    ,.inport1_rd_i(pmem_cache_rd_w)
    ,.inport1_len_i(pmem_cache_len_w)
    ,.inport1_addr_i(pmem_cache_addr_w)
    ,.inport1_write_data_i(pmem_cache_write_data_w)

    // Outputs
    ,.outport_wr_o(pmem_wr_w)
    ,.outport_rd_o(pmem_rd_w)
    ,.outport_len_o(pmem_len_w)
    ,.outport_addr_o(pmem_addr_w)
    ,.outport_write_data_o(pmem_write_data_w)
    ,.inport0_accept_o(pmem_uncached_accept_w)
    ,.inport0_ack_o(pmem_uncached_ack_w)
    ,.inport0_error_o(pmem_uncached_error_w)
    ,.inport0_read_data_o(pmem_uncached_read_data_w)
    ,.inport1_accept_o(pmem_cache_accept_w)
    ,.inport1_ack_o(pmem_cache_ack_w)
    ,.inport1_error_o(pmem_cache_error_w)
    ,.inport1_read_data_o(pmem_cache_read_data_w)
);


dcache_mux
u_mux
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.mem_addr_i(mem_addr_i)
    ,.mem_data_wr_i(mem_data_wr_i)
    ,.mem_rd_i(mem_rd_i)
    ,.mem_wr_i(mem_wr_i)
    ,.mem_cacheable_i(mem_cacheable_i)
    ,.mem_req_tag_i(mem_req_tag_i)
    ,.mem_invalidate_i(mem_invalidate_i)
    ,.mem_writeback_i(mem_writeback_i)
    ,.mem_flush_i(mem_flush_i)
    ,.mem_cached_data_rd_i(mem_cached_data_rd_w)
    ,.mem_cached_accept_i(mem_cached_accept_w)
    ,.mem_cached_ack_i(mem_cached_ack_w)
    ,.mem_cached_error_i(mem_cached_error_w)
    ,.mem_cached_resp_tag_i(mem_cached_resp_tag_w)
    ,.mem_uncached_data_rd_i(mem_uncached_data_rd_w)
    ,.mem_uncached_accept_i(mem_uncached_accept_w)
    ,.mem_uncached_ack_i(mem_uncached_ack_w)
    ,.mem_uncached_error_i(mem_uncached_error_w)
    ,.mem_uncached_resp_tag_i(mem_uncached_resp_tag_w)

    // Outputs
    ,.mem_data_rd_o(mem_data_rd_o)
    ,.mem_accept_o(mem_accept_o)
    ,.mem_ack_o(mem_ack_o)
    ,.mem_error_o(mem_error_o)
    ,.mem_resp_tag_o(mem_resp_tag_o)
    ,.mem_cached_addr_o(mem_cached_addr_w)
    ,.mem_cached_data_wr_o(mem_cached_data_wr_w)
    ,.mem_cached_rd_o(mem_cached_rd_w)
    ,.mem_cached_wr_o(mem_cached_wr_w)
    ,.mem_cached_cacheable_o(mem_cached_cacheable_w)
    ,.mem_cached_req_tag_o(mem_cached_req_tag_w)
    ,.mem_cached_invalidate_o(mem_cached_invalidate_w)
    ,.mem_cached_writeback_o(mem_cached_writeback_w)
    ,.mem_cached_flush_o(mem_cached_flush_w)
    ,.mem_uncached_addr_o(mem_uncached_addr_w)
    ,.mem_uncached_data_wr_o(mem_uncached_data_wr_w)
    ,.mem_uncached_rd_o(mem_uncached_rd_w)
    ,.mem_uncached_wr_o(mem_uncached_wr_w)
    ,.mem_uncached_cacheable_o(mem_uncached_cacheable_w)
    ,.mem_uncached_req_tag_o(mem_uncached_req_tag_w)
    ,.mem_uncached_invalidate_o(mem_uncached_invalidate_w)
    ,.mem_uncached_writeback_o(mem_uncached_writeback_w)
    ,.mem_uncached_flush_o(mem_uncached_flush_w)
    ,.cache_active_o(pmem_select_w)
);


dcache_core
u_core
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.mem_addr_i(mem_cached_addr_w)
    ,.mem_data_wr_i(mem_cached_data_wr_w)
    ,.mem_rd_i(mem_cached_rd_w)
    ,.mem_wr_i(mem_cached_wr_w)
    ,.mem_cacheable_i(mem_cached_cacheable_w)
    ,.mem_req_tag_i(mem_cached_req_tag_w)
    ,.mem_invalidate_i(mem_cached_invalidate_w)
    ,.mem_writeback_i(mem_cached_writeback_w)
    ,.mem_flush_i(mem_cached_flush_w)
    ,.outport_accept_i(pmem_cache_accept_w)
    ,.outport_ack_i(pmem_cache_ack_w)
    ,.outport_error_i(pmem_cache_error_w)
    ,.outport_read_data_i(pmem_cache_read_data_w)

    // Outputs
    ,.mem_data_rd_o(mem_cached_data_rd_w)
    ,.mem_accept_o(mem_cached_accept_w)
    ,.mem_ack_o(mem_cached_ack_w)
    ,.mem_error_o(mem_cached_error_w)
    ,.mem_resp_tag_o(mem_cached_resp_tag_w)
    ,.outport_wr_o(pmem_cache_wr_w)
    ,.outport_rd_o(pmem_cache_rd_w)
    ,.outport_len_o(pmem_cache_len_w)
    ,.outport_addr_o(pmem_cache_addr_w)
    ,.outport_write_data_o(pmem_cache_write_data_w)
);


dcache_hxi
u_hxi
(
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.inport_wr_i(pmem_wr_w)
    ,.inport_rd_i(pmem_rd_w)
    ,.inport_len_i(pmem_len_w)
    ,.inport_addr_i(pmem_addr_w)
    ,.inport_write_data_i(pmem_write_data_w)

    // Outputs
    ,.inport_accept_o(pmem_accept_w)
    ,.inport_ack_o(pmem_ack_w)
    ,.inport_error_o(pmem_error_w)
    ,.inport_read_data_o(pmem_read_data_w)
    ,.hxi_req_valid_o(hxi_req_valid_o)
    ,.hxi_req_ready_i(hxi_req_ready_i)
    ,.hxi_req_addr_o(hxi_req_addr_o)
    ,.hxi_req_write_o(hxi_req_write_o)
    ,.hxi_req_wdata_o(hxi_req_wdata_o)
    ,.hxi_req_wstrb_o(hxi_req_wstrb_o)
    ,.hxi_rsp_valid_i(hxi_rsp_valid_i)
    ,.hxi_rsp_ready_o(hxi_rsp_ready_o)
    ,.hxi_rsp_rdata_i(hxi_rsp_rdata_i)
    ,.hxi_rsp_err_i(hxi_rsp_err_i)
);



endmodule
