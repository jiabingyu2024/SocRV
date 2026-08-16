

module soc_clock_bridge (
   input  logic        core_clk,
   input  logic        core_rst_n,
   input  logic        core_req_valid,
   input  logic        core_req_write,
   input  logic [31:0] core_req_addr,
   input  logic [31:0] core_req_wdata,
   input  logic [3:0]  core_req_wstrb,
   output logic        core_req_ready,
   output logic [31:0] core_req_rdata,
   output logic        core_req_error,

   input  logic        periph_clk,
   input  logic        periph_rst_n,
   output logic        periph_req_valid,
   output logic        periph_req_write,
   output logic [31:0] periph_req_addr,
   output logic [31:0] periph_req_wdata,
   output logic [3:0]  periph_req_wstrb,
   input  logic        periph_req_ready,
   input  logic [31:0] periph_req_rdata,
   input  logic        periph_req_error
);
   logic        req_toggle_q;
   logic        req_busy_q;
   logic        req_write_q;
   logic [31:0] req_addr_q, req_wdata_q;
   logic [3:0]  req_wstrb_q;
   logic        resp_toggle_q;
   logic [31:0] resp_rdata_q;
   logic        resp_error_q;

   (* ASYNC_REG = "TRUE" *) logic resp_toggle_meta_q, resp_toggle_sync_q;
   logic [31:0] resp_rdata_meta_q, resp_rdata_sync_q;
   logic        resp_error_meta_q, resp_error_sync_q;
   (* ASYNC_REG = "TRUE" *) logic req_toggle_meta_q, req_toggle_sync_q;
   logic        req_seen_q;
   logic        periph_active_q;
   logic        periph_req_write_q;
   logic [31:0] periph_req_addr_q, periph_req_wdata_q;
   logic [3:0]  periph_req_wstrb_q;
   logic [31:0] req_addr_meta_q, req_addr_sync_q;
   logic [31:0] req_wdata_meta_q, req_wdata_sync_q;
   logic [3:0]  req_wstrb_meta_q, req_wstrb_sync_q;
   logic        req_write_meta_q, req_write_sync_q;

   assign core_req_ready  = req_busy_q && (resp_toggle_sync_q == req_toggle_q);
   assign core_req_rdata  = resp_rdata_sync_q;
   assign core_req_error  = resp_error_sync_q;

   assign periph_req_valid = periph_active_q;
   assign periph_req_write = periph_req_write_q;
   assign periph_req_addr  = periph_req_addr_q;
   assign periph_req_wdata = periph_req_wdata_q;
   assign periph_req_wstrb = periph_req_wstrb_q;


   always_ff @(posedge core_clk or negedge core_rst_n) begin
      if (!core_rst_n) begin
         req_toggle_q       <= 1'b0;
         req_busy_q         <= 1'b0;
         req_write_q        <= 1'b0;
         req_addr_q         <= 32'b0;
         req_wdata_q        <= 32'b0;
         req_wstrb_q        <= 4'b0;
         resp_toggle_meta_q <= 1'b0;
         resp_toggle_sync_q <= 1'b0;
         resp_rdata_meta_q  <= 32'b0;
         resp_rdata_sync_q  <= 32'b0;
         resp_error_meta_q  <= 1'b0;
         resp_error_sync_q  <= 1'b0;
      end else begin
         resp_toggle_meta_q <= resp_toggle_q;
         resp_toggle_sync_q <= resp_toggle_meta_q;
         resp_rdata_meta_q  <= resp_rdata_q;
         resp_rdata_sync_q  <= resp_rdata_meta_q;
         resp_error_meta_q  <= resp_error_q;
         resp_error_sync_q  <= resp_error_meta_q;

         if (!req_busy_q && core_req_valid) begin
            req_write_q  <= core_req_write;
            req_addr_q   <= core_req_addr;
            req_wdata_q  <= core_req_wdata;
            req_wstrb_q  <= core_req_wstrb;
            req_toggle_q <= ~req_toggle_q;
            req_busy_q   <= 1'b1;
         end else if (req_busy_q && core_req_ready && core_req_valid) begin
            req_busy_q <= 1'b0;
         end
      end
   end


   always_ff @(posedge periph_clk or negedge periph_rst_n) begin
      if (!periph_rst_n) begin
         req_toggle_meta_q  <= 1'b0;
         req_toggle_sync_q  <= 1'b0;
         req_seen_q         <= 1'b0;
         req_addr_meta_q    <= 32'b0;
         req_addr_sync_q    <= 32'b0;
         req_wdata_meta_q   <= 32'b0;
         req_wdata_sync_q   <= 32'b0;
         req_wstrb_meta_q   <= 4'b0;
         req_wstrb_sync_q   <= 4'b0;
         req_write_meta_q   <= 1'b0;
         req_write_sync_q   <= 1'b0;
         periph_active_q    <= 1'b0;
         periph_req_write_q <= 1'b0;
         periph_req_addr_q  <= 32'b0;
         periph_req_wdata_q <= 32'b0;
         periph_req_wstrb_q <= 4'b0;
         resp_toggle_q      <= 1'b0;
         resp_rdata_q       <= 32'b0;
         resp_error_q       <= 1'b0;
      end else begin
         req_toggle_meta_q <= req_toggle_q;
         req_toggle_sync_q <= req_toggle_meta_q;
         req_addr_meta_q   <= req_addr_q;
         req_addr_sync_q   <= req_addr_meta_q;
         req_wdata_meta_q  <= req_wdata_q;
         req_wdata_sync_q  <= req_wdata_meta_q;
         req_wstrb_meta_q  <= req_wstrb_q;
         req_wstrb_sync_q  <= req_wstrb_meta_q;
         req_write_meta_q  <= req_write_q;
         req_write_sync_q  <= req_write_meta_q;

         if (!periph_active_q && req_toggle_sync_q != req_seen_q) begin
            periph_req_write_q <= req_write_sync_q;
            periph_req_addr_q  <= req_addr_sync_q;
            periph_req_wdata_q <= req_wdata_sync_q;
            periph_req_wstrb_q <= req_wstrb_sync_q;
            periph_active_q    <= 1'b1;
         end else if (periph_active_q && periph_req_ready) begin
            resp_rdata_q    <= periph_req_rdata;
            resp_error_q    <= periph_req_error;
            resp_toggle_q   <= req_toggle_sync_q;
            req_seen_q      <= req_toggle_sync_q;
            periph_active_q <= 1'b0;
         end
      end
   end
endmodule
