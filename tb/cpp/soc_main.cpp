#include <exception>
#include <iostream>

#include "sim_config.h"
#include "sim_control.h"
#include "soc_dut_adapter.h"

int main(int argc, char** argv) {
    try {
        const SimConfig config = SimConfig::parse(argc, argv);
        SocDutAdapter dut(argc, argv, config.trace_path);
        SimControl simulation(config, dut);
        const SimResult result = simulation.run();
        result.write_json(config);
        return result.exit_code();
    } catch (const std::exception& error) {
        std::cerr << "CONFIG_ERROR: " << error.what() << "\n";
        return 2;
    }
}
