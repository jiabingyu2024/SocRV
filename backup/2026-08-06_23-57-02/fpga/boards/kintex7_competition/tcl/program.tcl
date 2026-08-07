if {$argc < 1} {
    error "usage: program.tcl BITSTREAM ?HW_SERVER_URL?"
}
set bitstream [file normalize [lindex $argv 0]]
set server_url [expr {$argc >= 2 ? [lindex $argv 1] : "localhost:3121"}]
if {![file exists $bitstream]} {
    error "bitstream does not exist: $bitstream"
}
open_hw_manager
connect_hw_server -url $server_url
open_hw_target
set device [lindex [get_hw_devices xc7k325t_0] 0]
if {$device eq ""} {
    error "xc7k325t_0 was not found on the hardware target"
}
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device $device
puts "SOCRV_PROGRAMMED=$bitstream"
close_hw_manager
