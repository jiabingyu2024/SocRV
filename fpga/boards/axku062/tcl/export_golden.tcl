if {$argc < 2 || $argc > 3} {
    error "usage: export_golden.tcl ROUTED_DCP GOLDEN_DIR ?ALLOW_TIMING_VIOLATIONS?"
}

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir .. .. .. ..]]
set dcp_path [file normalize [lindex $argv 0]]
set golden_dir [file normalize [lindex $argv 1]]
set allow_timing_violations [expr {$argc == 3 && [lindex $argv 2]}]
file mkdir $golden_dir

open_checkpoint $dcp_path
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set drc_report [file join $golden_dir golden_drc.rpt]
set timing_report [file join $golden_dir golden_timing_summary.rpt]
report_drc -file $drc_report
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -max_paths 10 -input_pins -file $timing_report

set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $drc_errors] != 0} {
    error "golden checkpoint has [llength $drc_errors] DRC errors"
}
set setup_path [get_timing_paths -quiet -delay_type max -max_paths 1]
set hold_path [get_timing_paths -quiet -delay_type min -max_paths 1]
if {[llength $setup_path] == 0 || [llength $hold_path] == 0} {
    error "golden checkpoint has no setup or hold timing path"
}
set setup_slack [get_property SLACK $setup_path]
set hold_slack [get_property SLACK $hold_path]
if {!$allow_timing_violations && ($setup_slack < 0.0 || $hold_slack < 0.0)} {
    error "golden checkpoint fails timing: setup=$setup_slack hold=$hold_slack"
}

set golden_dcp [file join $golden_dir golden_postroute.dcp]
set golden_bit [file join $golden_dir golden.bit]
write_checkpoint -force $golden_dcp
write_bitstream -force $golden_bit
close_design

set argv [list $golden_dcp [file join $golden_dir bram_map.tsv]]
set argc 2
source [file join $repo_root fpga tools export_bram_map.tcl]

puts "SOCRV_GOLDEN_DCP=$golden_dcp"
puts "SOCRV_GOLDEN_BIT=$golden_bit"
puts "SOCRV_GOLDEN_SETUP_SLACK=$setup_slack"
puts "SOCRV_GOLDEN_HOLD_SLACK=$hold_slack"
