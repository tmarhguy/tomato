# Optional OpenSTA script (requires sta in OSS CAD Suite).
# Primary timing: reports/timing_est.txt from estimate_timing.py

read_liberty pdk/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog reports/synth_mapped.v
link_design alu-32b-final

create_clock -name clk -period 10.0 [get_ports CLK]
set_input_delay 0.0 -clock clk [all_inputs]
set_output_delay 0.0 -clock clk [all_outputs]

report_checks -path_delay max -digits 3
report_worst_slack -max
