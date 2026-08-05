#ifndef SOCRV_TB_DIFFTEST_CHECKER_H
#define SOCRV_TB_DIFFTEST_CHECKER_H

#include <cstdint>
#include <deque>
#include <memory>
#include <string>
#include <vector>

#include "difftest_types.h"

class ReferenceModel;
struct SimConfig;

class DiffTestChecker {
public:
    explicit DiffTestChecker(const SimConfig& config);
    ~DiffTestChecker();

    void observe_cycle(
        std::uint64_t cycle,
        const std::vector<ArchEvent>& events,
        const std::vector<IrqEvent>& irq_events);
    void finish();

    bool enabled() const;
    bool passed() const;
    const DiffTestSnapshot& snapshot() const;

private:
    void fail(
        std::uint64_t cycle,
        std::uint64_t order,
        const std::string& kind,
        const std::string& message);
    void remember(const std::string& line);
    void write_artifacts(bool final);

    DiffTestSnapshot snapshot_;
    std::unique_ptr<ReferenceModel> reference_;
    std::deque<std::string> commit_history_;
    std::deque<std::string> memory_history_;
    std::uint64_t expected_order_ = 0;
    bool expected_order_valid_ = false;
    bool artifacts_written_ = false;
};

#endif
