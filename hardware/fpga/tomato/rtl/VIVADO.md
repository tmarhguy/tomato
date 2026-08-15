# Vivado bring-up — Tomato FPGA (Nexys A7)
#
# Completeness checklist
# ----------------------
# [x] Microcode opcodes burned in control.v (rtl/burn/mc_*.vh)
# [x] Boot program burned in main.v (rtl/burn/dmem_init.vh) — default Tomato OS
# [x] All demo images in rtl/tomato_boot_rom.v + dmem_*.vh
# [x] Board top nexys_top.v (buttons→IN, LEDs←OUT)
# [x] constr/nexys.xdc — clk, cpu_resetn (active-low), btns, sw, leds, 7-seg, VGA
# [x] nexys_top inverts Digilent CPU_RESETN → active-high core reset
# [x] Bitstream config (CFGBVS, CONFIG_VOLTAGE, COMPRESS)
# [x] Solidified ISA: make pack-isa  (~51 burn ops; unused ROM = NOP; no growth phantoms)
# [x] Icarus proof: make burn-boot
# [x] Vivado project: hardware/fpga/core/core.xpr (authority)
# [x] Timing that closed: 125 ns / 8 MHz analysis (see core/.../nexys.xdc)
#
# Before Vivado:
#   make pack-isa          # tomato.v1.csv + microcode + rtl/burn
#   make burn-boot         # prove burned OS boots
#
# Vivado (preferred):
#   Open hardware/fpga/core/core.xpr
#   Part xc7a100tcsg324-1 · top nexys_top · constrs = core.srcs/constrs_1/nexys.xdc
#   Bitstream → program_bit.tcl
#
# Ad-hoc (not preferred):
#   1. Part xc7a100tcsg324-1
#   2. Add rtl/*.v ; include dir = rtl/
#   3. Constraints: prefer core/.../nexys.xdc (8 MHz closed); tomato/constr is aspirational 100 MHz
#   4. Top: nexys_top
#   5. Bitstream → program
#
# Boot image (re-synth):
#   make burn BOOT=counter|tomato_os|snake|bounce|sudoku|tetris
#
# Buttons: BTNL=1 BTNU=2 BTNR=3 BTNC=0(quit) BTND=q
# LEDs: last OUT | SW[3:0]
# 7-seg: last WB mux value during execute
