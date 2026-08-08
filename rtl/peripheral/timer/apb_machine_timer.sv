module apb_machine_timer (
  input logic clk_i,
  input logic rst_ni,
  input logic [31:0] paddr_i,
  input logic psel_i,
  input logic penable_i,
  input logic pwrite_i,
  input logic [31:0] pwdata_i,
  input logic [3:0] pstrb_i,
  output logic [31:0] prdata_o,
  output logic pready_o,
  output logic pslverr_o,
  output logic irq_timer_o
);
  import common_types_pkg::apply_wstrb;
  logic [63:0] mtime_q;
  logic [63:0] mtimecmp_q;
  logic [31:0] control_q;
  logic access;

  assign access = psel_i && penable_i;
  assign pready_o = 1'b1;
  assign irq_timer_o = control_q[1] && (mtime_q >= mtimecmp_q);
  assign pslverr_o = access && !(paddr_i[11:0] inside {
      12'h000, 12'h004, 12'h008, 12'h00c, 12'h010});

  always_comb begin
    unique case (paddr_i[11:0])
      12'h000: prdata_o = mtime_q[31:0];
      12'h004: prdata_o = mtime_q[63:32];
      12'h008: prdata_o = mtimecmp_q[31:0];
      12'h00c: prdata_o = mtimecmp_q[63:32];
      12'h010: prdata_o = control_q;
      default: prdata_o = '0;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mtime_q <= '0;
      mtimecmp_q <= '1;
      control_q <= 32'h0000_0001;
    end else begin
      if (control_q[0]) mtime_q <= mtime_q + 64'd1;
      if (access && pwrite_i) begin
        unique case (paddr_i[11:0])
          12'h000: mtime_q[31:0] <= apply_wstrb(
              mtime_q[31:0], pwdata_i, pstrb_i);
          12'h004: mtime_q[63:32] <= apply_wstrb(
              mtime_q[63:32], pwdata_i, pstrb_i);
          12'h008: mtimecmp_q[31:0] <= apply_wstrb(
              mtimecmp_q[31:0], pwdata_i, pstrb_i);
          12'h00c: mtimecmp_q[63:32] <= apply_wstrb(
              mtimecmp_q[63:32], pwdata_i, pstrb_i);
          12'h010: control_q <= apply_wstrb(control_q, pwdata_i, pstrb_i);
          default: begin end
        endcase
      end
    end
  end
endmodule
