if {$argc < 1} {
    error "usage: synth.tcl PROJECT_XPR ?JOBS? ?REPORT_MODE?"
}
set project_xpr [file normalize [lindex $argv 0]]
set jobs [expr {$argc >= 2 ? [lindex $argv 1] : 4}]
set report_mode [expr {$argc >= 3 ? [lindex $argv 2] : "top"}]
if {$report_mode ni {top all}} {
    error "REPORT_MODE must be top or all"
}
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
report_timing -delay_type max -max_paths 100 -nworst 1 \
    -path_type full_clock_expanded -input_pins \
    -file [file join $report_dir post_synth_setup_paths.rpt]
report_timing -delay_type min -max_paths 50 -nworst 1 \
    -path_type full_clock_expanded -input_pins \
    -file [file join $report_dir post_synth_hold_paths.rpt]
if {$report_mode eq "all"} {
    report_timing -delay_type max -slack_lesser_than 0 -max_paths 10000 -nworst 1 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $report_dir post_synth_setup_violations.rpt]
    report_timing -delay_type min -slack_lesser_than 0 -max_paths 10000 -nworst 1 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $report_dir post_synth_hold_violations.rpt]
}
report_clock_interaction -file [file join $report_dir post_synth_clock_interaction.rpt]
report_clock_utilization -file [file join $report_dir post_synth_clock_utilization.rpt]
report_cdc -file [file join $report_dir post_synth_cdc.rpt]
close_project
