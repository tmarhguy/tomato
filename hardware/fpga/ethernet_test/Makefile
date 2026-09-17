TOP := ethernet_top
SRC := rtl/ethernet_top.v rtl/rmii_rx.v rtl/rmii_tx.v rtl/lan_min.v rtl/mdio_probe.v ../core/rtl/board/font_rom.v
YOSYS_LANG := -sv
XDC := constr/ethernet.xdc
# Internal RMII domain runs at 50MHz; pixel domain at 25MHz.
FREQ_MHZ := 50
ALL_NEEDS_FPGA := 1
.PHONY: all test
all: fpga
include ../common.mk
test:
	iverilog -g2012 -s rx_tb -o /tmp/tomato-ethernet-rx tb/rx_tb.v rtl/rmii_rx.v
	vvp -n /tmp/tomato-ethernet-rx

	iverilog -g2012 -s mdio_tb -o /tmp/tomato-ethernet-mdio tb/mdio_tb.v rtl/mdio_probe.v
	vvp -n /tmp/tomato-ethernet-mdio

	iverilog -g2012 -s tx_tb -o /tmp/tomato-ethernet-tx tb/tx_tb.v rtl/rmii_tx.v
	vvp -n /tmp/tomato-ethernet-tx

	iverilog -g2012 -s echo_tb -o /tmp/tomato-ethernet-echo tb/echo_tb.v rtl/lan_min.v rtl/rmii_tx.v rtl/rmii_rx.v
	vvp -n /tmp/tomato-ethernet-echo

	iverilog -g2012 -s arp_next_hop_tb -o /tmp/tomato-arp-next-hop tb/arp_next_hop_tb.v rtl/arp_next_hop.v
	vvp -n /tmp/tomato-arp-next-hop

	python3 tools/test_ethernet_pipeline.py
