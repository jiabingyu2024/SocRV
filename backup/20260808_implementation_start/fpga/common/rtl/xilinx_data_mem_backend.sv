module xilinx_data_mem_backend #(
  parameter int unsigned BYTES = 65_536,
  parameter string MEM_FILE = ""
) (
  input logic clk_i,
  input logic rst_ni,
  mem_native_if.slave mem
);
  generic_spram #(
    .BYTES(BYTES),
    .MEM_FILE(MEM_FILE)
  ) u_inferred_bram (
    .clk_i,
    .rst_ni,
    .mem
  );
endmodule
