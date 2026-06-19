# Tomato32 ALU Verification Makefile

ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
RTL       := $(ROOT)/rtl
FORMAL    := $(ROOT)/formal
DIRECTED  := $(ROOT)/directed
UVM_DIR   := $(ROOT)/uvm
WORK      := $(ROOT)/work
RESULTS   := $(ROOT)/results
GENERATE  := python3 $(ROOT)/scripts/generate.py

VLOG      ?= vlog
VSIM      ?= vsim
IVERILOG  ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator

SEED      ?= $(shell echo $$RANDOM)
UVM_TEST  ?= alu_1b_smoke_test

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

.PHONY: all help signoff signoff_full generate formal_all formal_1b formal_8b \
        formal_32b formal_32b_equiv formal_32b_flags \
        directed lint clean \
        uvm_1b_smoke uvm_1b_exhaustive uvm_8b_smoke uvm_8b_full \
        uvm_32b_smoke uvm_32b_directed uvm_32b_ops91 uvm_32b_random uvm_32b_edge uvm_32b_flag \
        uvm_32b_regression uvm_regression

all: signoff

help:
	@echo "Tomato32 ALU Verification"
	@echo "  make signoff           fast CI: spot formal + lint + directed (~35 s)"
	@echo "  make signoff_full      full: + 32b equiv prove (~3 min)"
	@echo "  make formal_32b_equiv  end-to-end comb Out golden (~74 s)"
	@echo "  make generate          regenerate op table + directed vectors"
	@echo "  make uvm_regression    1b + 8b + 32b UVM (Questa)"

generate:
	@$(GENERATE)

# --- Formal ---
formal_1b:
	cd $(FORMAL) && sby -f alu_1b_verify.sby

formal_8b:
	cd $(FORMAL) && sby -f alu_8b_verify.sby

formal_32b:
	cd $(FORMAL) && sby -f alu_32b_verify.sby

formal_32b_equiv:
	cd $(FORMAL) && sby -f alu_32b_equiv_verify.sby

formal_32b_flags:
	cd $(FORMAL) && sby -f alu_32b_flags_verify.sby

formal_all: formal_1b formal_8b formal_32b formal_32b_flags

formal_full: formal_1b formal_8b formal_32b formal_32b_equiv formal_32b_flags

# --- Directed (Icarus) ---
$(WORK):
	mkdir -p $(WORK)

directed: $(WORK) generate
	$(IVERILOG) -g2005-sv -o $(WORK)/directed.out \
	  $(RTL)/alu-32b-final.v $(DIRECTED)/alu_ref.v \
	  $(DIRECTED)/alu_32b_dut_wrap.v $(DIRECTED)/run_extracted_tb.v
	$(VVP) $(WORK)/directed.out

lint:
	$(VERILATOR) --lint-only -Wno-fatal -Wno-UNUSEDSIGNAL \
	  $(RTL)/alu-1b-final.v $(RTL)/alu-8b-final.v $(RTL)/alu-32b-final.v

signoff: generate formal_all lint directed
	@echo "=== SIGNOFF PASS (fast) ==="

signoff_full: generate formal_full lint directed
	@echo "=== SIGNOFF FULL PASS ==="

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
uvm_1b_smoke uvm_1b_exhaustive: $(WORK)
	$(RUN_UVM_1B)

uvm_8b_smoke: UVM_TEST = alu_8b_smoke_test
uvm_8b_full:  UVM_TEST = alu_8b_full_test
uvm_8b_smoke uvm_8b_full: $(WORK)
	$(RUN_UVM_8B)

uvm_32b_smoke:    UVM_TEST = alu_32b_smoke_test
uvm_32b_directed: UVM_TEST = alu_32b_directed_test
uvm_32b_ops91:    UVM_TEST = alu_32b_ops91_test
uvm_32b_random:   UVM_TEST = alu_32b_random_test
uvm_32b_edge:     UVM_TEST = alu_32b_edge_test
uvm_32b_flag:     UVM_TEST = alu_32b_flag_test
uvm_32b_regression: UVM_TEST = alu_32b_full_regression_test
uvm_32b_smoke uvm_32b_directed uvm_32b_ops91 uvm_32b_random uvm_32b_edge uvm_32b_flag uvm_32b_regression: $(WORK)
	$(RUN_UVM_32B)

UVM_REGRESSION := uvm_1b_exhaustive uvm_8b_full uvm_32b_regression

uvm_regression: $(WORK)
	@mkdir -p $(RESULTS); fail=0; \
	for t in $(UVM_REGRESSION); do \
	  echo "--- $$t ---"; \
	  $(MAKE) $$t SEED=$(SEED) || fail=$$((fail+1)); \
	done; \
	echo "UVM regression: $$((3-fail))/3 suites passed"; \
	test $$fail -eq 0

clean:
	rm -rf $(WORK) $(RESULTS) $(FORMAL)/alu_*_verify $(FORMAL)/alu_*_prove
