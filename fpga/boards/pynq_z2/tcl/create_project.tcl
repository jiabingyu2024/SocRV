if {$argc < 2} {
    error "usage: create_project.tcl BUILD_DIR IMAGE_DIR"
}

set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. .. ..]]
set build_dir [file normalize [lindex $argv 0]]
set image_dir [file normalize [lindex $argv 1]]
set part xc7z020clg400-1

set image_names [list \
    iccm_lane0.mem iccm_lane1.mem iccm_lane2.mem iccm_lane3.mem \
    dccm_bank0.mem dccm_bank1.mem dccm_bank2.mem dccm_bank3.mem \
    dccm_bank4.mem dccm_bank5.mem dccm_bank6.mem dccm_bank7.mem]
foreach name $image_names {
    set required [file join $image_dir $name]
    if {![file exists $required]} {
        error "required memory image does not exist: $required"
    }
}

set socrv_sources [list]
set socrv_include_dirs [list]
proc read_socrv_filelist {repo_dir filelist_path} {
    global socrv_sources
    global socrv_include_dirs
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
            lappend socrv_include_dirs $include_path
        } else {
            set source_path [file normalize [file join $repo_dir $line]]
            if {![file exists $source_path]} {
                error "filelist source does not exist: $source_path"
            }
            lappend socrv_sources $source_path
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

read_socrv_filelist $repo_dir [file join $repo_dir sim filelists fpga_pynq_z2.f]
set_property include_dirs $socrv_include_dirs [current_fileset]
read_verilog -sv $socrv_sources
set eh1_defines [get_files -quiet -filter {NAME =~ "*common_defines.vh"}]
if {[llength $eh1_defines] != 1} {
    error "expected exactly one common_defines.vh, got [llength $eh1_defines]"
}
set_property file_type {Verilog Header} $eh1_defines
set_property is_global_include true $eh1_defines
read_xdc [list [file join $repo_dir fpga boards pynq_z2 constraints pins.xdc]]
read_xdc [list [file join $repo_dir fpga boards pynq_z2 constraints clocks.xdc]]
read_xdc [list [file join $repo_dir fpga boards pynq_z2 constraints cdc.xdc]]

set_property top fpga_top [current_fileset]
set generics [list "CORE_CLOCK_HZ=50000000" "PERIPHERAL_CLOCK_HZ=50000000"]
for {set lane 0} {$lane < 4} {incr lane} {
    lappend generics "ICCM_LANE${lane}_INIT_FILE=[file join $image_dir iccm_lane${lane}.mem]"
}
for {set bank 0} {$bank < 8} {incr bank} {
    lappend generics "DCCM_BANK${bank}_INIT_FILE=[file join $image_dir dccm_bank${bank}.mem]"
}
set_property generic $generics [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
update_compile_order -fileset sources_1
puts "SOCRV_PROJECT=[get_property DIRECTORY [current_project]]"
