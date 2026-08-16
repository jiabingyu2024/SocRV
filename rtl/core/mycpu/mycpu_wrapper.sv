

module mycpu_wrapper
   import mycpu_types::*;
#(
   parameter string ICCM_LANE0_INIT_FILE = "",
   parameter string ICCM_LANE1_INIT_FILE = "",
   parameter string ICCM_LANE2_INIT_FILE = "",
   parameter string ICCM_LANE3_INIT_FILE = "",
   parameter string DCCM_BANK0_INIT_FILE = "",
   parameter string DCCM_BANK1_INIT_FILE = "",
   parameter string DCCM_BANK2_INIT_FILE = "",
   parameter string DCCM_BANK3_INIT_FILE = "",
   parameter string DCCM_BANK4_INIT_FILE = "",
   parameter string DCCM_BANK5_INIT_FILE = "",
   parameter string DCCM_BANK6_INIT_FILE = "",
   parameter string DCCM_BANK7_INIT_FILE = ""
)
(
   input  logic                       clk,
   input  logic                       rst_l,
   input  logic                       timer_int,
   input  logic [8:1]                 extintsrc_req,
   output logic                       lsu_mmio_valid,
   output logic                       lsu_mmio_write,
   output logic [31:0]                lsu_mmio_addr,
   output logic [31:0]                lsu_mmio_wdata,
   output logic [3:0]                 lsu_mmio_wstrb,
   input  logic                       lsu_mmio_ready,
   input  logic [31:0]                lsu_mmio_rdata,
   input  logic                       lsu_mmio_error,
   output logic [63:0]                trace_rv_i_insn_ip,
   output logic [63:0]                trace_rv_i_address_ip,
   output logic [2:0]                 trace_rv_i_valid_ip,
   output logic [2:0]                 trace_rv_i_exception_ip,
   output logic [4:0]                 trace_rv_i_ecause_ip,
   output logic [2:0]                 trace_rv_i_interrupt_ip,
   output logic [31:0]                trace_rv_i_tval_ip
);

`include "core_params.svh"

   logic dbg_rst_l;
   logic [31:1] rst_vec;
   logic nmi_int;
   logic [31:1] nmi_vec;
   logic lsu_bus_clk_en;
   logic ifu_bus_clk_en;
   logic mpc_debug_halt_req;
   logic mpc_debug_run_req;
   logic mpc_reset_run_req;
   logic mpc_debug_halt_ack;
   logic mpc_debug_run_ack;
   logic debug_brkpt_status;
   logic i_cpu_halt_req;
   logic o_cpu_halt_ack;
   logic o_cpu_halt_status;
   logic o_debug_mode_status;
   logic i_cpu_run_req;
   logic o_cpu_run_ack;
   logic scan_mode;
   logic mbist_mode;
   logic [1:0] dec_tlu_perfcnt0;
   logic [1:0] dec_tlu_perfcnt1;
   logic [1:0] dec_tlu_perfcnt2;
   logic [1:0] dec_tlu_perfcnt3;

   assign dbg_rst_l          = rst_l;
   assign rst_vec            = '0;
   assign nmi_int            = 1'b0;
   assign nmi_vec            = '0;
   assign lsu_bus_clk_en     = 1'b1;
   assign ifu_bus_clk_en     = 1'b1;
   assign mpc_debug_halt_req = 1'b0;
   assign mpc_debug_run_req  = 1'b0;
   assign mpc_reset_run_req  = 1'b1;
   assign i_cpu_halt_req     = 1'b0;
   assign i_cpu_run_req      = 1'b0;
   assign scan_mode          = 1'b0;
   assign mbist_mode         = 1'b0;


   logic         dccm_wren;
   logic         dccm_rden;
   logic [DCCM_BITS-1:0]  dccm_wr_addr;
   logic [DCCM_BITS-1:0]  dccm_rd_addr_lo;
   logic [DCCM_BITS-1:0]  dccm_rd_addr_hi;
   logic [DCCM_FDATA_WIDTH-1:0]  dccm_wr_data;

   logic [DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo;
   logic [DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi;

   logic         lsu_freeze_dc3;


   logic [`RV_ICCM_BITS-1:2]    iccm_rw_addr;
   logic           iccm_rden;
   logic [127:0]   iccm_rd_data;

   logic        core_rst_l;
   logic        dccm_clk_override;
   logic        icm_clk_override;
   logic        dec_tlu_core_ecc_disable;


   mycpu_core u_mycpu_core (
          .*
          );


   mycpu_mem #(
        .ICCM_LANE0_INIT_FILE(ICCM_LANE0_INIT_FILE),
        .ICCM_LANE1_INIT_FILE(ICCM_LANE1_INIT_FILE),
        .ICCM_LANE2_INIT_FILE(ICCM_LANE2_INIT_FILE),
        .ICCM_LANE3_INIT_FILE(ICCM_LANE3_INIT_FILE),
        .DCCM_BANK0_INIT_FILE(DCCM_BANK0_INIT_FILE),
        .DCCM_BANK1_INIT_FILE(DCCM_BANK1_INIT_FILE),
        .DCCM_BANK2_INIT_FILE(DCCM_BANK2_INIT_FILE),
        .DCCM_BANK3_INIT_FILE(DCCM_BANK3_INIT_FILE),
        .DCCM_BANK4_INIT_FILE(DCCM_BANK4_INIT_FILE),
        .DCCM_BANK5_INIT_FILE(DCCM_BANK5_INIT_FILE),
        .DCCM_BANK6_INIT_FILE(DCCM_BANK6_INIT_FILE),
        .DCCM_BANK7_INIT_FILE(DCCM_BANK7_INIT_FILE)
        ) u_memory (
        .rst_l(core_rst_l),
        .*
        );

endmodule

