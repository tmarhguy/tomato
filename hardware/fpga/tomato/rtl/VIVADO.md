# Vivado bring-up — Tomato FPGA (Nexys A7)
#
# Completeness checklist
# ----------------------
# [x] Microcode opcodes burned in control.v (rtl/burn/mc_*.vh)
# [x] Boot program burned in main.v (rtl/burn/dmem_init.vh) — default Tomato OS
# [x] All demo images in rtl/tomato_boot_rom.v + dmem_*.vh
# [x] Board top nexys_top.v (buttons→IN, LEDs←OUT)
# [x] constr/nexys.xdc — clk, reset, btns, sw, leds, 7-seg (seg/an/dp), VGA
# [x] Bitstream config (CFGBVS, CONFIG_VOLTAGE, COMPRESS)
# [x] Solidified ISA: make pack-isa  (~51 burn ops; unused ROM = NOP; no growth phantoms)
# [x] Icarus proof: make burn-boot
#
# Before Vivado:
#   make pack-isa          # tomato.v1.csv + microcode + rtl/burn
#   make burn-boot         # prove burned OS boots
#
# Vivado:
#   1. Part xc7a100tcsg324-1
#   2. Add rtl/*.v ; include dir = rtl/
#   3. Constraints: constr/nexys.xdc
#   4. Top: nexys_top
#   5. Bitstream → program
#
# Boot image (re-synth):
#   make burn BOOT=counter|tomato_os|snake|bounce|sudoku|tetris
#
# Buttons: BTNL=1 BTNU=2 BTNR=3 BTNC=0(quit) BTND=q
# LEDs: last OUT | SW[3:0]
# 7-seg: last register writeback
