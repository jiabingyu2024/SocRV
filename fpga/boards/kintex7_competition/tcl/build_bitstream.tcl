if {$argc < 3} {
    error "usage: build_bitstream.tcl BUILD_DIR IMAGE_DIR JOBS ?STAGE? ?REPORT_MODE?"
}
set script_dir [file normalize [file dirname [info script]]]
set build_dir [file normalize [lindex $argv 0]]
set image_dir [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]
set stage [expr {$argc >= 4 ? [lindex $argv 3] : "bitstream"}]
set report_mode [expr {$argc >= 5 ? [lindex $argv 4] : "top"}]
if {$stage ni {synth impl bitstream}} {
    error "STAGE must be synth, impl or bitstream"
}
if {$report_mode ni {top all}} {
    error "REPORT_MODE must be top or all"
}

set argv [list $build_dir $image_dir]
set argc 2
source [file join $script_dir create_project.tcl]
close_project

set project_xpr [file join $build_dir socrv.xpr]
set argv [list $project_xpr $jobs $report_mode]
set argc 3
source [file join $script_dir synth.tcl]

if {$stage eq "synth"} {
    puts "SOCRV_FPGA_SYNTH_COMPLETE=$build_dir"
    exit 0
}

set argv [list $project_xpr $jobs $report_mode]
set argc 3
source [file join $script_dir impl.tcl]

if {$stage eq "impl"} {
    puts "SOCRV_FPGA_IMPL_COMPLETE=$build_dir"
    exit 0
}

set argv [list $project_xpr $jobs]
set argc 2
source [file join $script_dir bitstream.tcl]
puts "SOCRV_FPGA_BUILD_COMPLETE=$build_dir"
