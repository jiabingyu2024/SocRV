if {$argc < 5} {
    error "usage: build_bitstream.tcl BUILD_DIR CODE_LO_MEM CODE_HI_MEM DATA_MEM JOBS"
}
set script_dir [file normalize [file dirname [info script]]]
set build_dir [file normalize [lindex $argv 0]]
set code_lo_mem [file normalize [lindex $argv 1]]
set code_hi_mem [file normalize [lindex $argv 2]]
set data_mem [file normalize [lindex $argv 3]]
set jobs [lindex $argv 4]

set argv [list $build_dir $code_lo_mem $code_hi_mem $data_mem]
set argc 4
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
