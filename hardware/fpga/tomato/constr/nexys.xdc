# Nexys A7-100T — Tomato (nexys_top)
# Part: xc7a100tcsg324-1
#
# Vivado:
#   Add sources: rtl/*.v   Include dir: rtl/
#   Add this constraints file
#   Set top: nexys_top
#
# Port ↔ pin completeness vs rtl/nexys_top.v:
#   clk cpu_resetn btn{c,u,l,r,d} sw[3:0] led[7:0]
#   seg[6:0] an[7:0] dp  vga_{r,g,b}[3:0] vga_hs vga_vs
#
# Bitstream authority: hardware/fpga/core/ (core.xpr + core.srcs/.../nexys.xdc).
# That XDC closes at 125 ns (8 MHz) analysis; board OSC is still 100 MHz.

## -------------------------------------------------------------------------
## Device / bitstream (Artix-7)
## -------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

## -------------------------------------------------------------------------
## Clock — 100 MHz aspirational analysis (core/ closed at 125 ns / 8 MHz)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## -------------------------------------------------------------------------
## Reset — Digilent CPU_RESETN (HIGH at rest, LOW when pressed)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports cpu_resetn]

## -------------------------------------------------------------------------
## Pushbuttons → Tomato IN keycodes (OS menu)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports btnc]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports btnu]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports btnl]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports btnr]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports btnd]
set_property PULLDOWN true [get_ports {btnc btnu btnl btnr btnd}]

## -------------------------------------------------------------------------
## Switches (mirrored on LEDs; boot image is synth-time)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]

## -------------------------------------------------------------------------
## LEDs ← OUT | SW
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

## -------------------------------------------------------------------------
## 7-segment — CA..CG = seg[0..6], AN0..AN7, DP (last reg writeback)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports dp]
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {an[3]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {an[4]}]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {an[5]}]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {an[6]}]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports {an[7]}]

## -------------------------------------------------------------------------
## VGA 640×480 (4-bit RGB + HS/VS)
## -------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports {vga_r[0]}]
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports {vga_r[1]}]
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports {vga_r[2]}]
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports {vga_r[3]}]
set_property -dict { PACKAGE_PIN C6  IOSTANDARD LVCMOS33 } [get_ports {vga_g[0]}]
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports {vga_g[1]}]
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports {vga_g[2]}]
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports {vga_g[3]}]
set_property -dict { PACKAGE_PIN B7  IOSTANDARD LVCMOS33 } [get_ports {vga_b[0]}]
set_property -dict { PACKAGE_PIN C7  IOSTANDARD LVCMOS33 } [get_ports {vga_b[1]}]
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports {vga_b[2]}]
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports {vga_b[3]}]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports vga_hs]
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports vga_vs]
