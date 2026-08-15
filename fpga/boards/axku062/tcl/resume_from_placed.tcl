if {$argc != 2} {
    error "usage: resume_from_placed.tcl PLACED_DCP OUTPUT_DIR"
}

set placed_dcp [file normalize [lindex $argv 0]]
set output_dir [file normalize [lindex $argv 1]]
file mkdir $output_dir

open_checkpoint $placed_dcp
route_design -directive Explore

set routed_dcp [file join $output_dir fpga_top_routed.dcp]
set timing_report [file join $output_dir post_route_timing_summary.rpt]
set drc_report [file join $output_dir post_route_drc.rpt]
set bitstream [file join $output_dir fpga_top.bit]

write_checkpoint -force $routed_dcp
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 -input_pins -file $timing_report
report_drc -file $drc_report

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
write_bitstream -force $bitstream

puts "SOCRV_FALLBACK_ROUTED_DCP=$routed_dcp"
puts "SOCRV_FALLBACK_BITSTREAM=$bitstream"
close_design
