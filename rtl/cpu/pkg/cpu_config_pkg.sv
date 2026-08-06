package cpu_config_pkg;
  parameter logic [31:0] CPU_RESET_VECTOR = soc_config_pkg::RESET_VECTOR;
  parameter bit ENABLE_SUPERSCALAR_CORE = 1'b1;
endpackage
