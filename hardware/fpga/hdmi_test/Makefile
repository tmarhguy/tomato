# hdmi_test — the bring-up that first lit a monitor: 640x480@60 colour bars
# out of the 12-bit DVI PMOD, with no Vivado anywhere in the flow.
#
#   make setup                    # one-time: OSS CAD Suite + prjxray bitgen
#   ../scripts/env.sh make        # synth → P&R → bit
#   ../scripts/env.sh make program
#
# Kept as the reference the core's board layer is checked against. If video
# ever breaks after a core change, build this: it isolates PMOD wiring and
# pixel timing from everything the CPU does.

TOP        := main
SRC        := rtl/main.sv
XDC        := constr/hdmi.xdc
FREQ_MHZ   := 100
YOSYS_LANG := -sv

.PHONY: all
all: fpga

include ../common.mk
