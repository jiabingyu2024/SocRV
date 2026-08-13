if {$argc < 1} {
    error "usage: impl.tcl PROJECT_XPR ?JOBS?"
}
set project_xpr [file normalize [lindex $argv 0]]
set jobs [expr {$argc >= 2 ? [lindex $argv 1] : 4}]
open_project $project_xpr
launch_runs impl_1 -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "implementation did not complete"
}
open_run impl_1
set report_dir [file join [get_property DIRECTORY [current_project]] reports]
file mkdir $report_dir
report_utilization -hierarchical -file [file join $report_dir post_impl_utilization.rpt]
report_timing_summary -file [file join $report_dir post_impl_timing_summary.rpt]
report_timing -delay_type max -max_paths 20 -nworst 5 \
    -path_type full_clock_expanded -input_pins \
    -file [file join $report_dir post_impl_timing_paths.rpt]
report_drc -file [file join $report_dir post_impl_drc.rpt]
report_methodology -file [file join $report_dir post_impl_methodology.rpt]
close_project
