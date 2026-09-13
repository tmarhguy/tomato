# Tomato ALU Verification Makefile

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SYNTH     := $(ROOT)/synthesis
RTL       := $(ROOT)/rtl
FORMAL    := $(ROOT)/formal
DIRECTED  := $(ROOT)/directed
UVM_DIR   := $(ROOT)/uvm
WORK      := $(ROOT)/work
RESULTS   := $(ROOT)/results
GENERATE  := python3 $(ROOT)/scripts/generate.py
EXTRACTED_TB := $(DIRECTED)/run_extracted_tb.v

# Digital-export DUT netlists (provisioned locally, gitignored — see rtl/README.md).
RTL_1B := $(RTL)/alu-1b-final.v
RTL_8B := $(RTL)/alu-8b-final.v
RTL_32B := $(RTL)/alu-32b-final.v

VLOG      ?= vlog
VSIM      ?= vsim
IVERILOG  ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator

SEED      ?= $(shell echo $$RANDOM)
UVM_TEST  ?= alu_1b_smoke_test

# Gauntlet vector-count overrides (passed through to gauntlet/; fixed SEED => reproducible).
VECTORS_SMOKE ?= 1000000
VECTORS_10B   ?= 10000000000
VECTORS_130B  ?= 130000000000

COMMON_SV := \
  $(UVM_DIR)/common/alu_types_pkg.sv \
  $(UVM_DIR)/common/alu_op_table_pkg.sv \
  $(UVM_DIR)/common/directed_vectors_pkg.sv \
  $(UVM_DIR)/common/alu_ref_model_pkg.sv \
  $(UVM_DIR)/common/alu_if.sv \
  $(UVM_DIR)/common/alu_cov_pkg.sv

VLOG_FLAGS := -sv -timescale 1ns/1ps \
  +incdir+$(UVM_DIR)/common +incdir+$(UVM_DIR)/alu_1b \
  +incdir+$(UVM_DIR)/alu_8b +incdir+$(UVM_DIR)/alu_32b
VSIM_FLAGS := -c -do "run -all; quit -f" +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED)

UVM_32B_SRCS := $(COMMON_SV) \
  $(UVM_DIR)/alu_32b/alu_32b_pkg.sv \
  $(UVM_DIR)/alu_32b/alu_32b_assertions.sv \
  $(RTL)/alu-32b-final.v \
  $(UVM_DIR)/alu_32b/tb/tb_alu_32b.sv

.PHONY: all help test signoff signoff_open signoff_full generate formal_all formal_full formal_1b formal_8b \
        formal_32b formal_32b_equiv formal_32b_flags formal_inventory \
        directed lint clean synth synth_clean check-rtl check-questa \
        uvm_1b_smoke uvm_1b_exhaustive uvm_8b_smoke uvm_8b_full \
        uvm_32b_smoke uvm_32b_directed uvm_32b_ops91 uvm_32b_random uvm_32b_edge uvm_32b_flag \
        uvm_32b_regression uvm_regression \
        gauntlet gauntlet_formal gauntlet_formal_1b gauntlet_smoke gauntlet_10b gauntlet_130b gauntlet_claim

all: signoff

# `test` is the no-license tier: no Digital exports, no Questa
# (needs python3 + sby/solvers for the gauntlet formal leg).
# `signoff` is the strict full fast sign-off (needs rtl/).
test: signoff_open

# Every tool target that touches the DUT fails here first with the exact
# provisioning step, instead of a cryptic missing-file error mid-recipe.
check-rtl:
	@test -f $(RTL_1B) || { echo "missing $(RTL_1B) — export hardware/digital/modules/alu-1b-final.dig from Digital (see rtl/README.md)"; exit 1; }
	@test -f $(RTL_8B) || { echo "missing $(RTL_8B) — export hardware/digital/modules/alu-8b-final.dig from Digital (see rtl/README.md)"; exit 1; }
	@test -f $(RTL_32B) || { echo "missing $(RTL_32B) — export hardware/digital/modules/alu-32b-final.dig from Digital (see rtl/README.md)"; exit 1; }

check-questa:
	@command -v $(VLOG) >/dev/null || { echo "missing $(VLOG) — UVM needs Questa (vlog + vsim on PATH); open-source flow is signoff/signoff_full (see uvm/README.md)"; exit 1; }
	@command -v $(VSIM) >/dev/null || { echo "missing $(VSIM) — UVM needs Questa (vlog + vsim on PATH); open-source flow is signoff/signoff_full (see uvm/README.md)"; exit 1; }

help:
	@echo "Tomato ALU Verification"
	@echo "  make test              no-license tier: vectors + inventory + gauntlet formal (needs sby/solvers)"
	@echo "  make signoff           fast local sign-off: spot formal + lint + directed (~35 s, needs rtl/)"
	@echo "  make signoff_full      full: + 32b equiv prove (~3 min, needs rtl/)"
	@echo "  make formal_32b_equiv  end-to-end comb Out golden (~74 s)"
	@echo "  make formal_inventory  recount ALU assert/cover statements"
	@echo "  make generate          (re)extract directed vectors from Digital TBs"
	@echo "  make uvm_regression    1b + 8b + 32b UVM (Questa)"
	@echo "  make synth             Yosys → sky130 area/timing (see synthesis/README.md)"
	@echo "  make synth_clean       remove synthesis reports/"
	@echo "  make gauntlet_smoke    FPGA ALU: Verilator 1e6 smoke (~1 min, see gauntlet/)"
	@echo "  make gauntlet_10b      FPGA ALU: Verilator 10e9 on 8b (~7 min)"
	@echo "  make gauntlet_130b     FPGA ALU: Verilator 130e9 on 32b (~2-3 h)"
	@echo "  make gauntlet_claim    FPGA ALU: formal + 10B + 130B (long)"
	@echo ""
	@echo "Prerequisites: Digital-export netlists in rtl/ for signoff_* (see rtl/README.md);"
	@echo "  Questa (vlog/vsim) for uvm_* only."

# --- Vector extraction (no DUT needed) ---
# The file rule builds run_extracted_tb.v on first use; the phony forces a
# rebuild after editing a source TB (their filenames contain spaces, so they
# cannot be listed as make prerequisites — generate.py globs them itself).
generate:
	rm -f $(EXTRACTED_TB)
	@$(MAKE) --no-print-directory $(EXTRACTED_TB)

$(EXTRACTED_TB): $(ROOT)/scripts/generate.py
	@$(GENERATE)

# --- Formal ---
formal_1b: check-rtl
	cd $(FORMAL) && sby -f alu_1b_verify.sby

formal_8b: check-rtl
	cd $(FORMAL) && sby -f alu_8b_verify.sby

formal_32b: check-rtl
	cd $(FORMAL) && sby -f alu_32b_verify.sby

formal_32b_equiv: check-rtl
	cd $(FORMAL) && sby -f alu_32b_equiv_verify.sby

formal_32b_flags: check-rtl
	cd $(FORMAL) && sby -f alu_32b_flags_verify.sby

formal_all: formal_1b formal_8b formal_32b formal_32b_flags

formal_full: formal_1b formal_8b formal_32b formal_32b_equiv formal_32b_flags

formal_inventory:
	python3 $(ROOT)/scripts/inventory_formal.py

# --- Directed (Icarus) ---
$(WORK):
	mkdir -p $(WORK)

directed: check-rtl $(WORK) $(EXTRACTED_TB)
	$(IVERILOG) -g2005-sv -o $(WORK)/directed.out \
	  $(RTL)/alu-32b-final.v $(DIRECTED)/alu_ref.v \
	  $(DIRECTED)/alu_32b_dut_wrap.v $(EXTRACTED_TB)
	$(VVP) $(WORK)/directed.out

lint: check-rtl
	$(VERILATOR) --lint-only -Wno-fatal -Wno-UNUSEDSIGNAL \
	  $(RTL)/alu-1b-final.v $(RTL)/alu-8b-final.v $(RTL)/alu-32b-final.v

signoff: generate formal_all lint directed
	@echo "=== SIGNOFF PASS (fast) ==="

signoff_full: generate formal_full lint directed
	@echo "=== SIGNOFF FULL PASS ==="

# --- Open tier (no Digital netlists, no Questa) ---
# Needs python3 + sby/solvers for the gauntlet formal leg (OSS CAD Suite on
# PATH — see gauntlet/README.md). Runs: vector extraction (self-checks the
# 455/12/9 per-file counts), the formal inventory recount, and the full
# SymbiYosys proof of the FPGA ALU copy (gauntlet ships its own DUT).
signoff_open: generate formal_inventory gauntlet_formal
	@echo "=== SIGNOFF OPEN PASS (no-DUT layers: vectors, inventory, gauntlet formal) ==="

# --- Gauntlet (FPGA dual-LUT ALU copy; does not touch hardware/fpga/core) ---
# Every long run is reachable from here so docs never send you hunting for
# a subdirectory. Overrides pass through: e.g.
#   make gauntlet_130b VECTORS_130B=100000000 SEED=7   # 1e8 pilot
gauntlet gauntlet_smoke:
	$(MAKE) -C $(ROOT)/gauntlet smoke VECTORS_SMOKE=$(VECTORS_SMOKE) SEED=$(SEED)

gauntlet_10b:
	$(MAKE) -C $(ROOT)/gauntlet run_10b VECTORS_10B=$(VECTORS_10B) SEED=$(SEED)

gauntlet_130b:
	$(MAKE) -C $(ROOT)/gauntlet run_130b VECTORS_130B=$(VECTORS_130B) SEED=$(SEED)

gauntlet_formal:
	$(MAKE) -C $(ROOT)/gauntlet formal

gauntlet_formal_1b:
	$(MAKE) -C $(ROOT)/gauntlet formal_1b

gauntlet_claim:
	$(MAKE) -C $(ROOT)/gauntlet claim VECTORS_10B=$(VECTORS_10B) VECTORS_130B=$(VECTORS_130B) SEED=$(SEED)

# --- UVM (Questa) ---
define RUN_UVM_1B
	$(VLOG) $(VLOG_FLAGS) -work $(WORK)/alu_1b $(COMMON_SV) \
	  $(UVM_DIR)/alu_1b/alu_1b_pkg.sv $(RTL)/alu-1b-final.v $(UVM_DIR)/alu_1b/tb/tb_alu_1b.sv
	$(VSIM) $(VSIM_FLAGS) -work $(WORK)/alu_1b tb_alu_1b
endef

define RUN_UVM_8B
	$(VLOG) $(VLOG_FLAGS) -work $(WORK)/alu_8b $(COMMON_SV) \
	  $(UVM_DIR)/alu_8b/alu_8b_pkg.sv $(RTL)/alu-8b-final.v $(UVM_DIR)/alu_8b/tb/tb_alu_8b.sv
	$(VSIM) $(VSIM_FLAGS) -work $(WORK)/alu_8b tb_alu_8b
endef

define RUN_UVM_32B
	$(VLOG) $(VLOG_FLAGS) -work $(WORK)/alu_32b $(UVM_32B_SRCS)
	$(VSIM) $(VSIM_FLAGS) -work $(WORK)/alu_32b tb_alu_32b
endef

uvm_1b_smoke:       UVM_TEST = alu_1b_smoke_test
uvm_1b_exhaustive:  UVM_TEST = alu_1b_exhaustive_test
uvm_1b_smoke uvm_1b_exhaustive: check-rtl check-questa $(WORK)
	$(RUN_UVM_1B)

uvm_8b_smoke: UVM_TEST = alu_8b_smoke_test
uvm_8b_full:  UVM_TEST = alu_8b_full_test
uvm_8b_smoke uvm_8b_full: check-rtl check-questa $(WORK)
	$(RUN_UVM_8B)

uvm_32b_smoke:    UVM_TEST = alu_32b_smoke_test
uvm_32b_directed: UVM_TEST = alu_32b_directed_test
uvm_32b_ops91:    UVM_TEST = alu_32b_ops91_test
uvm_32b_random:   UVM_TEST = alu_32b_random_test
uvm_32b_edge:     UVM_TEST = alu_32b_edge_test
uvm_32b_flag:     UVM_TEST = alu_32b_flag_test
uvm_32b_regression: UVM_TEST = alu_32b_full_regression_test
uvm_32b_smoke uvm_32b_directed uvm_32b_ops91 uvm_32b_random uvm_32b_edge uvm_32b_flag uvm_32b_regression: check-rtl check-questa $(WORK)
	$(RUN_UVM_32B)

UVM_REGRESSION := uvm_1b_exhaustive uvm_8b_full uvm_32b_regression

uvm_regression: check-questa $(WORK)
	@mkdir -p $(RESULTS); fail=0; \
	for t in $(UVM_REGRESSION); do \
	  echo "--- $$t ---"; \
	  $(MAKE) $$t SEED=$(SEED) || fail=$$((fail+1)); \
	done; \
	echo "UVM regression: $$((3-fail))/3 suites passed"; \
	test $$fail -eq 0

clean:
	rm -rf $(WORK) $(RESULTS) $(FORMAL)/alu_*_verify $(FORMAL)/alu_*_prove $(DIRECTED)/run_extracted_tb.v

synth:
	cd $(SYNTH) && bash run.sh

synth_clean:
	rm -rf $(SYNTH)/reports/*

