package cpu_types_pkg;
  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instruction;
    logic [4:0]  rd;
    logic [31:0] rd_value;
  } commit_trace_t;
endpackage
