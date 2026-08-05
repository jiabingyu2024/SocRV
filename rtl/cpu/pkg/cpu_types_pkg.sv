package cpu_types_pkg;
  typedef struct packed {
    logic        valid;
    logic        retired;
    logic [63:0] order;
    logic [31:0] pc_rdata;
    logic [31:0] pc_wdata;
    logic [31:0] instruction;
    logic [4:0]  rs1_addr;
    logic [31:0] rs1_rdata;
    logic [4:0]  rs2_addr;
    logic [31:0] rs2_rdata;
    logic        rd_wen;
    logic [4:0]  rd_addr;
    logic [31:0] rd_wdata;
    logic        sync_trap;
    logic [31:0] cause;
    logic [31:0] tval;
    logic [1:0]  mode;
    logic        mem_valid;
    logic [31:0] mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic [31:0] mem_wdata;

    // CSR values are the architectural state immediately before this event.
    logic [31:0] csr_mstatus;
    logic [31:0] csr_mie;
    logic [31:0] csr_mip;
    logic [31:0] csr_mtvec;
    logic [31:0] csr_mscratch;
    logic [31:0] csr_mepc;
    logic [31:0] csr_mcause;
    logic [31:0] csr_mtval;
    logic [63:0] csr_mcycle;
    logic [63:0] csr_minstret;

    // Asynchronous interrupt notifications are ordered before irq_next_order.
    logic        irq_valid;
    logic [63:0] irq_next_order;
    logic [31:0] irq_mip_pre;
    logic [31:0] irq_mip_post;
  } commit_trace_t;
endpackage
