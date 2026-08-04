module memory_subsystem (
  hxi_if.slave code_hxi,
  hxi_if.slave data_hxi,
  mem_native_if.master code_mem,
  mem_native_if.master data_mem
);
  hxi_code_mem_slave u_code_adapter (
    .hxi(code_hxi),
    .mem(code_mem)
  );

  hxi_data_mem_slave u_data_adapter (
    .hxi(data_hxi),
    .mem(data_mem)
  );
endmodule
