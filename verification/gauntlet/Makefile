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

.PHONY: all help sync check-sync check-tools check-tools-sby check-tools-verilator formal formal_1b formal_8b formal_32b \
        build build8 build32 smoke run_10b run_130b core10b slice130b claim clean results-dir

all: formal smoke

help:
	@echo "Tomato ALU gauntlet (FPGA dual-LUT copy — does not touch core/)"
	@echo ""
	@echo "  make sync          copy alu.v from hardware/fpga/core"
	@echo "  make check-sync    assert copy matches core"
	@echo "  make check-tools   assert sby + yosys + verilator are on PATH"
	@echo "  make check-tools-sby        assert sby + yosys (formal only)"
	@echo "  make check-tools-verilator  assert verilator (smoke / long runs only)"
	@echo "  make formal        SymbiYosys prove 1b + 8b + 32b (needs sby + solvers)"
	@echo "  make smoke         Verilator smoke: 1e6 vectors on 8b + 32b (~1 min)"
	@echo "  make run_10b       Verilator 10e9 vectors on alu8b (8-bit, ~7 min)"
	@echo "  make run_130b      Verilator 130e9 vectors on alu (32-bit, ~2-3 h)"
	@echo "  make claim         formal + run_10b + run_130b -> results/CLAIM.txt"
	@echo "  make clean         remove obj/ and formal run dirs"
	@echo ""
	@echo "Overrides: VECTORS_SMOKE= N (default 1000000)"
	@echo "           VECTORS_10B=   N (default 10000000000)"
	@echo "           VECTORS_130B=  N (default 130000000000)"
	@echo "           SEED=          N (default 1; fixed seed => reproducible)"
	@echo "           GAUNTLET_PROGRESS_EVERY=N (status line every N vectors; default 1e9)"
	@echo "Examples:"
	@echo "  make smoke VECTORS_SMOKE=100000      # short smoke"
	@echo "  make run_130b VECTORS_130B=100000000 # 1e8 pilot before the full run"
	@echo "  GAUNTLET_PROGRESS_EVERY=100000000 make run_130b   # ~10x chattier log"
	@echo "Watch a long run: tail -f results/slice_130b.txt   # 10B: results/core_10b.txt"
	@echo ""
	@echo "Legacy aliases: core10b (= run_10b), slice130b (= run_130b)."

sync:
	@mkdir -p $(RTL)
	cp $(CORE_ALU) $(RTL)/alu.v
	@echo "synced $(RTL)/alu.v from core"

check-sync:
	@test -f $(CORE_ALU) || (echo "missing core DUT: $(CORE_ALU)"; exit 1)
	@test -f $(RTL)/alu.v || (echo "missing gauntlet copy — run: make sync"; exit 1)
	@diff -q $(CORE_ALU) $(RTL)/alu.v
	@echo "OK: gauntlet rtl/alu.v matches hardware/fpga/core/rtl/alu.v"

# Fail fast with the install pointer instead of a cryptic mid-recipe error.
# Split targets so Verilator-only runs (smoke/run_10b/run_130b) don't require
# sby, and formal-only runs don't require Verilator. check-tools = both.
check-tools-sby:
	@command -v $(SBY) >/dev/null || { echo "missing $(SBY) — install SymbiYosys (OSS CAD Suite: make setup in hardware/fpga/core, or brew install sby)"; exit 1; }
	@command -v yosys >/dev/null || { echo "missing yosys — install Yosys (OSS CAD Suite, or brew install yosys)"; exit 1; }
	@echo "OK: $(SBY) + yosys on PATH"

check-tools-verilator:
	@command -v $(VERILATOR) >/dev/null || { echo "missing $(VERILATOR) — install Verilator (OSS CAD Suite, or brew install verilator)"; exit 1; }
	@echo "OK: $(VERILATOR) on PATH"

check-tools: check-tools-sby check-tools-verilator
	@echo "OK: $(SBY) + $(VERILATOR) on PATH"

formal_1b: check-tools-sby
	cd $(FORMAL) && $(SBY) -f alu1b_verify.sby

formal_8b: check-tools-sby
	cd $(FORMAL) && $(SBY) -f alu8b_verify.sby

formal_32b: check-tools-sby
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

smoke: check-sync check-tools-verilator build results-dir
	$(OBJ)/alu8/alu8_gauntlet $(VECTORS_SMOKE) $(SEED) | tee $(RESULTS)/smoke_8b.txt
	$(OBJ)/alu32/alu_gauntlet $(VECTORS_SMOKE) $(SEED) | tee $(RESULTS)/smoke_32b.txt
	@echo "=== GAUNTLET SMOKE PASS ==="

# Canonical long runs. 8b first (fast, ~25 Mvec/s), then 32b (~13-16 Mvec/s).
run_10b: check-sync check-tools-verilator build8 results-dir
	$(OBJ)/alu8/alu8_gauntlet $(VECTORS_10B) $(SEED) | tee $(RESULTS)/core_10b.txt
	@grep -q '^PASS alu8b' $(RESULTS)/core_10b.txt
	@echo "=== 10B ALU-CORE PASS ==="

run_130b: check-sync check-tools-verilator build32 results-dir
	$(OBJ)/alu32/alu_gauntlet $(VECTORS_130B) $(SEED) | tee $(RESULTS)/slice_130b.txt
	@grep -q '^PASS alu32' $(RESULTS)/slice_130b.txt
	@echo "=== 130B 32-BIT SLICE PASS ==="

# Legacy aliases (prefer run_10b / run_130b in docs and CI).
core10b: run_10b
slice130b: run_130b

claim: formal run_10b run_130b
	@{ \
	  echo "# Tomato ALU gauntlet claim — $(shell date -u +%Y-%m-%dT%H:%M:%SZ)"; \
	  echo "dut=verification/gauntlet/rtl/alu.v (copy of fpga/core)"; \
	  echo "dut_sha256=$$(shasum -a 256 $(RTL)/alu.v | cut -d' ' -f1)"; \
	  echo "git_rev=$$(git -C $(ROOT) rev-parse --short HEAD 2>/dev/null || echo unknown)"; \
	  echo "seed=$(SEED)"; \
	  echo "directed=1048576+ (8b) / low-byte+lut (32b)"; \
	  echo "run_10b_vectors=$(VECTORS_10B)"; \
	  echo "run_130b_vectors=$(VECTORS_130B)"; \
	  echo "formal=alu1b+alu8b+alu32 PASS"; \
	} > $(RESULTS)/CLAIM.txt
	@echo "=== DONE: formal + 10B + 130B ==="
	@cat $(RESULTS)/CLAIM.txt

clean:
	rm -rf $(OBJ) $(RESULTS) \
	  $(FORMAL)/alu1b_verify $(FORMAL)/alu8b_verify \
	  $(FORMAL)/alu32_verify $(FORMAL)/alu32_top_verify
