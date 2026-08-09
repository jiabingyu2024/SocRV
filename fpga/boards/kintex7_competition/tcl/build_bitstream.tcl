if {$argc < 3} {
    error "usage: build_bitstream.tcl BUILD_DIR IMAGE_DIR JOBS"
}
set script_dir [file normalize [file dirname [info script]]]
set build_dir [file normalize [lindex $argv 0]]
set image_dir [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]

set argv [list $build_dir $image_dir]
set argc 2
source [file join $script_dir create_project.tcl]
close_project

set project_xpr [file join $build_dir socrv.xpr]
set argv [list $project_xpr $jobs]
set argc 2
source [file join $script_dir synth.tcl]

set argv [list $project_xpr $jobs]
set argc 2
source [file join $script_dir impl.tcl]

set argv [list $project_xpr $jobs]
set argc 2
source [file join $script_dir bitstream.tcl]
puts "SOCRV_FPGA_BUILD_COMPLETE=$build_dir"
