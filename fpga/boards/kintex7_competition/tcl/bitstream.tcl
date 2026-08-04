if {$argc < 1} {
    error "usage: bitstream.tcl PROJECT_XPR ?JOBS?"
}
set project_xpr [file normalize [lindex $argv 0]]
set jobs [expr {$argc >= 2 ? [lindex $argv 1] : 4}]
open_project $project_xpr
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
if {![string match "*write_bitstream Complete*" $status]} {
    error "bitstream generation failed: $status"
}
puts "SOCRV_BITSTREAM=[file normalize [file join [get_property DIRECTORY [current_project]] socrv.runs impl_1 fpga_top.bit]]"
close_project
