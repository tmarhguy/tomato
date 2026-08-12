# Tomato FPGA — Icarus simulation + FPGA burn packaging
export PATH := $(HOME)/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$(PATH)

# -I rtl  → `include "burn/..." resolves for control.v / main.v
# -DTOMATO_SIM → leave dmem empty so TBs can $readmemh their programs
IVERILOG ?= iverilog -g2005 -I rtl -DTOMATO_SIM
IVERILOG_BURN ?= iverilog -g2005 -I rtl
VVP      ?= vvp
SIM      ?= sim
RTL      := $(wildcard rtl/*.v)
ROOT     := $(abspath ../../..)
ASM      := python3 $(ROOT)/software/assembler.py
GENMC    := python3 $(ROOT)/tools/gen_microcode_v1.py
GENBURN  := python3 $(ROOT)/tools/gen_fpga_burn.py
BOOT     ?= tomato_os
ASM_SRC  := $(ROOT)/software/asm

PROG_MEM := tb/mem/counter.mem tb/mem/fib.mem tb/mem/collatz.mem tb/mem/call.mem tb/mem/bytes.mem \
	tb/mem/ecall.mem tb/mem/io.mem tb/mem/softops.mem tb/mem/kb_mmio.mem

TBS := shift lane wb bus sp regs ir pc vga muldiv alu control hex vgatiming main counter fidelity \
	kb_io burn_boot

.PHONY: all test clean asm microcode pack-isa lean-isa burn burn-check progs $(TBS)

all: test

$(SIM):
	mkdir -p $(SIM)

microcode:
	$(GENMC)

pack-isa lean-isa:
	$(GENMC) --pack-rom
	$(GENBURN) --boot $(BOOT)
	@echo "ISA packed (tomato.v1.csv) + FPGA burn refreshed (boot=$(BOOT))"

burn: microcode
	$(GENBURN) --boot $(BOOT)
	@echo "FPGA burn ready: boot=$(BOOT)  (see rtl/VIVADO.md)"

burn-check: microcode
	$(GENMC) --check

asm: $(PROG_MEM)

tb/mem/counter.mem: $(ASM_SRC)/counter.s
	$(ASM) $< -o $@

tb/mem/fib.mem: $(ASM_SRC)/fib.s
	$(ASM) $< -o $@

tb/mem/collatz.mem: $(ASM_SRC)/collatz.s
	$(ASM) $< -o $@

tb/mem/call.mem: $(ASM_SRC)/call.s
	$(ASM) $< -o $@

tb/mem/bytes.mem: $(ASM_SRC)/bytes.s
	$(ASM) $< -o $@

tb/mem/ecall.mem: $(ASM_SRC)/ecall.s
	$(ASM) $< -o $@

tb/mem/io.mem: $(ASM_SRC)/io.s
	$(ASM) $< -o $@

tb/mem/kb_mmio.mem: $(ASM_SRC)/kb_mmio.s
	$(ASM) $< -o $@

tb/mem/softops.mem: $(ASM_SRC)/softops.s
	$(ASM) $< -o $@

$(SIM)/shift_tb.vvp: rtl/shift.v tb/shift_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/shift.v tb/shift_tb.v

$(SIM)/lane_tb.vvp: rtl/lane.v tb/lane_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/lane.v tb/lane_tb.v

$(SIM)/wb_tb.vvp: rtl/wb.v tb/wb_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/wb.v tb/wb_tb.v

$(SIM)/bus_tb.vvp: rtl/bus.v tb/bus_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/bus.v tb/bus_tb.v

$(SIM)/sp_tb.vvp: rtl/sp.v tb/sp_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/sp.v tb/sp_tb.v

$(SIM)/regs_tb.vvp: rtl/regs.v tb/regs_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/regs.v tb/regs_tb.v

$(SIM)/ir_tb.vvp: rtl/ir.v tb/ir_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/ir.v tb/ir_tb.v

$(SIM)/pc_tb.vvp: rtl/pc.v tb/pc_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/pc.v tb/pc_tb.v

$(SIM)/vga_tb.vvp: rtl/vga.v tb/vga_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/vga.v tb/vga_tb.v

$(SIM)/muldiv_tb.vvp: rtl/shift.v rtl/muldiv.v tb/muldiv_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/shift.v rtl/muldiv.v tb/muldiv_tb.v

$(SIM)/alu_tb.vvp: rtl/alu.v tb/alu_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/alu.v tb/alu_tb.v

$(SIM)/control_tb.vvp: rtl/control.v tb/control_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/control.v tb/control_tb.v

$(SIM)/hex_tb.vvp: rtl/hex.v tb/hex_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/hex.v tb/hex_tb.v

$(SIM)/vgatiming_tb.vvp: rtl/vgatiming.v tb/vgatiming_tb.v | $(SIM)
	$(IVERILOG) -o $@ rtl/vgatiming.v tb/vgatiming_tb.v

$(SIM)/main_tb.vvp: $(RTL) tb/main_tb.v | $(SIM)
	$(IVERILOG) -o $@ $(RTL) tb/main_tb.v

$(SIM)/counter_tb.vvp: $(RTL) tb/counter_tb.v | $(SIM)
	$(IVERILOG) -o $@ $(RTL) tb/counter_tb.v

$(SIM)/fidelity_tb.vvp: $(RTL) tb/fidelity_tb.v | $(SIM)
	$(IVERILOG) -o $@ $(RTL) tb/fidelity_tb.v

$(SIM)/burn_boot_tb.vvp: $(RTL) tb/burn_boot_tb.v rtl/burn/dmem_init.vh | $(SIM)
	$(IVERILOG_BURN) -o $@ $(RTL) tb/burn_boot_tb.v

$(SIM)/kb_io_tb.vvp: $(RTL) tb/kb_io_tb.v tb/mem/io.mem | $(SIM)
	$(IVERILOG) -o $@ $(RTL) tb/kb_io_tb.v

$(SIM)/prog_tb.vvp: $(RTL) tb/prog_tb.v asm | $(SIM)
	$(IVERILOG) -o $@ $(RTL) tb/prog_tb.v

define RUN_TB
	@echo "=== $(1) ==="
	@$(VVP) $(SIM)/$(1)_tb.vvp $(2) | tee $(SIM)/$(1)_tb.log
	@grep -q '^PASS:' $(SIM)/$(1)_tb.log
	@! grep -q '^FAIL:' $(SIM)/$(1)_tb.log
endef

test: burn-check $(foreach t,$(TBS),$(SIM)/$(t)_tb.vvp) $(SIM)/prog_tb.vvp
	$(call RUN_TB,shift)
	$(call RUN_TB,lane)
	$(call RUN_TB,wb)
	$(call RUN_TB,bus)
	$(call RUN_TB,sp)
	$(call RUN_TB,regs)
	$(call RUN_TB,ir)
	$(call RUN_TB,pc)
	$(call RUN_TB,vga)
	$(call RUN_TB,muldiv)
	$(call RUN_TB,alu)
	$(call RUN_TB,control)
	$(call RUN_TB,hex)
	$(call RUN_TB,vgatiming)
	$(call RUN_TB,main)
	$(call RUN_TB,counter)
	$(call RUN_TB,fidelity)
	$(call RUN_TB,kb_io)
	$(call RUN_TB,burn_boot)
	@echo "=== prog counter ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=counter +EXPECT_R1=10 +EXPECT_DISP=10 | tee $(SIM)/prog_counter.log
	@grep -q '^PASS:' $(SIM)/prog_counter.log
	@echo "=== prog fib ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=fib +EXPECT_R1=21 +EXPECT_R6=21 +EXPECT_DISP=21 | tee $(SIM)/prog_fib.log
	@grep -q '^PASS:' $(SIM)/prog_fib.log
	@echo "=== prog collatz ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=collatz +EXPECT_R1=111 +EXPECT_DISP=111 | tee $(SIM)/prog_collatz.log
	@grep -q '^PASS:' $(SIM)/prog_collatz.log
	@echo "=== prog call ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=call +EXPECT_R1=99 +EXPECT_R2=42 +EXPECT_DISP=99 | tee $(SIM)/prog_call.log
	@grep -q '^PASS:' $(SIM)/prog_call.log
	@echo "=== prog bytes ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=bytes +EXPECT_R1=90 +EXPECT_R2=-128 +EXPECT_DISP=-128 | tee $(SIM)/prog_bytes.log
	@grep -q '^PASS:' $(SIM)/prog_bytes.log
	@echo "=== prog ecall ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=ecall +EXPECT_R1=42 +EXPECT_DISP=42 | tee $(SIM)/prog_ecall.log
	@grep -q '^PASS:' $(SIM)/prog_ecall.log
	@echo "=== prog softops ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=softops +EXPECT_R1=129 +EXPECT_R6=129 +EXPECT_DISP=129 | tee $(SIM)/prog_softops.log
	@grep -q '^PASS:' $(SIM)/prog_softops.log
	@echo "=== prog io ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=io +EXPECT_R1=65 +KB=65 +EXPECT_DISP=65 | tee $(SIM)/prog_io.log
	@grep -q '^PASS:' $(SIM)/prog_io.log
	@echo "=== prog kb_mmio ==="
	@$(VVP) $(SIM)/prog_tb.vvp +PROG=kb_mmio +EXPECT_R1=126 +EXPECT_R2=1 +KB=126 +EXPECT_DISP=1 | tee $(SIM)/prog_kb_mmio.log
	@grep -q '^PASS:' $(SIM)/prog_kb_mmio.log
	@echo "All FPGA Tomato tests passed (units + asm programs)."

progs: $(SIM)/prog_tb.vvp
	$(VVP) $< +PROG=counter +EXPECT_R1=10 +EXPECT_DISP=10
	$(VVP) $< +PROG=fib +EXPECT_R1=21 +EXPECT_R6=21 +EXPECT_DISP=21
	$(VVP) $< +PROG=collatz +EXPECT_R1=111 +EXPECT_DISP=111
	$(VVP) $< +PROG=call +EXPECT_R1=99 +EXPECT_R2=42 +EXPECT_DISP=99
	$(VVP) $< +PROG=bytes +EXPECT_R1=90 +EXPECT_R2=-128 +EXPECT_DISP=-128
	$(VVP) $< +PROG=ecall +EXPECT_R1=42 +EXPECT_DISP=42
	$(VVP) $< +PROG=softops +EXPECT_R1=129 +EXPECT_R6=129 +EXPECT_DISP=129
	$(VVP) $< +PROG=io +EXPECT_R1=65 +KB=65 +EXPECT_DISP=65
	$(VVP) $< +PROG=kb_mmio +EXPECT_R1=126 +EXPECT_R2=1 +KB=126 +EXPECT_DISP=1

$(TBS): %: $(SIM)/%_tb.vvp
	$(VVP) $<

clean:
	rm -rf $(SIM)
	rm -f tb/mem/fib.mem tb/mem/collatz.mem tb/mem/call.mem tb/mem/bytes.mem
	rm -f tb/mem/ecall.mem tb/mem/io.mem tb/mem/softops.mem tb/mem/kb_mmio.mem
