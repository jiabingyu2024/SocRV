# Export all violating setup/hold paths from an already synthesized or implemented
# checkpoint. This is intentionally separate from the normal build flow so that
# path clustering can cover every failing endpoint before the next RTL batch.

if {$argc < 2} {
  puts "usage: vivado -mode batch -source report_all_violations.tcl -tclargs <project.xpr|checkpoint.dcp> <report_dir> ?synth|impl?"
  exit 2
}

set checkpoint [file normalize [lindex $argv 0]]
set report_dir [file normalize [lindex $argv 1]]
set stage [expr {$argc >= 3 ? [lindex $argv 2] : "synth"}]
if {$stage ni {synth impl}} {
  error "STAGE must be synth or impl"
}
file mkdir $report_dir

if {[string match "*.xpr" $checkpoint]} {
  open_project $checkpoint
  set run_name [expr {$stage eq "impl" ? "impl_1" : "synth_1"}]
  if {[llength [get_runs -quiet $run_name]] > 0 && [get_property PROGRESS [get_runs $run_name]] eq "100%"} {
    open_run $run_name
  } else {
    error "project does not contain a completed $run_name run"
  }
} else {
  open_checkpoint $checkpoint
}

report_timing_summary -delay_type max -file [file join $report_dir all_setup_timing_summary.rpt]
report_timing_summary -delay_type min -file [file join $report_dir all_hold_timing_summary.rpt]

# One worst path per endpoint keeps the report finite while covering every
# failing endpoint reported by timing_summary.
report_timing -delay_type max -slack_lesser_than 0 -max_paths 10000 -nworst 1 \
  -path_type full_clock_expanded -input_pins \
  -file [file join $report_dir all_setup_violations.rpt]
report_timing -delay_type min -slack_lesser_than 0 -max_paths 10000 -nworst 1 \
  -path_type full_clock_expanded -input_pins \
  -file [file join $report_dir all_hold_violations.rpt]

report_clock_interaction -file [file join $report_dir all_clock_interaction.rpt]
report_cdc -file [file join $report_dir all_cdc.rpt]
if {[llength [get_projects -quiet]] > 0} {
  close_project
} else {
  close_design
}
exit 0
