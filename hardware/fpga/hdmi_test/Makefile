# hdmi_test — 640x480 nominal-60-Hz (~59.52 Hz) colour-bar bring-up
# out of the 12-bit DVI PMOD, with no Vivado anywhere in the flow.
#
#   make setup                    # one-time: OSS CAD Suite + prjxray bitgen
#   make                          # synth → P&R → bit (auto-enters toolchain)
#   make program                  # flash the board (same auto-enter)
#
# A bare `make` here builds the bitstream, so common.mk re-enters through
# scripts/env.sh when the nix shell is not already active.
#
# Kept as the reference the core's board layer is checked against. If video
# ever breaks after a core change, build this: it isolates PMOD wiring and
# pixel timing from everything the CPU does.

TOP        := main
SRC        := rtl/main.sv
XDC        := constr/hdmi.xdc
FREQ_MHZ   := 100
YOSYS_LANG := -sv
ALL_NEEDS_FPGA := 1

.PHONY: all
all: fpga

include ../common.mk
