set project_hint [file normalize [get_property DIRECTORY [current_project]]]
set source_candidates [list \
    [file join $project_hint socrv.runs impl_1 fpga_top.bit] \
    [file join $project_hint fpga_top.bit]]

set run_object ""
if {[catch {set run_object [current_run]}]} {
    set run_object ""
}
if {$run_object ne ""} {
    set run_dir [file normalize [get_property DIRECTORY $run_object]]
    lappend source_candidates [file join $run_dir fpga_top.bit]
}

set source_bit ""
foreach candidate $source_candidates {
    if {[file isfile $candidate]} {
        set source_bit [file normalize $candidate]
        break
    }
}
if {$source_bit eq ""} {
    error "generated bitstream does not exist; checked: $source_candidates"
}

set runs_dir [file dirname [file dirname $source_bit]]
set project_dir [file dirname $runs_dir]
set base_dir [file dirname $project_dir]
set out_path [file join $base_dir bram_map.tsv]
set temporary_path "${out_path}.[pid].[clock clicks].tmp"
set stream ""
set selected_count 0

if {[catch {
    set stream [open $temporary_path {WRONLY CREAT EXCL}]
    puts $stream "# bram_map_version=1"
    puts $stream "# part=[get_property PART [current_design]]"
    puts $stream "# source_bit=$source_bit"
    puts $stream [join {
        cell loc ref_name primitive_type
        read_width_a read_width_b write_width_a write_width_b
        ram_mode doa_reg dob_reg porta_layout portb_layout
    } "\t"]

    set all_brams [lsort [get_cells -hier -filter {REF_NAME =~ RAMB*}]]
    foreach cell $all_brams {
        set is_iccm [regexp {/iccm/(lane[0-3]_reg_(bram_)?[0-7]|lane_q_reg\[[0-3]\]_[0-7])$} $cell]
        set is_dccm [regexp {/Gen_dccm_enable\.dccm/dccm_bank_gen\[[0-7]\]\.bank_mem_reg_(bram_)?[01]$} $cell]
        if {!$is_iccm && !$is_dccm} {
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
    set stream ""

    if {$selected_count != 48} {
        error "expected 48 ICCM/DCCM BRAM cells, got $selected_count"
    }

    file rename -force $temporary_path $out_path
} export_error export_options]} {
    if {$stream ne ""} {
        catch {close $stream}
    }
    catch {file delete -force $temporary_path}
    return -options $export_options $export_error
}

puts "SOCRV_PATCH_BASE=$base_dir"
puts "SOCRV_BRAM_MAP=$out_path"
puts "SOCRV_BRAM_COUNT=$selected_count"
