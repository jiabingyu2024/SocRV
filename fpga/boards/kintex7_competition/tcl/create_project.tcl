if {$argc < 3} {
    error "usage: create_project.tcl BUILD_DIR CODE_MEM DATA_MEM"
}

set script_dir [file normalize [file dirname [info script]]]
set repo_dir [file normalize [file join $script_dir .. .. .. ..]]
set build_dir [file normalize [lindex $argv 0]]
set code_mem [file normalize [lindex $argv 1]]
set data_mem [file normalize [lindex $argv 2]]
set part xc7k325tffg900-2

foreach required [list $code_mem $data_mem] {
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
        } elseif {[string match "+incdir+*" $line]} {
            # Include directories are applied to the Vivado fileset below.
            continue
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

proc set_ip_config_required {ip_name keys value} {
    set ip_obj [get_ips $ip_name]
    set props [list_property $ip_obj]
    foreach key $keys {
        set prop "CONFIG.$key"
        if {[lsearch -exact $props $prop] >= 0} {
            set_property $prop $value $ip_obj
            return
        }
    }
    error "IP $ip_name does not expose any required property in: $keys"
}

proc set_ip_config_optional {ip_name keys value} {
    set ip_obj [get_ips $ip_name]
    set props [list_property $ip_obj]
    foreach key $keys {
        set prop "CONFIG.$key"
        if {[lsearch -exact $props $prop] >= 0} {
            set_property $prop $value $ip_obj
            return
        }
    }
    puts "WARNING: IP $ip_name does not expose optional properties: $keys"
}

file mkdir $build_dir
create_project -force socrv $build_dir -part $part
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property verilog_define {SYNTHESIS} [current_fileset]
set_property include_dirs [list [file join $repo_dir rtl cpu include]] [current_fileset]

read_socrv_filelist $repo_dir [file join $repo_dir sim filelists fpga_kintex7.f]

# The core instantiates stable wrapper names.  Verilator supplies same-name
# behavioural models, while FPGA builds bind these generated Xilinx IPs.  Deep
# non-blocking, speed-optimized maximum-latency FPO pipelines keep their
# datapaths away from integer WNS/TNS.
create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name MUL_0
set_ip_config_required MUL_0 {PortAType port_a_type} {Signed}
set_ip_config_required MUL_0 {PortAWidth port_a_width} {33}
set_ip_config_required MUL_0 {PortBType port_b_type} {Signed}
set_ip_config_required MUL_0 {PortBWidth port_b_width} {33}
set_ip_config_required MUL_0 {MultType multiplier_type} {Parallel_Multiplier}
set_ip_config_required MUL_0 {Multiplier_Construction multiplier_construction} {Use_Mults}
set_ip_config_optional MUL_0 {OptGoal optimization_goal} {Speed}
set_ip_config_required MUL_0 {PipeStages pipeline_stages} {3}
set_ip_config_required MUL_0 {Use_Custom_Output_Width use_custom_output_width} {true}
set_ip_config_required MUL_0 {OutputWidthHigh output_width_high} {65}
set_ip_config_required MUL_0 {OutputWidthLow output_width_low} {0}

create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name DIV_0
set_ip_config_required DIV_0 {algorithm_type Algorithm_Type} {Radix2}
set_ip_config_required DIV_0 {dividend_and_quotient_width Dividend_and_Quotient_Width} {32}
set_ip_config_required DIV_0 {divisor_width Divisor_Width} {32}
set_ip_config_required DIV_0 {remainder_type Remainder_Type} {Remainder}
set_ip_config_required DIV_0 {operand_sign Operand_Sign} {Unsigned}
set_ip_config_required DIV_0 {clocks_per_division Clocks_Per_Division} {1}
set_ip_config_required DIV_0 {latency_configuration Latency_Configuration} {Manual}
set_ip_config_required DIV_0 {latency Latency} {34}
set_ip_config_required DIV_0 {FlowControl flow_control} {Blocking}

create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name FP_FMA_0
set_ip_config_required FP_FMA_0 {Operation_Type operation_type} {FMA}
set_ip_config_required FP_FMA_0 {Add_Sub_Value add_sub_value} {Add}
set_ip_config_required FP_FMA_0 {A_Precision_Type a_precision_type} {Single}
set_ip_config_required FP_FMA_0 {Result_Precision_Type result_precision_type} {Single}
set_ip_config_required FP_FMA_0 {Flow_Control flow_control} {NonBlocking}
set_ip_config_required FP_FMA_0 {Has_ARESETn has_aresetn} {true}
set_ip_config_required FP_FMA_0 {Has_RESULT_TREADY has_result_tready} {false}
set_ip_config_required FP_FMA_0 {C_Optimization c_optimization} {Speed_Optimized}
set_ip_config_required FP_FMA_0 {Maximum_Latency maximum_latency} {true}
set_ip_config_optional FP_FMA_0 {C_Rate c_rate} {1}

create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name FP_DIV_0
set_ip_config_required FP_DIV_0 {Operation_Type operation_type} {Divide}
set_ip_config_required FP_DIV_0 {A_Precision_Type a_precision_type} {Single}
set_ip_config_required FP_DIV_0 {Result_Precision_Type result_precision_type} {Single}
set_ip_config_required FP_DIV_0 {Flow_Control flow_control} {NonBlocking}
set_ip_config_required FP_DIV_0 {Has_ARESETn has_aresetn} {true}
set_ip_config_required FP_DIV_0 {Has_RESULT_TREADY has_result_tready} {false}
set_ip_config_required FP_DIV_0 {C_Optimization c_optimization} {Speed_Optimized}
set_ip_config_required FP_DIV_0 {Maximum_Latency maximum_latency} {true}
set_ip_config_optional FP_DIV_0 {C_Rate c_rate} {1}

create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name FP_SQRT_0
set_ip_config_required FP_SQRT_0 {Operation_Type operation_type} {Square_root}
set_ip_config_required FP_SQRT_0 {A_Precision_Type a_precision_type} {Single}
set_ip_config_required FP_SQRT_0 {Result_Precision_Type result_precision_type} {Single}
set_ip_config_required FP_SQRT_0 {Flow_Control flow_control} {NonBlocking}
set_ip_config_required FP_SQRT_0 {Has_ARESETn has_aresetn} {true}
set_ip_config_required FP_SQRT_0 {Has_RESULT_TREADY has_result_tready} {false}
set_ip_config_required FP_SQRT_0 {C_Optimization c_optimization} {Speed_Optimized}
set_ip_config_required FP_SQRT_0 {Maximum_Latency maximum_latency} {true}
set_ip_config_optional FP_SQRT_0 {C_Rate c_rate} {1}

read_xdc [file join $repo_dir fpga boards kintex7_competition constraints pins.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints clocks.xdc]
read_xdc [file join $repo_dir fpga boards kintex7_competition constraints cdc.xdc]

set_property top fpga_top [current_fileset]
set_property generic [list "CODE_MEM_FILE=$code_mem" "DATA_MEM_FILE=$data_mem"] [current_fileset]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
update_compile_order -fileset sources_1
puts "SOCRV_PROJECT=[get_property DIRECTORY [current_project]]"
