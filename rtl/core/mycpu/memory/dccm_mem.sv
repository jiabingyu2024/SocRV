

module dccm_mem
   import mycpu_types::*;
#(
   parameter string BANK0_INIT_FILE = "",
   parameter string BANK1_INIT_FILE = "",
   parameter string BANK2_INIT_FILE = "",
   parameter string BANK3_INIT_FILE = "",
   parameter string BANK4_INIT_FILE = "",
   parameter string BANK5_INIT_FILE = "",
   parameter string BANK6_INIT_FILE = "",
   parameter string BANK7_INIT_FILE = ""
)
(
   input  logic                              clk,
   input  logic                              free_clk,
   input  logic                              rst_l,
   input  logic                              lsu_freeze_dc3,
   input  logic                              clk_override,
   input  logic                              dccm_wren,
   input  logic                              dccm_rden,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_wr_addr,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_lo,
   input  logic [`RV_DCCM_BITS-1:0]          dccm_rd_addr_hi,
   input  logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_wr_data,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_rd_data_lo,
   output logic [`RV_DCCM_DATA_WIDTH-1:0]    dccm_rd_data_hi,
   input  logic                              scan_mode
);

   localparam int BANK_BITS  = `RV_DCCM_BANK_BITS;
   localparam int BANK_COUNT = `RV_DCCM_NUM_BANKS;
   localparam int ROW_BITS   = `RV_DCCM_INDEX_BITS;
   localparam int ROW_COUNT  = `RV_DCCM_ROWS;

   logic [BANK_BITS-1:0] rd_bank_lo_q, rd_bank_hi_q;
   logic [31:0] bank_dout [0:BANK_COUNT-1];

   for (genvar bank = 0; bank < BANK_COUNT; bank++) begin: dccm_bank_gen
      localparam string INIT_FILE =
         bank == 0 ? BANK0_INIT_FILE : bank == 1 ? BANK1_INIT_FILE :
         bank == 2 ? BANK2_INIT_FILE : bank == 3 ? BANK3_INIT_FILE :
         bank == 4 ? BANK4_INIT_FILE : bank == 5 ? BANK5_INIT_FILE :
         bank == 6 ? BANK6_INIT_FILE : BANK7_INIT_FILE;
      localparam string PLUSARG_FORMAT =
         bank == 0 ? "dccm_bank0=%s" : bank == 1 ? "dccm_bank1=%s" :
         bank == 2 ? "dccm_bank2=%s" : bank == 3 ? "dccm_bank3=%s" :
         bank == 4 ? "dccm_bank4=%s" : bank == 5 ? "dccm_bank5=%s" :
         bank == 6 ? "dccm_bank6=%s" : "dccm_bank7=%s";
      (* ram_style = "block" *) logic [31:0] bank_mem [0:ROW_COUNT-1];
      logic [ROW_BITS-1:0] read_row;
      logic                 bank_read;
      logic                 bank_write;
`ifndef SYNTHESIS
      string runtime_init_file;
`endif

      initial begin
`ifndef SYNTHESIS
         if ($value$plusargs(PLUSARG_FORMAT, runtime_init_file))
            $readmemh(runtime_init_file, bank_mem);
         else
`endif
         if (INIT_FILE != "") $readmemh(INIT_FILE, bank_mem);
      end

      assign bank_read = dccm_rden &
                         ((dccm_rd_addr_lo[2+:BANK_BITS] == bank[BANK_BITS-1:0]) |
                          (dccm_rd_addr_hi[2+:BANK_BITS] == bank[BANK_BITS-1:0]));
      assign bank_write = dccm_wren &
                          (dccm_wr_addr[2+:BANK_BITS] == bank[BANK_BITS-1:0]);


      assign read_row = ((dccm_rd_addr_hi[2+:BANK_BITS] == bank[BANK_BITS-1:0]) &
                         (dccm_rd_addr_hi[2+:BANK_BITS] != dccm_rd_addr_lo[2+:BANK_BITS])) ?
                           dccm_rd_addr_hi[(BANK_BITS+2)+:ROW_BITS] :
                           dccm_rd_addr_lo[(BANK_BITS+2)+:ROW_BITS];

      always_ff @(posedge clk) begin
         if (!lsu_freeze_dc3) begin
            if (bank_read)
               bank_dout[bank] <= bank_mem[read_row];
            if (bank_write)
               bank_mem[dccm_wr_addr[(BANK_BITS+2)+:ROW_BITS]] <= dccm_wr_data[31:0];
         end
      end
   end

   always_ff @(posedge clk) begin
      if (!lsu_freeze_dc3 && dccm_rden) begin
         rd_bank_lo_q <= dccm_rd_addr_lo[2+:BANK_BITS];
         rd_bank_hi_q <= dccm_rd_addr_hi[2+:BANK_BITS];
      end
   end

   assign dccm_rd_data_lo[31:0] = bank_dout[rd_bank_lo_q];
   assign dccm_rd_data_hi[31:0] = bank_dout[rd_bank_hi_q];


endmodule
