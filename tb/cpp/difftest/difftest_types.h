#ifndef SOCRV_TB_DIFFTEST_TYPES_H
#define SOCRV_TB_DIFFTEST_TYPES_H

#include <cstdint>
#include <string>
#include <vector>

struct ArchEvent {
    bool valid = false;
    bool retired = false;
    std::uint64_t order = 0;
    std::uint32_t pc_rdata = 0;
    std::uint32_t pc_wdata = 0;
    std::uint32_t instruction = 0;
    std::uint32_t rs1_addr = 0;
    std::uint32_t rs1_rdata = 0;
    std::uint32_t rs2_addr = 0;
    std::uint32_t rs2_rdata = 0;
    bool rd_wen = false;
    std::uint32_t rd_addr = 0;
    std::uint32_t rd_wdata = 0;
    bool sync_trap = false;
    std::uint32_t cause = 0;
    std::uint32_t tval = 0;
    std::uint32_t mode = 3;
    bool mem_valid = false;
    std::uint32_t mem_addr = 0;
    std::uint32_t mem_rmask = 0;
    std::uint32_t mem_wmask = 0;
    std::uint32_t mem_rdata = 0;
    std::uint32_t mem_wdata = 0;
    std::uint32_t csr_mstatus = 0;
    std::uint32_t csr_mie = 0;
    std::uint32_t csr_mip = 0;
    std::uint32_t csr_mtvec = 0;
    std::uint32_t csr_mscratch = 0;
    std::uint32_t csr_mepc = 0;
    std::uint32_t csr_mcause = 0;
    std::uint32_t csr_mtval = 0;
    std::uint64_t csr_mcycle = 0;
    std::uint64_t csr_minstret = 0;
};

struct IrqEvent {
    bool valid = false;
    std::uint64_t next_order = 0;
    std::uint32_t mip_pre = 0;
    std::uint32_t mip_post = 0;
};

struct DiffMemoryRegion {
    std::string name;
    std::uint32_t base = 0;
    std::uint32_t size = 0;
    bool mmio = false;
    std::string image_path;
};

struct ReferenceStepOutcome {
    bool passed = true;
    std::string kind;
    std::string message;
    std::uint32_t reference_pc = 0;
    std::uint32_t reference_value = 0;
    std::uint64_t mmio_syncs = 0;
};

struct DiffTestSnapshot {
    bool enabled = false;
    bool passed = true;
    std::string backend = "none";
    std::string backend_version;
    std::string mode;
    std::string isa;
    std::uint64_t compared_events = 0;
    std::uint64_t retired_instructions = 0;
    std::uint64_t mmio_syncs = 0;
    std::uint64_t last_order = 0;
    bool has_last_order = false;
    std::uint64_t failure_cycle = 0;
    std::uint64_t failure_order = 0;
    std::string failure_kind;
    std::string failure_message;
    std::string log_path;
    std::string trace_path;
};

#endif
