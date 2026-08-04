#ifndef SOCRV_TB_SIM_CONTROL_H
#define SOCRV_TB_SIM_CONTROL_H

#include "sim_config.h"
#include "sim_result.h"

class SocDutAdapter;

class SimControl {
public:
    SimControl(const SimConfig& config, SocDutAdapter& dut);
    SimResult run();

private:
    const SimConfig& config_;
    SocDutAdapter& dut_;
};

#endif
