#ifndef SOCRV_TB_REFERENCE_MODEL_H
#define SOCRV_TB_REFERENCE_MODEL_H

#include <memory>
#include <string>
#include <vector>

#include "difftest_types.h"

struct ReferenceConfig {
    std::string backend;
    std::string backend_version;
    std::string mode;
    std::string isa;
    std::string reference_trace_path;
    std::uint32_t reset_pc = 0;
    std::uint32_t reset_mtvec = 0;
    std::vector<DiffMemoryRegion> regions;
};

class ReferenceModel {
public:
    virtual ~ReferenceModel() = default;
    virtual void notify_irq(const IrqEvent& event) = 0;
    virtual ReferenceStepOutcome step(const ArchEvent& event) = 0;
};

bool spike_reference_available();
std::unique_ptr<ReferenceModel> create_reference_model(
    const ReferenceConfig& config);

#endif
