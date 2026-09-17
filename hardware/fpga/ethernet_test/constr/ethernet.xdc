## Nexys A7-100T - 12-bit DVI PMOD v1.1b on JC + JD
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz board clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]
# NOTE: net_clk (sys/2, 50MHz RMII) and pix_clk (sys/4, 25MHz video) have no
# generated-clock constraints because nextpnr-xilinx ignores
# create_generated_clock (it says so in the log). They are checked against
# the Makefile FREQ_MHZ target instead, so keep that target honest and keep
# net_clk logic pipelined with margin (see lan_min.v timing notes).

set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports cpu_resetn]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]

## JC = R/G (PMOD1A)
## pin1 R3, pin2 R1, pin3 G3, pin4 G1, pin7 R2, pin8 R0, pin9 G2, pin10 G0
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[3]}]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[1]}]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[3]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[1]}]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[2]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[0]}]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[2]}]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[0]}]

## JD = B + CLK/HS/VS/DE (PMOD1B)
## pin1 B3, pin2 CLK, pin3 B0, pin4 HS, pin7 B2, pin8 B1, pin9 DE, pin10 VS
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[3]}]
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_clk]
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[0]}]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_hs]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[2]}]
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[1]}]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_de]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_vs]
set_property -dict { PACKAGE_PIN C9 IOSTANDARD LVCMOS33 } [get_ports {eth_mdc}]
set_property -dict { PACKAGE_PIN A9 IOSTANDARD LVCMOS33 } [get_ports {eth_mdio}]
set_property -dict { PACKAGE_PIN B3 IOSTANDARD LVCMOS33 } [get_ports {eth_rstn}]
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports {eth_crsdv}]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports {eth_rxerr}]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[0]}]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[1]}]
set_property -dict { PACKAGE_PIN B9 IOSTANDARD LVCMOS33 } [get_ports {eth_txen}]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[0]}]
set_property -dict { PACKAGE_PIN A8 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[1]}]
set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports {eth_refclk}]
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports {uart_tx}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
