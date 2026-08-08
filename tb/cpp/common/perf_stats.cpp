#include "perf_stats.h"

#include <algorithm>

PerfStats::PerfStats(const SimConfig& config)
    : requested_(config.performance_enabled()),
      start_code_(config.perf_start_code),
      stop_code_(config.perf_stop_code),
      iterations_(config.benchmark_iterations),
      soc_hz_(config.soc_hz) {}

void PerfStats::observe(
    std::uint64_t cycle,
    std::uint32_t retired_count,
    std::uint32_t test_code,
    const PerfCounterSample& perf_counters) {
    total_commits_ += retired_count;
    if (!requested_) {
        return;
    }
    if (!started_ && test_code == start_code_) {
        started_ = true;
        start_cycle_ = cycle;
        start_commits_ = total_commits_;
        start_perf_counters_ = perf_counters;
    } else if (started_ && !complete_) {
        if (retired_count == 0) {
            ++zero_retire_cycles_;
        } else if (retired_count == 1) {
            ++single_retire_cycles_;
        } else {
            ++dual_retire_cycles_;
        }
        if (perf_counters.icache_stall) {
            ++stall_icache_cycles_;
        }
        if (perf_counters.decode_stall) {
            ++stall_decode_cycles_;
        }
        if (perf_counters.rename_stall) {
            ++stall_rename_cycles_;
        }
        if (perf_counters.backend_stall) {
            ++stall_backend_cycles_;
        }
        if (perf_counters.recovery_cycle) {
            ++recovery_cycles_;
        }
        if (perf_counters.recovery_phase == 1) {
            ++recovery_phase0_cycles_;
        } else if (perf_counters.recovery_phase == 2) {
            ++recovery_phase1_cycles_;
        }
        if (perf_counters.recovery_to_phase) {
            ++recovery_start_cycles_;
        }
        if (perf_counters.recovery_rmt) {
            ++recovery_rmt_cycles_;
        }
        if (perf_counters.recovery_iq_return) {
            ++recovery_iq_return_cycles_;
        }
        if (perf_counters.recovery_replay_flush) {
            ++recovery_replay_flush_cycles_;
        }
        if (perf_counters.recovery_wakeup_flush) {
            ++recovery_wakeup_flush_cycles_;
        }
        if (perf_counters.recovery_unable_start) {
            ++recovery_unable_start_cycles_;
        }
        if (perf_counters.recovery_commit_exception) {
            ++recovery_commit_exception_cycles_;
        }
        if (perf_counters.recovery_rw_exception) {
            ++recovery_rw_exception_cycles_;
        }
        if (perf_counters.recovery_flush_all) {
            ++recovery_flush_all_cycles_;
        }
        if (perf_counters.recovery_active_list) {
            ++recovery_active_list_cycles_;
        }
        for (const BranchEventSample& event : perf_counters.branch_events) {
            if (!event.valid) {
                continue;
            }
            BranchHotspot& hotspot = branch_hotspots_[event.pc];
            hotspot.pc = event.pc;
            ++hotspot.executed;
            ++observed_branch_events_;
            if (event.mispred) {
                ++hotspot.mispredicts;
                ++observed_branch_mispredicts_;
                if (event.conditional) {
                    ++hotspot.conditional_mispredicts;
                    ++observed_conditional_mispredicts_;
                }
            }
        }
        for (std::size_t lane = 0;
             lane < perf_counters.decode_flush_trigger.size();
             ++lane) {
            if (!perf_counters.decode_flush_trigger[lane]) {
                continue;
            }
            const std::uint32_t pc = perf_counters.decode_branch_pc[lane];
            BranchHotspot& hotspot = branch_hotspots_[pc];
            hotspot.pc = pc;
            ++hotspot.decode_corrections;
            ++observed_decode_corrections_;
        }
        if (perf_counters.rename_no_physreg) {
            ++rename_no_physreg_cycles_;
        }
        if (perf_counters.rename_no_iq) {
            ++rename_no_iq_cycles_;
        }
        if (perf_counters.rename_no_rob) {
            ++rename_no_rob_cycles_;
        }
        if (perf_counters.rename_no_lsq) {
            ++rename_no_lsq_cycles_;
        }
        if (perf_counters.rename_serialize) {
            ++rename_serialize_cycles_;
        }
        if (perf_counters.dispatch_count == 0) {
            ++zero_dispatch_cycles_;
        } else if (perf_counters.dispatch_count == 1) {
            ++single_dispatch_cycles_;
        } else {
            ++dual_dispatch_cycles_;
        }
        if (perf_counters.issue_count == 0) {
            ++zero_issue_cycles_;
        } else if (perf_counters.issue_count == 1) {
            ++single_issue_cycles_;
        } else {
            ++multi_issue_cycles_;
        }
        if (test_code == stop_code_) {
            complete_ = true;
            end_cycle_ = cycle;
            end_commits_ = total_commits_;
            end_perf_counters_ = perf_counters;
        }
    }
}

std::uint64_t PerfStats::total_commits() const {
    return total_commits_;
}

PerfSnapshot PerfStats::snapshot() const {
    PerfSnapshot value;
    value.requested = requested_;
    value.complete = complete_;
    value.iterations = iterations_;
    if (!complete_) {
        return value;
    }
    value.start_cycle = start_cycle_;
    value.end_cycle = end_cycle_;
    value.cycles = end_cycle_ - start_cycle_;
    value.commits = end_commits_ - start_commits_;
    value.zero_retire_cycles = zero_retire_cycles_;
    value.single_retire_cycles = single_retire_cycles_;
    value.dual_retire_cycles = dual_retire_cycles_;
    value.hpm_icache_misses = static_cast<std::uint32_t>(
        end_perf_counters_.icache_misses - start_perf_counters_.icache_misses);
    value.hpm_load_misses = static_cast<std::uint32_t>(
        end_perf_counters_.load_misses - start_perf_counters_.load_misses);
    value.hpm_store_misses = static_cast<std::uint32_t>(
        end_perf_counters_.store_misses - start_perf_counters_.store_misses);
    value.hpm_branch_mispredicts = static_cast<std::uint32_t>(
        end_perf_counters_.branch_mispredicts -
        start_perf_counters_.branch_mispredicts);
    value.hpm_decode_branch_mispredicts = static_cast<std::uint32_t>(
        end_perf_counters_.decode_branch_mispredicts -
        start_perf_counters_.decode_branch_mispredicts);
    value.hpm_store_load_forwarding_failures = static_cast<std::uint32_t>(
        end_perf_counters_.store_load_forwarding_failures -
        start_perf_counters_.store_load_forwarding_failures);
    value.hpm_memory_dependency_mispredicts = static_cast<std::uint32_t>(
        end_perf_counters_.memory_dependency_mispredicts -
        start_perf_counters_.memory_dependency_mispredicts);
    value.stall_icache_cycles = stall_icache_cycles_;
    value.stall_decode_cycles = stall_decode_cycles_;
    value.stall_rename_cycles = stall_rename_cycles_;
    value.stall_backend_cycles = stall_backend_cycles_;
    value.recovery_cycles = recovery_cycles_;
    value.recovery_phase0_cycles = recovery_phase0_cycles_;
    value.recovery_phase1_cycles = recovery_phase1_cycles_;
    value.recovery_start_cycles = recovery_start_cycles_;
    value.recovery_rmt_cycles = recovery_rmt_cycles_;
    value.recovery_iq_return_cycles = recovery_iq_return_cycles_;
    value.recovery_replay_flush_cycles = recovery_replay_flush_cycles_;
    value.recovery_wakeup_flush_cycles = recovery_wakeup_flush_cycles_;
    value.recovery_unable_start_cycles = recovery_unable_start_cycles_;
    value.recovery_commit_exception_cycles = recovery_commit_exception_cycles_;
    value.recovery_rw_exception_cycles = recovery_rw_exception_cycles_;
    value.recovery_flush_all_cycles = recovery_flush_all_cycles_;
    value.recovery_active_list_cycles = recovery_active_list_cycles_;
    value.observed_branch_events = observed_branch_events_;
    value.observed_branch_mispredicts = observed_branch_mispredicts_;
    value.observed_conditional_mispredicts =
        observed_conditional_mispredicts_;
    value.observed_decode_corrections = observed_decode_corrections_;
    value.branch_mispredict_hotspots.reserve(branch_hotspots_.size());
    for (const auto& entry : branch_hotspots_) {
        value.branch_mispredict_hotspots.push_back(entry.second);
    }
    std::sort(
        value.branch_mispredict_hotspots.begin(),
        value.branch_mispredict_hotspots.end(),
        [](const BranchHotspot& lhs, const BranchHotspot& rhs) {
            const std::uint64_t lhs_total =
                lhs.mispredicts + lhs.decode_corrections;
            const std::uint64_t rhs_total =
                rhs.mispredicts + rhs.decode_corrections;
            if (lhs_total != rhs_total) {
                return lhs_total > rhs_total;
            }
            if (lhs.mispredicts != rhs.mispredicts) {
                return lhs.mispredicts > rhs.mispredicts;
            }
            return lhs.pc < rhs.pc;
        });
    constexpr std::size_t kHotspotLimit = 16;
    if (value.branch_mispredict_hotspots.size() > kHotspotLimit) {
        value.branch_mispredict_hotspots.resize(kHotspotLimit);
    }
    value.rename_no_physreg_cycles = rename_no_physreg_cycles_;
    value.rename_no_iq_cycles = rename_no_iq_cycles_;
    value.rename_no_rob_cycles = rename_no_rob_cycles_;
    value.rename_no_lsq_cycles = rename_no_lsq_cycles_;
    value.rename_serialize_cycles = rename_serialize_cycles_;
    value.zero_dispatch_cycles = zero_dispatch_cycles_;
    value.single_dispatch_cycles = single_dispatch_cycles_;
    value.dual_dispatch_cycles = dual_dispatch_cycles_;
    value.zero_issue_cycles = zero_issue_cycles_;
    value.single_issue_cycles = single_issue_cycles_;
    value.multi_issue_cycles = multi_issue_cycles_;
    if (value.cycles != 0) {
        value.ipc = static_cast<double>(value.commits) /
                    static_cast<double>(value.cycles);
    }
    if (soc_hz_ != 0) {
        value.seconds = static_cast<double>(value.cycles) /
                        static_cast<double>(soc_hz_);
    }
    if (iterations_ != 0) {
        value.cycles_per_iteration =
            static_cast<double>(value.cycles) /
            static_cast<double>(iterations_);
        value.commits_per_iteration =
            static_cast<double>(value.commits) /
            static_cast<double>(iterations_);
    }
    if (value.seconds != 0.0) {
        value.iterations_per_second =
            static_cast<double>(iterations_) / value.seconds;
    }
    return value;
}
