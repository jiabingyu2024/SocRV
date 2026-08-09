#ifndef SOCRV_TB_SOC_DUT_ADAPTER_H
#define SOCRV_TB_SOC_DUT_ADAPTER_H

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "difftest_types.h"

class VerilatedContext;
class VerilatedVcdC;
class Vsoc_sim_top;

class SocDutAdapter {
public:
    SocDutAdapter(int argc, char** argv, const std::string& trace_path);
    ~SocDutAdapter();

    SocDutAdapter(const SocDutAdapter&) = delete;
    SocDutAdapter& operator=(const SocDutAdapter&) = delete;

    void set_reset(bool released);
    void set_uart_rx(bool value);
    void step_cycle();
    void finish();

    bool uart_tx() const;
    bool commit_valid() const;
    std::uint32_t retired_count() const;
    std::uint32_t commit_pc() const;
    std::uint32_t debug_mepc() const;
    std::uint32_t debug_mcause() const;
    std::uint32_t debug_mtval() const;
    std::uint32_t debug_lsu_start() const;
    std::uint32_t debug_lsu_end() const;
    std::uint32_t debug_lsu_flags() const;
    std::uint32_t debug_inst_flags() const;
    std::uint32_t debug_inst_pc() const;
    std::uint32_t debug_inst_target() const;
    std::vector<ArchEvent> arch_events() const;
    std::vector<IrqEvent> irq_events() const;
    bool cpu_fault() const;
    bool test_done() const;
    bool test_pass() const;
    std::uint32_t test_code() const;

private:
    std::unique_ptr<VerilatedContext> context_;
    std::unique_ptr<Vsoc_sim_top> dut_;
#if VM_TRACE
    std::unique_ptr<VerilatedVcdC> trace_;
#endif
    bool finished_ = false;
};

#endif
