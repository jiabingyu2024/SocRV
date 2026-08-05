#include "reference_model.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>

#ifdef SOCRV_ENABLE_SPIKE

#include "cosim.h"
#include "spike_cosim.h"

namespace {

constexpr int kCsrMstatus = 0x300;
constexpr int kCsrMie = 0x304;
constexpr int kCsrMtvec = 0x305;
constexpr int kCsrMscratch = 0x340;
constexpr int kCsrMepc = 0x341;
constexpr int kCsrMcause = 0x342;
constexpr int kCsrMtval = 0x343;
constexpr int kCsrMip = 0x344;
constexpr int kCsrMinstret = 0xb02;
constexpr int kCsrMinstreth = 0xb82;
constexpr std::uint32_t kMachineInterruptMask = 0x00000888u;
constexpr std::uint32_t kMstatusMask = 0x00001888u;
constexpr std::uint32_t kPrivilegeMachine = 3u;

std::string hex32(std::uint32_t value) {
    std::ostringstream output;
    output << "0x" << std::hex << std::setw(8) << std::setfill('0') << value;
    return output.str();
}

std::string normalize_isa(std::string isa) {
    std::transform(
        isa.begin(),
        isa.end(),
        isa.begin(),
        [](unsigned char character) {
            return static_cast<char>(std::tolower(character));
        });
    return isa;
}

std::string classify_error(const std::string& message) {
    std::string lower = message;
    std::transform(
        lower.begin(),
        lower.end(),
        lower.begin(),
        [](unsigned char character) {
            return static_cast<char>(std::tolower(character));
        });
    if (lower.find("memory") != std::string::npos ||
        lower.find("load") != std::string::npos ||
        lower.find("store") != std::string::npos) {
        return "MEM";
    }
    if (lower.find("register") != std::string::npos ||
        lower.find("gpr") != std::string::npos) {
        return "GPR";
    }
    if (lower.find("trap") != std::string::npos ||
        lower.find("exception") != std::string::npos) {
        return "TRAP";
    }
    if (lower.find("pc") != std::string::npos) {
        return "PC";
    }
    return "REFERENCE_ERROR";
}

std::int32_t sign_extend_12(std::uint32_t value) {
    return static_cast<std::int32_t>(value << 20) >> 20;
}

bool validate_dut_misaligned_trap(
    const ArchEvent& event,
    std::string& error) {
    const std::uint32_t opcode = event.instruction & 0x7fu;
    const std::uint32_t funct3 = (event.instruction >> 12) & 7u;
    std::uint32_t address = 0;
    std::uint32_t required_alignment = 1;
    std::uint32_t expected_cause = 0;

    if (opcode == 0x03u) {
        address = event.rs1_rdata + static_cast<std::uint32_t>(
            sign_extend_12(event.instruction >> 20));
        expected_cause = 4;
        if (funct3 == 1u || funct3 == 5u) {
            required_alignment = 2;
        } else if (funct3 == 2u) {
            required_alignment = 4;
        } else {
            error = "load-misaligned trap reported for a byte/invalid load";
            return false;
        }
    } else if (opcode == 0x23u) {
        const std::uint32_t immediate =
            ((event.instruction >> 25) << 5) |
            ((event.instruction >> 7) & 0x1fu);
        address = event.rs1_rdata + static_cast<std::uint32_t>(
            sign_extend_12(immediate));
        expected_cause = 6;
        if (funct3 == 1u) {
            required_alignment = 2;
        } else if (funct3 == 2u) {
            required_alignment = 4;
        } else {
            error = "store-misaligned trap reported for a byte/invalid store";
            return false;
        }
    } else {
        error = "misaligned data trap reported by a non-memory instruction";
        return false;
    }

    if (event.cause != expected_cause) {
        error = "misaligned trap cause mismatch: DUT=" +
            std::to_string(event.cause) +
            " expected=" + std::to_string(expected_cause);
        return false;
    }
    if ((address & (required_alignment - 1u)) == 0) {
        error = "misaligned trap reported for aligned address " +
            hex32(address);
        return false;
    }
    if (event.tval != address) {
        error = "misaligned trap tval mismatch: DUT=" +
            hex32(event.tval) + " expected=" + hex32(address);
        return false;
    }
    return true;
}

class SpikeReferenceModel final : public ReferenceModel {
public:
    explicit SpikeReferenceModel(const ReferenceConfig& config)
        : config_(config),
          spike_(std::make_unique<SpikeCosim>(
              normalize_isa(config.isa),
              config.reset_pc,
              config.reset_mtvec,
              config.reference_trace_path,
              false,
              false)) {
        for (const DiffMemoryRegion& region : config.regions) {
            if (region.size == 0) {
                throw std::runtime_error(
                    "DiffTest memory region has zero size: " + region.name);
            }
            spike_->add_memory(region.base, region.size);
            if (!region.image_path.empty()) {
                load_word_image(region);
            }
        }
    }

    void notify_irq(const IrqEvent& event) override {
        spike_->set_mip(event.mip_pre);
        irq_notification_pending_ = true;
    }

    ReferenceStepOutcome step(const ArchEvent& event) override {
        ReferenceStepOutcome outcome;
        outcome.mmio_syncs = mmio_syncs_;
        const bool entering_irq = irq_notification_pending_;
        if (!entering_irq && !compare_pre_state(event, outcome)) {
            return outcome;
        }
        irq_notification_pending_ = false;
        spike_->set_mcycle(event.csr_mcycle);

        std::array<std::uint8_t, 4> instruction_bytes{};
        if (!spike_->backdoor_read_mem(
                event.pc_rdata,
                instruction_bytes.size(),
                instruction_bytes.data())) {
            return failure(
                "INSN",
                "reference cannot read instruction at " +
                    hex32(event.pc_rdata));
        }
        const std::uint32_t reference_instruction =
            static_cast<std::uint32_t>(instruction_bytes[0]) |
            (static_cast<std::uint32_t>(instruction_bytes[1]) << 8) |
            (static_cast<std::uint32_t>(instruction_bytes[2]) << 16) |
            (static_cast<std::uint32_t>(instruction_bytes[3]) << 24);
        if (reference_instruction != event.instruction) {
            return failure(
                "INSN",
                "instruction mismatch at " + hex32(event.pc_rdata) +
                    ": DUT=" + hex32(event.instruction) +
                    " REF=" + hex32(reference_instruction),
                event.pc_rdata,
                reference_instruction);
        }

        // The pinned Spike build deliberately supports unaligned accesses,
        // while an RV32 implementation is also allowed to raise the standard
        // load/store address-misaligned exceptions.  Validate that the DUT
        // event is a real alignment fault, then apply the architecturally
        // specified trap transition to the reference state.  This keeps
        // --enable-misaligned available for cores that execute the access,
        // without trusting an arbitrary DUT trap.
        if (event.sync_trap && (event.cause == 4u || event.cause == 6u)) {
            std::string validation_error;
            if (!validate_dut_misaligned_trap(event, validation_error)) {
                return failure("TRAP", validation_error, event.pc_rdata);
            }
            std::uint32_t trap_mstatus = event.csr_mstatus;
            trap_mstatus &= ~0x00001888u;
            trap_mstatus |= (event.mode & 3u) << 11;
            trap_mstatus |=
                ((event.csr_mstatus >> 3) & 1u) << 7;
            spike_->force_csr_value(kCsrMstatus, trap_mstatus);
            spike_->force_csr_value(kCsrMepc, event.pc_rdata);
            spike_->force_csr_value(kCsrMcause, event.cause);
            spike_->force_csr_value(kCsrMtval, event.tval);
            spike_->force_privilege(kPrivilegeMachine);
            const std::uint32_t trap_pc = event.csr_mtvec & ~3u;
            spike_->force_pc(trap_pc);
            if (trap_pc != event.pc_wdata) {
                return failure(
                    "NEXT_PC",
                    "misaligned trap target mismatch: DUT=" +
                        hex32(event.pc_wdata) +
                        " expected=" + hex32(trap_pc),
                    trap_pc);
            }
            spike_->set_mip(event.csr_mip);
            outcome.mmio_syncs = mmio_syncs_;
            return outcome;
        }

        std::uint32_t trigger_address = 0;
        if (trigger_match(event, trigger_address)) {
            if (!event.sync_trap || event.cause != 3u) {
                return failure(
                    "TRAP",
                    "configured address trigger did not produce a "
                    "breakpoint trap at " + hex32(trigger_address),
                    event.pc_rdata);
            }
            if (event.tval != trigger_address) {
                return failure(
                    "TRAP",
                    "breakpoint tval mismatch: DUT=" +
                        hex32(event.tval) +
                        " expected=" + hex32(trigger_address),
                    event.pc_rdata,
                    trigger_address);
            }
            std::uint32_t trap_mstatus = event.csr_mstatus;
            trap_mstatus &= ~0x00001888u;
            trap_mstatus |= (event.mode & 3u) << 11;
            trap_mstatus |=
                ((event.csr_mstatus >> 3) & 1u) << 7;
            spike_->force_csr_value(kCsrMstatus, trap_mstatus);
            spike_->force_csr_value(kCsrMepc, event.pc_rdata);
            spike_->force_csr_value(kCsrMcause, 3u);
            spike_->force_csr_value(kCsrMtval, trigger_address);
            spike_->force_privilege(kPrivilegeMachine);
            const std::uint32_t trap_pc = event.csr_mtvec & ~3u;
            spike_->force_pc(trap_pc);
            if (trap_pc != event.pc_wdata) {
                return failure(
                    "NEXT_PC",
                    "breakpoint trap target mismatch: DUT=" +
                        hex32(event.pc_wdata) +
                        " expected=" + hex32(trap_pc),
                    trap_pc);
            }
            spike_->set_mip(event.csr_mip);
            outcome.mmio_syncs = mmio_syncs_;
            return outcome;
        }

        if (event.mem_valid) {
            const bool store = event.mem_wmask != 0;
            const std::uint32_t aligned_address = event.mem_addr & ~3u;
            const std::uint32_t byte_enable =
                store ? event.mem_wmask : event.mem_rmask;
            const std::uint32_t data =
                store ? event.mem_wdata : event.mem_rdata;
            if (is_mmio(event.mem_addr)) {
                if (!store) {
                    std::array<std::uint8_t, 4> bytes{
                        static_cast<std::uint8_t>(data),
                        static_cast<std::uint8_t>(data >> 8),
                        static_cast<std::uint8_t>(data >> 16),
                        static_cast<std::uint8_t>(data >> 24),
                    };
                    if (!spike_->backdoor_write_mem(
                            aligned_address, bytes.size(), bytes.data())) {
                        return failure(
                            "MEM",
                            "cannot mirror MMIO load at " +
                                hex32(aligned_address));
                    }
                }
                ++mmio_syncs_;
            }
            DSideAccessInfo access{
                store,
                data,
                aligned_address,
                byte_enable,
                false,
                false,
                false,
            };
            spike_->notify_dside_access(access);
        }

        spike_->clear_errors();
        const std::uint32_t write_register =
            event.retired && event.rd_wen ? event.rd_addr : 0;
        const bool stepped = spike_->step(
            write_register,
            event.rd_wdata,
            event.pc_rdata,
            event.sync_trap);
        if (!stepped) {
            const auto& errors = spike_->get_errors();
            std::ostringstream message;
            for (std::size_t index = 0; index < errors.size(); ++index) {
                if (index != 0) {
                    message << "; ";
                }
                message << errors[index];
            }
            const std::string rendered =
                message.str().empty() ? "Spike step failed" : message.str();
            return failure(classify_error(rendered), rendered);
        }
        if (entering_irq && !compare_irq_entry_state(event, outcome)) {
            return outcome;
        }

        const std::uint32_t reference_next_pc = spike_->get_pc();
        if (reference_next_pc != event.pc_wdata) {
            return failure(
                "NEXT_PC",
                "next PC mismatch after " + hex32(event.pc_rdata) +
                    ": DUT=" + hex32(event.pc_wdata) +
                    " REF=" + hex32(reference_next_pc),
                reference_next_pc);
        }
        if (event.retired && event.rd_wen) {
            const std::uint32_t reference_gpr =
                spike_->get_gpr(event.rd_addr);
            if (reference_gpr != event.rd_wdata) {
                return failure(
                    "GPR",
                    "x" + std::to_string(event.rd_addr) +
                        " mismatch: DUT=" + hex32(event.rd_wdata) +
                        " REF=" + hex32(reference_gpr),
                    reference_next_pc,
                    reference_gpr);
            }
        }
        // csr_mip is sampled with the retiring DUT instruction. Applying it
        // before stepping Spike would let an IRQ that arrived while that
        // instruction was in flight preempt it one instruction too early.
        // Make the sampled level visible at the following instruction
        // boundary; an explicit ordered IRQ event still overrides it before
        // the corresponding step.
        spike_->set_mip(event.csr_mip);
        update_trigger_shadow(event);
        outcome.mmio_syncs = mmio_syncs_;
        return outcome;
    }

private:
    ReferenceStepOutcome failure(
        const std::string& kind,
        const std::string& message,
        std::uint32_t reference_pc = 0,
        std::uint32_t reference_value = 0) const {
        ReferenceStepOutcome outcome;
        outcome.passed = false;
        outcome.kind = kind;
        outcome.message = message;
        outcome.reference_pc = reference_pc;
        outcome.reference_value = reference_value;
        outcome.mmio_syncs = mmio_syncs_;
        return outcome;
    }

    bool compare_csr(
        int csr,
        std::uint32_t dut_value,
        std::uint32_t mask,
        const char* name,
        ReferenceStepOutcome& outcome) {
        const std::uint32_t reference = spike_->get_csr_value(csr);
        if ((reference & mask) == (dut_value & mask)) {
            return true;
        }
        outcome = failure(
            "CSR",
            std::string(name) + " pre-state mismatch: DUT=" +
                hex32(dut_value & mask) +
                " REF=" + hex32(reference & mask),
            spike_->get_pc(),
            reference);
        return false;
    }

    bool compare_pre_state(
        const ArchEvent& event,
        ReferenceStepOutcome& outcome) {
        if (!compare_csr(
                kCsrMstatus,
                event.csr_mstatus,
                kMstatusMask,
                "mstatus",
                outcome) ||
            !compare_csr(
                kCsrMie,
                event.csr_mie,
                kMachineInterruptMask,
                "mie",
                outcome) ||
            !compare_csr(
                kCsrMtvec,
                event.csr_mtvec,
                0xffffffffu,
                "mtvec",
                outcome) ||
            !compare_csr(
                kCsrMscratch,
                event.csr_mscratch,
                0xffffffffu,
                "mscratch",
                outcome) ||
            !compare_csr(
                kCsrMepc,
                event.csr_mepc,
                0xffffffffu,
                "mepc",
                outcome) ||
            !compare_csr(
                kCsrMcause,
                event.csr_mcause,
                0xffffffffu,
                "mcause",
                outcome) ||
            !compare_csr(
                kCsrMtval,
                event.csr_mtval,
                0xffffffffu,
                "mtval",
                outcome)) {
            return false;
        }
        const std::uint64_t reference_minstret =
            static_cast<std::uint64_t>(
                spike_->get_csr_value(kCsrMinstret)) |
            (static_cast<std::uint64_t>(
                 spike_->get_csr_value(kCsrMinstreth))
             << 32);
        if (reference_minstret != event.csr_minstret) {
            outcome = failure(
                "CSR",
                "minstret pre-state mismatch: DUT=" +
                    std::to_string(event.csr_minstret) +
                    " REF=" + std::to_string(reference_minstret),
                spike_->get_pc(),
                static_cast<std::uint32_t>(reference_minstret));
            return false;
        }
        return true;
    }

    bool compare_irq_entry_state(
        const ArchEvent& event,
        ReferenceStepOutcome& outcome) {
        // The Ibex co-sim wrapper takes an asynchronous interrupt and executes
        // the first handler instruction in one step. The event CSR snapshot is
        // from immediately before that instruction, so compare only
        // non-counter trap state here. The following event resumes the full
        // pre-state comparison.
        return compare_csr(
                   kCsrMstatus,
                   event.csr_mstatus,
                   kMstatusMask,
                   "mstatus",
                   outcome) &&
               compare_csr(
                   kCsrMtvec,
                   event.csr_mtvec,
                   0xffffffffu,
                   "mtvec",
                   outcome) &&
               compare_csr(
                   kCsrMepc,
                   event.csr_mepc,
                   0xffffffffu,
                   "mepc",
                   outcome) &&
               compare_csr(
                   kCsrMcause,
                   event.csr_mcause,
                   0xffffffffu,
                   "mcause",
                   outcome) &&
               compare_csr(
                   kCsrMtval,
                   event.csr_mtval,
                   0xffffffffu,
                   "mtval",
                   outcome);
    }

    bool is_mmio(std::uint32_t address) const {
        for (const DiffMemoryRegion& region : config_.regions) {
            if (region.mmio &&
                address >= region.base &&
                address - region.base < region.size) {
                return true;
            }
        }
        return false;
    }

    bool trigger_match(
        const ArchEvent& event,
        std::uint32_t& matched_address) const {
        const std::uint32_t opcode = event.instruction & 0x7fu;
        std::uint32_t access_address = event.pc_rdata;
        std::uint32_t operation_bit = 2u;
        if (opcode == 0x03u) {
            access_address =
                event.rs1_rdata + static_cast<std::uint32_t>(
                    sign_extend_12(event.instruction >> 20));
            operation_bit = 0u;
        } else if (opcode == 0x23u) {
            const std::uint32_t immediate =
                ((event.instruction >> 25) << 5) |
                ((event.instruction >> 7) & 0x1fu);
            access_address =
                event.rs1_rdata + static_cast<std::uint32_t>(
                    sign_extend_12(immediate));
            operation_bit = 1u;
        }

        for (std::size_t index = 0; index < trigger_data1_.size(); ++index) {
            const std::uint32_t control = trigger_data1_[index];
            const bool mode_enabled =
                (event.mode == 3u && ((control >> 6) & 1u)) ||
                (event.mode == 1u && ((control >> 4) & 1u)) ||
                (event.mode == 0u && ((control >> 3) & 1u));
            if (((control >> 28) & 0xfu) == 2u &&
                mode_enabled &&
                ((control >> operation_bit) & 1u) &&
                trigger_data2_[index] == access_address) {
                matched_address = access_address;
                return true;
            }
        }
        return false;
    }

    void update_trigger_shadow(const ArchEvent& event) {
        if (!event.retired ||
            (event.instruction & 0x7fu) != 0x73u) {
            return;
        }
        const std::uint32_t funct3 =
            (event.instruction >> 12) & 7u;
        const std::uint32_t address =
            (event.instruction >> 20) & 0xfffu;
        if (funct3 == 0u ||
            !(address == 0x7a0u ||
              address == 0x7a1u ||
              address == 0x7a2u)) {
            return;
        }

        std::uint32_t old_value = 0;
        if (address == 0x7a0u) {
            old_value = trigger_select_;
        } else if (address == 0x7a1u) {
            old_value = trigger_data1_[trigger_select_];
        } else {
            old_value = trigger_data2_[trigger_select_];
        }
        const std::uint32_t source =
            funct3 >= 5u ?
                ((event.instruction >> 15) & 0x1fu) :
                event.rs1_rdata;
        bool write = false;
        std::uint32_t value = old_value;
        if (funct3 == 1u || funct3 == 5u) {
            write = true;
            value = source;
        } else if (funct3 == 2u || funct3 == 6u) {
            write = source != 0;
            value = old_value | source;
        } else if (funct3 == 3u || funct3 == 7u) {
            write = source != 0;
            value = old_value & ~source;
        }
        if (!write) {
            return;
        }
        if (address == 0x7a0u) {
            trigger_select_ = value & 1u;
        } else if (address == 0x7a1u) {
            trigger_data1_[trigger_select_] = value;
        } else {
            trigger_data2_[trigger_select_] = value;
        }
    }

    void load_word_image(const DiffMemoryRegion& region) {
        std::ifstream input(region.image_path);
        if (!input) {
            throw std::runtime_error(
                "cannot open DiffTest image: " + region.image_path);
        }
        std::string line;
        std::uint32_t address = region.base;
        while (std::getline(input, line)) {
            const auto comment = line.find_first_of("#;");
            if (comment != std::string::npos) {
                line.erase(comment);
            }
            std::istringstream parser(line);
            std::string token;
            if (!(parser >> token)) {
                continue;
            }
            const std::uint32_t word =
                static_cast<std::uint32_t>(std::stoul(token, nullptr, 16));
            std::array<std::uint8_t, 4> bytes{
                static_cast<std::uint8_t>(word),
                static_cast<std::uint8_t>(word >> 8),
                static_cast<std::uint8_t>(word >> 16),
                static_cast<std::uint8_t>(word >> 24),
            };
            if (address - region.base + bytes.size() > region.size) {
                throw std::runtime_error(
                    "DiffTest image exceeds region " + region.name);
            }
            if (!spike_->backdoor_write_mem(
                    address, bytes.size(), bytes.data())) {
                throw std::runtime_error(
                    "cannot load DiffTest memory at " + hex32(address));
            }
            address += static_cast<std::uint32_t>(bytes.size());
        }
    }

    ReferenceConfig config_;
    std::unique_ptr<SpikeCosim> spike_;
    bool irq_notification_pending_ = false;
    std::uint64_t mmio_syncs_ = 0;
    std::uint32_t trigger_select_ = 0;
    std::array<std::uint32_t, 2> trigger_data1_{};
    std::array<std::uint32_t, 2> trigger_data2_{};
};

}  // namespace

bool spike_reference_available() {
    return true;
}

std::unique_ptr<ReferenceModel> create_reference_model(
    const ReferenceConfig& config) {
    if (config.backend != "spike") {
        throw std::runtime_error(
            "unsupported DiffTest backend: " + config.backend);
    }
    return std::make_unique<SpikeReferenceModel>(config);
}

#else

bool spike_reference_available() {
    return false;
}

std::unique_ptr<ReferenceModel> create_reference_model(
    const ReferenceConfig&) {
    throw std::runtime_error("Spike support is not compiled into this model");
}

#endif
