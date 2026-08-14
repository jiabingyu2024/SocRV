if {$argc != 2} {
    error "usage: export_bram_map.tcl ROUTED_DCP OUTPUT_TSV"
}

set dcp_path [file normalize [lindex $argv 0]]
set out_path [file normalize [lindex $argv 1]]
open_checkpoint $dcp_path

set stream [open $out_path w]
puts $stream "# bram_map_version=1"
puts $stream "# part=[get_property PART [current_design]]"
puts $stream "# source_dcp=$dcp_path"
puts $stream [join {
    cell loc ref_name primitive_type
    read_width_a read_width_b write_width_a write_width_b
    ram_mode doa_reg dob_reg porta_layout portb_layout
} "\t"]

set selected_count 0
set all_brams [lsort [get_cells -hier -filter {PRIMITIVE_TYPE =~ BMEM.bram.*}]]
foreach cell $all_brams {
    if {![string match "*u_soc/core/mem/iccm/*" $cell] &&
        ![string match "*u_soc/core/mem/Gen_dccm_enable.dccm/*" $cell]} {
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
puts "SOCRV_PART=[get_property PART [current_design]]"
puts "SOCRV_BRAM_MAP=$out_path"
puts "SOCRV_BRAM_COUNT=$selected_count"
if {$selected_count != 48} {
    error "expected 48 ICCM/DCCM BRAM cells, got $selected_count"
}
close_design
