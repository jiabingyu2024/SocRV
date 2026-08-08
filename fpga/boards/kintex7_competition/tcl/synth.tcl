if {$argc < 1} {
    error "usage: synth.tcl PROJECT_XPR ?JOBS?"
}
set project_xpr [file normalize [lindex $argv 0]]
set jobs [expr {$argc >= 2 ? [lindex $argv 1] : 4}]
open_project $project_xpr
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synthesis did not complete"
}
open_run synth_1
set report_dir [file join [get_property DIRECTORY [current_project]] reports]
file mkdir $report_dir
report_utilization -hierarchical -file [file join $report_dir post_synth_utilization.rpt]
report_timing_summary -file [file join $report_dir post_synth_timing_summary.rpt]
report_clock_utilization -file [file join $report_dir post_synth_clock_utilization.rpt]
report_cdc -details -file [file join $report_dir post_synth_cdc.rpt]
close_project
