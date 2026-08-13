# Program Nexys A7 with existing nexys_top.bit
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [lindex [get_hw_devices] 0]
refresh_hw_device -update_hw_probes false [current_hw_device]
set_property PROGRAM.FILE {C:/Users/Tyrone/OneDrive/Documents/GitHub/tomato/hardware/fpga/core/core.runs/impl_1/nexys_top.bit} [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]
puts "PROGRAM_OK device=[current_hw_device]"
close_hw_manager
exit 0
