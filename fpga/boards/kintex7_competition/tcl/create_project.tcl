if {$argc < 2} {
    error "usage: create_project.tcl BUILD_DIR IMAGE_DIR"
}

set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. .. ..]]
set build_dir [file normalize [lindex $argv 0]]
set image_dir [file normalize [lindex $argv 1]]
set part xc7k325tffg900-2

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
proc read_socrv_filelist {repo_dir filelist_path} {
    global socrv_sources
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
            # Keep the ordered source list and submit it as one SystemVerilog
            # compilation unit below.  EH1's generated common_defines.vh is
            # intentionally the first source and its macros must remain live
            # while veer_types and the implementation modules are parsed.
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

read_socrv_filelist $repo_dir [file join $repo_dir sim filelists fpga_kintex7.f]
read_verilog -sv $socrv_sources
set eh1_defines [file normalize [file join $repo_dir rtl core eh1f config eh1_stage_a common_defines.vh]]
set_property file_type {Verilog Header} [get_files $eh1_defines]
set_property is_global_include true [get_files $eh1_defines]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints pins.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints clocks.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints cdc.xdc]

set_property top fpga_top [current_fileset]
set clock_mult [expr {[info exists ::env(SOCRV_CLOCK_MULT)] ? $::env(SOCRV_CLOCK_MULT) : "5.0"}]
set core_divide [expr {[info exists ::env(SOCRV_CORE_DIVIDE)] ? $::env(SOCRV_CORE_DIVIDE) : "4.0"}]
set peripheral_divide [expr {[info exists ::env(SOCRV_PERIPHERAL_DIVIDE)] ? $::env(SOCRV_PERIPHERAL_DIVIDE) : 20}]
set core_hz [expr {[info exists ::env(SOCRV_CORE_HZ)] ? $::env(SOCRV_CORE_HZ) : 250000000}]
set generics [list "CLOCK_MULT_F=$clock_mult" \
                   "CORE_CLKOUT_DIVIDE_F=$core_divide" \
                   "PERIPHERAL_CLKOUT_DIVIDE=$peripheral_divide" \
                   "CORE_CLOCK_HZ=$core_hz"]
for {set lane 0} {$lane < 4} {incr lane} {
    lappend generics "ICCM_LANE${lane}_INIT_FILE=[file join $image_dir iccm_lane${lane}.mem]"
}
for {set bank 0} {$bank < 8} {incr bank} {
    lappend generics "DCCM_BANK${bank}_INIT_FILE=[file join $image_dir dccm_bank${bank}.mem]"
}
set_property generic $generics [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
# The TCMs are explicit BRAM macros, so implementation effort should be spent
# on the remaining high-fanout front-end/LSU control paths.  These directives
# are part of every frequency sign-off build, rather than relying on a lucky
# default-place seed.
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
update_compile_order -fileset sources_1
puts "SOCRV_PROJECT=[get_property DIRECTORY [current_project]]"
