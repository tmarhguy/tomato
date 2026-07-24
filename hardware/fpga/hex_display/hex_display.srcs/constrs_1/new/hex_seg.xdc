set_property IOSTANDARD LVCMOS33 [get_ports {data_out[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {data_out[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {en_out[0]}]

set_property PACKAGE_PIN L18 [get_ports {data_out[6]}]

set_property PACKAGE_PIN T11 [get_ports {data_out[5]}]

set_property PACKAGE_PIN T10 [get_ports {data_out[0]}]

set_property PACKAGE_PIN R10 [get_ports {data_out[1]}]

set_property PACKAGE_PIN K16 [get_ports {data_out[2]}]

set_property PACKAGE_PIN K13 [get_ports {data_out[3]}]

set_property PACKAGE_PIN P15 [get_ports {data_out[4]}]

set_property PACKAGE_PIN U13 [get_ports {en_out[7]}]

set_property PACKAGE_PIN K2 [get_ports {en_out[6]}]

set_property PACKAGE_PIN T14 [get_ports {en_out[5]}]

set_property PACKAGE_PIN P14 [get_ports {en_out[4]}]

set_property PACKAGE_PIN J14 [get_ports {en_out[3]}]

set_property PACKAGE_PIN T9 [get_ports {en_out[2]}]

set_property PACKAGE_PIN J18 [get_ports {en_out[1]}]

set_property PACKAGE_PIN J17 [get_ports {en_out[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property IOSTANDARD LVCMOS33 [get_ports data_tog]

set_property IOSTANDARD LVCMOS33 [get_ports dp]

set_property IOSTANDARD LVCMOS33 [get_ports en_tog]

set_property PACKAGE_PIN E3 [get_ports clk]

create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

set_property PACKAGE_PIN J15 [get_ports data_tog]

set_property PACKAGE_PIN H15 [get_ports dp]

set_property PACKAGE_PIN L16 [get_ports en_tog]
