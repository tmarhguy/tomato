## Tomato — Nexys A7-100T (xc7a100tcsg324-1)
## Top: nexys_top. Video leaves on the 12-bit DVI PMOD across JC + JD.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ---- 100 MHz board oscillator -------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## ---- CPU_RESETN (red button, high at rest) -------------------------------
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports cpu_resetn]

## ---- D-pad: stands in for a keyboard (rtl/board/keypad.v) ----------------
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports btnc]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports btnu]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports btnd]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports btnl]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports btnr]

## ---- Slide switches ------------------------------------------------------
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
set_property -dict { PACKAGE_PIN T8  IOSTANDARD LVCMOS18 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS18 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## ---- LEDs ----------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## ---- Seven-segment displays ----------------------------------------------
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

## ---- 12-bit DVI PMOD v1.1b -----------------------------------------------
## Identical mapping to hardware/fpga/hdmi_test — the bring-up that lit a screen.
## JC = R/G (PMOD1A): pin1 R3, pin2 R1, pin3 G3, pin4 G1, pin7 R2, pin8 R0, pin9 G2, pin10 G0
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[3]}]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[1]}]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[3]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[1]}]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[2]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[0]}]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[2]}]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[0]}]

## JD = B + CLK/HS/VS/DE (PMOD1B): pin1 B3, pin2 CLK, pin3 B0, pin4 HS, pin7 B2, pin8 B1, pin9 DE, pin10 VS
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[3]}]
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_clk]
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[0]}]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_hs]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[2]}]
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[1]}]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_de]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_vs]
