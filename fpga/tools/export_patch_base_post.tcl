set project_dir [file normalize [get_property DIRECTORY [current_project]]]
# Vivado can evaluate a write_bitstream post hook with the run directory as
# the reported project directory.  Recover the actual project root in that
# case and take the bitstream path directly from the implementation run.
if {[file tail $project_dir] eq "impl_1" &&
    [file tail [file dirname $project_dir]] eq "socrv.runs"} {
    set project_dir [file dirname [file dirname $project_dir]]
}
set base_dir [file dirname $project_dir]
set out_path [file join $base_dir bram_map.tsv]
set temporary_path "${out_path}.tmp"
set run_dir [get_property DIRECTORY [current_run]]
if {$run_dir eq ""} {
    set run_dir [file join $project_dir socrv.runs impl_1]
}
set source_bit [file normalize [file join $run_dir fpga_top.bit]]

file delete -force $temporary_path
file delete -force $out_path
if {![file isfile $source_bit]} {
    error "generated bitstream does not exist: $source_bit"
}

set stream [open $temporary_path w]
puts $stream "# bram_map_version=1"
puts $stream "# part=[get_property PART [current_design]]"
puts $stream "# source_bit=$source_bit"
puts $stream [join {
    cell loc ref_name primitive_type
    read_width_a read_width_b write_width_a write_width_b
    ram_mode doa_reg dob_reg porta_layout portb_layout
} "\t"]

set selected_count 0
set all_brams [lsort [get_cells -hier -filter {REF_NAME =~ RAMB*}]]
foreach cell $all_brams {
    if {![string match "*u_soc/core/mem/iccm/*" $cell] &&
        ![string match "*u_soc/core/mem/Gen_dccm_enable.dccm/*" $cell] &&
        ![string match "*u_soc/core/u_memory/iccm/*" $cell] &&
        ![string match "*u_soc/core/u_memory/Gen_dccm_enable.dccm/*" $cell]} {
        continue
    }

    set fields [list $cell]
    foreach property {
        LOC REF_NAME PRIMITIVE_TYPE
        READ_WIDTH_A READ_WIDTH_B WRITE_WIDTH_A WRITE_WIDTH_B
        RAM_MODE DOA_REG DOB_REG
        MEM.PORTA.DATA_BIT_LAYOUT MEM.PORTB.DATA_BIT_LAYOUT
    } {
        lappend fields [get_property $property $cell]
    }
    puts $stream [join $fields "\t"]
    incr selected_count
}
close $stream

if {$selected_count != 48} {
    file delete -force $temporary_path
    error "expected 48 ICCM/DCCM BRAM cells, got $selected_count"
}

file rename -force $temporary_path $out_path
puts "SOCRV_PATCH_BASE=$base_dir"
puts "SOCRV_BRAM_MAP=$out_path"
puts "SOCRV_BRAM_COUNT=$selected_count"
