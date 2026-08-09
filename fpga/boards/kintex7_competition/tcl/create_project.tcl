if {$argc < 4} {
    error "usage: create_project.tcl BUILD_DIR CODE_LO_MEM CODE_HI_MEM DATA_MEM"
}

set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. .. ..]]
set build_dir [file normalize [lindex $argv 0]]
set code_lo_mem [file normalize [lindex $argv 1]]
set code_hi_mem [file normalize [lindex $argv 2]]
set data_mem [file normalize [lindex $argv 3]]
set part xc7k325tffg900-2

foreach required [list $code_lo_mem $code_hi_mem $data_mem] {
    if {![file exists $required]} {
        error "required memory image does not exist: $required"
    }
}

proc read_socrv_filelist {repo_dir filelist_path} {
    set stream [open $filelist_path r]
    while {[gets $stream line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} {
            continue
        }
        if {[regexp {^-f[ \t]+(.+)$} $line -> nested]} {
            read_socrv_filelist $repo_dir [file normalize [file join $repo_dir $nested]]
        } elseif {[regexp {^\+incdir\+(.+)$} $line -> incdir]} {
            set include_path [file normalize [file join $repo_dir $incdir]]
            set current_dirs [get_property include_dirs [current_fileset]]
            set_property include_dirs [concat $current_dirs [list $include_path]] [current_fileset]
        } else {
            set source_path [file normalize [file join $repo_dir $line]]
            if {![file exists $source_path]} {
                error "filelist source does not exist: $source_path"
            }
            read_verilog -sv $source_path
        }
    }
    close $stream
}

file mkdir $build_dir
create_project -force socrv $build_dir -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property verilog_define {SYNTHESIS} [current_fileset]

read_socrv_filelist $repo_dir [file join $repo_dir sim filelists fpga_kintex7.f]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints pins.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints clocks.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints cdc.xdc]

set_property top fpga_top [current_fileset]
if {[info exists ::env(SOCRV_CORE_DIVIDE)]} {
    set core_divide $::env(SOCRV_CORE_DIVIDE)
} else {
    set core_divide 10.0
}
set_property generic [list "CORE_CLKOUT_DIVIDE_F=$core_divide" "CODE_MEM_LO_FILE=$code_lo_mem" "CODE_MEM_HI_FILE=$code_hi_mem" "DATA_MEM_FILE=$data_mem"] [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
# The TCMs are explicit BRAM macros, so implementation effort should be spent
# on the remaining high-fanout front-end/LSU control paths.  These directives
# are part of every frequency sign-off build, rather than relying on a lucky
# default-place seed.
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
update_compile_order -fileset sources_1
puts "SOCRV_PROJECT=[get_property DIRECTORY [current_project]]"
