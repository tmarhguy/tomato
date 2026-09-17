# Tomato — Vivado batch flow for nexys_top (Nexys A7-100T, xc7a100tcsg324-1)
#
# Why this exists: the open flow (yosys -flatten -abc9 -> nextpnr -> prjxray)
# is single-threaded and takes ~1h+. Vivado is multithreaded and does the
# same part in ~10 min. Use Vivado for iteration, open flow for sign-off.
#
# Vivado does NOT run on macOS. Run on a Linux box / VM with Vivado ML
# Standard (free, supports Artix-7) installed:
#
#   make -C hardware/fpga/core burn BOOT=tomato_os   # refresh rtl/burn/*.vh first
#   make -C hardware/fpga/core vivado                # synth+impl+bit, ~10 min
#   make -C hardware/fpga/core vivado-program        # flash via openFPGALoader
#
# Run from hardware/fpga/core so the rtl/board/wallpaper.mem relative path
# in videoout.v resolves. BUILD dir keeps it separate from the open flow.
#
# RTL notes:
# - (* ram_style/rom_style = "block" *) already Vivado-style, inferred as BRAM.
# - `include "burn/..." resolves via include_dirs=rtl (no TOMATO_SIM).
# - BUFG in nexys_top.v is Vivado-native; sim-only path is ifdef'd out.
set PART xc7a100tcsg324-1
set TOP nexys_top
set BUILD build/vivado
set JOBS 8

file mkdir $BUILD
set_param general.maxThreads $JOBS

# Fresh in-memory project (no .xpr litter in the repo).
create_project -in_memory -part $PART
set_property TOP $TOP [current_fileset]

# All RTL incl. board harness. Run from hardware/fpga/core so the
# rtl/board/wallpaper.mem relative path in videoout.v resolves.
add_files -norecurse [glob rtl/*.v rtl/board/*.v]
read_xdc constr/nexys.xdc
set_property include_dirs [list [file normalize rtl]] [current_fileset]

# QOR-neutral speed choices: default rebuilt hierarchy (NOT full-flatten like
# yosys -flatten), DSPs ON (open flow uses -nodsp only to dodge a nextpnr
# cascade-routing bug — Vivado routes DSP cascades fine).
synth_design -top $TOP -jobs $JOBS -retiming
write_checkpoint -force $BUILD/synth.dcp
report_timing_summary -file $BUILD/synth_timing.rpt
report_utilization -file $BUILD/synth_util.rpt

opt_design
place_design -jobs $JOBS
route_design -jobs $JOBS
report_timing_summary -file $BUILD/timing.rpt
report_utilization -file $BUILD/util.rpt
write_checkpoint -force $BUILD/routed.dcp
write_bitstream -force $BUILD/nexys_top.bit

puts "wrote $BUILD/nexys_top.bit"
