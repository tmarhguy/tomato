# Tomato — 130-billion vector gauntlet (FPGA dual-LUT ALU)
#
# DUT is a *copy* of hardware/fpga/core/rtl/alu.v. Do not edit core from here.
#   make sync          refresh the copy from core
#   make check-sync    fail if the copy drifted

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CORE_ALU  := $(abspath $(ROOT)/../../hardware/fpga/core/rtl/alu.v)
RTL       := $(ROOT)/rtl
FORMAL    := $(ROOT)/formal
VDIR      := $(ROOT)/verilator
OBJ       := $(ROOT)/obj
RESULTS   := $(ROOT)/results

OSS_BIN   := $(abspath $(ROOT)/../../hardware/fpga/.tools/oss-cad-suite/bin)
export PATH := $(OSS_BIN):$(PATH)

VERILATOR ?= verilator
SBY       ?= sby
CXXFLAGS  ?= -O3 -std=c++17

VECTORS_SMOKE ?= 1000000
VECTORS_10B   ?= 10000000000
VECTORS_130B  ?= 130000000000
SEED          ?= 1

.PHONY: all help sync check-sync formal formal_1b formal_8b formal_32b \
        build build8 build32 smoke core10b slice130b claim clean results-dir

all: formal smoke

help:
	@echo "Tomato ALU gauntlet (FPGA dual-LUT copy — does not touch core/)"
	@echo "  make sync          copy alu.v from hardware/fpga/core"
	@echo "  make check-sync    assert copy matches core"
	@echo "  make formal        SymbiYosys prove 1b + 8b + 32b"
	@echo "  make smoke         Verilator 1e6 vectors (8b + 32b)"
	@echo "  make core10b       Verilator 10e9 on alu8b (ALU core)"
	@echo "  make slice130b     Verilator 130e9 on alu (32-bit slice)"
	@echo "  make claim         formal + core10b + slice130b"
	@echo "  make clean         remove obj/ and formal run dirs"

sync:
	@mkdir -p $(RTL)
	cp $(CORE_ALU) $(RTL)/alu.v
	@echo "synced $(RTL)/alu.v from core"

check-sync:
	@test -f $(CORE_ALU) || (echo "missing core DUT: $(CORE_ALU)"; exit 1)
	@test -f $(RTL)/alu.v || (echo "missing gauntlet copy — run: make sync"; exit 1)
	@diff -q $(CORE_ALU) $(RTL)/alu.v
	@echo "OK: gauntlet rtl/alu.v matches hardware/fpga/core/rtl/alu.v"

formal_1b:
	cd $(FORMAL) && $(SBY) -f alu1b_verify.sby

formal_8b:
	cd $(FORMAL) && $(SBY) -f alu8b_verify.sby

formal_32b:
	cd $(FORMAL) && $(SBY) -f alu32_verify.sby
	cd $(FORMAL) && $(SBY) -f alu32_top_verify.sby

formal: check-sync formal_1b formal_8b formal_32b
	@echo "=== GAUNTLET FORMAL PASS ==="

$(OBJ):
	mkdir -p $(OBJ)

results-dir:
	mkdir -p $(RESULTS)

$(OBJ)/alu8/Valu8b.mk: $(RTL)/alu.v $(VDIR)/sim_main_8b.cpp $(VDIR)/golden.h | $(OBJ)
	$(VERILATOR) --cc --exe -O3 --x-assign fast --x-initial fast \
	  --top-module alu8b -o alu8_gauntlet \
	  -Mdir $(OBJ)/alu8 \
	  -CFLAGS "$(CXXFLAGS) -I$(VDIR)" \
	  $(RTL)/alu.v $(VDIR)/sim_main_8b.cpp

$(OBJ)/alu32/Valu.mk: $(RTL)/alu.v $(VDIR)/sim_main.cpp $(VDIR)/golden.h | $(OBJ)
	$(VERILATOR) --cc --exe -O3 --x-assign fast --x-initial fast \
	  --top-module alu -o alu_gauntlet \
	  -Mdir $(OBJ)/alu32 \
	  -CFLAGS "$(CXXFLAGS) -I$(VDIR)" \
	  $(RTL)/alu.v $(VDIR)/sim_main.cpp

$(OBJ)/alu8/alu8_gauntlet: $(OBJ)/alu8/Valu8b.mk
	$(MAKE) -C $(OBJ)/alu8 -f Valu8b.mk

$(OBJ)/alu32/alu_gauntlet: $(OBJ)/alu32/Valu.mk
	$(MAKE) -C $(OBJ)/alu32 -f Valu.mk

build8: $(OBJ)/alu8/alu8_gauntlet
build32: $(OBJ)/alu32/alu_gauntlet
build: build8 build32

smoke: check-sync build results-dir
	$(OBJ)/alu8/alu8_gauntlet $(VECTORS_SMOKE) $(SEED) | tee $(RESULTS)/smoke_8b.txt
	$(OBJ)/alu32/alu_gauntlet $(VECTORS_SMOKE) $(SEED) | tee $(RESULTS)/smoke_32b.txt
	@echo "=== GAUNTLET SMOKE PASS ==="

core10b: check-sync build8 results-dir
	$(OBJ)/alu8/alu8_gauntlet $(VECTORS_10B) $(SEED) | tee $(RESULTS)/core_10b.txt
	@grep -q '^PASS alu8b' $(RESULTS)/core_10b.txt
	@echo "=== 10B ALU-CORE PASS ==="

slice130b: check-sync build32 results-dir
	$(OBJ)/alu32/alu_gauntlet $(VECTORS_130B) $(SEED) | tee $(RESULTS)/slice_130b.txt
	@grep -q '^PASS alu32' $(RESULTS)/slice_130b.txt
	@echo "=== 130B 32-BIT SLICE PASS ==="

claim: formal core10b slice130b
	@echo "directed=1048576+ (8b) / low-byte+lut (32b)" > $(RESULTS)/CLAIM.txt
	@echo "core10b=$(VECTORS_10B)" >> $(RESULTS)/CLAIM.txt
	@echo "slice130b=$(VECTORS_130B)" >> $(RESULTS)/CLAIM.txt
	@echo "formal=alu1b+alu8b+alu32 PASS" >> $(RESULTS)/CLAIM.txt
	@echo "dut=verification/gauntlet/rtl/alu.v (copy of fpga/core)" >> $(RESULTS)/CLAIM.txt
	@echo "=== DONE: formal + 10B + 130B ==="
	@cat $(RESULTS)/CLAIM.txt

clean:
	rm -rf $(OBJ) $(RESULTS) \
	  $(FORMAL)/alu1b_verify $(FORMAL)/alu8b_verify \
	  $(FORMAL)/alu32_verify $(FORMAL)/alu32_top_verify
