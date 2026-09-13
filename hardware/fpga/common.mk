# Shared open-source Artix-7 flow: yosys → nextpnr-xilinx → Project X-Ray → openFPGALoader
#
# A project includes this and sets, before the include:
#
#   TOP        top module name
#   SRC        Verilog / SystemVerilog sources
#   XDC        constraints file
#   FREQ_MHZ   target for nextpnr's timing analysis
#   YOSYS_INC  optional  -I dirs for `include
#   YOSYS_DEFS optional  -D defines
#   SYNTH_OPTS optional  extra synth_xilinx flags
#
# openXC7's nix flake is Linux-only, so on Apple Silicon the toolchain is
# assembled from three places:
#
#   OSS CAD Suite  → yosys, openFPGALoader
#   nixpkgs        → nextpnr-xilinx, bbasm, prjxray-db + site metadata
#   local build    → xc7frames2bit, fasm2frames
#
# scripts/env.sh layers all three onto PATH. FPGA targets auto-enter it when
# nextpnr-xilinx is missing, so a bare `make fpga` / `make program` just works.

FPGA_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# nix on stock macOS ships with `nix-command` + `flakes` off; carry the flag on
# every invocation so no NIX_CONFIG export or nix.conf edit is ever needed.
NIX ?= nix --extra-experimental-features 'nix-command flakes'
# Make sure the nix binaries resolve even from a bare shell.
export PATH := $(HOME)/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$(PATH)

# Lowest-friction entry: a bare `make fpga` / `make program` inside core/ or
# hdmi_test/ re-enters through scripts/env.sh when nextpnr-xilinx is missing
# (i.e. outside the nix shell). env.sh exports TOMATO_FPGA_ENV=1, so the child
# make takes the real recipes below exactly once. Sim-only targets
# (test, os, burn, clean, ...) never wrap and stay nix-free.
# hdmi_test sets ALL_NEEDS_FPGA := 1 before including this file because its
# default `all` builds the bitstream; core's `all` is sim-only.
ALL_NEEDS_FPGA ?= 0
_FPGA_WRAP_MATCH := fpga synth chipdb pnr bit program
ifeq ($(ALL_NEEDS_FPGA),1)
_FPGA_WRAP_MATCH += all
endif
ifndef TOMATO_FPGA_ENV
ifeq (,$(shell command -v nextpnr-xilinx 2>/dev/null))
_FPGA_WRAP_GOALS := $(filter $(_FPGA_WRAP_MATCH),$(MAKECMDGOALS))
ifeq ($(MAKECMDGOALS),)
ifeq ($(ALL_NEEDS_FPGA),1)
_FPGA_WRAP_GOALS := __default_fpga__
endif
endif
ifneq ($(_FPGA_WRAP_GOALS),)
_FPGA_AUTO_WRAP := 1
endif
endif
endif

PART     ?= xc7a100tcsg324-1
FAMILY   ?= artix7
FREQ_MHZ ?= 100
BUILD    ?= build

CHIPDB   := $(BUILD)/chipdb/chipdb.bin
BBA      := $(BUILD)/chipdb/chipdb.bba
JSON     := $(BUILD)/$(TOP).json
ROUTED   := $(BUILD)/$(TOP)_routed.json
FASM     := $(BUILD)/$(TOP).fasm
FRAMES   := $(BUILD)/$(TOP).frames
BIT      := $(BUILD)/$(TOP).bit

TOOLS         := $(FPGA_DIR)/.tools
SCRIPTS       := $(FPGA_DIR)/scripts
FASM2FRAMES   := $(TOOLS)/fasm2frames
XC7FRAMES2BIT := $(TOOLS)/prjxray/build/tools/xc7frames2bit

# nextpnr-xilinx (nixpkgs) ships bbaexport.py plus prjxray-db and site metadata.
NEXTPNR_SHARE := $(dir $(shell command -v nextpnr-xilinx 2>/dev/null))../share/nextpnr
BBAEXPORT     := $(NEXTPNR_SHARE)/python/bbaexport.py
PRJXRAY_DB    := $(NEXTPNR_SHARE)/external/prjxray-db
PART_YAML     := $(PRJXRAY_DB)/$(FAMILY)/$(PART)/part.yaml

# ODDR is a blackbox in cells_xtra.v; BUFG lives in cells_sim.v. Both needed.
YOSYS_DATADIR := $(shell yosys-config --datdir 2>/dev/null)
XILINX_CELLS  := $(YOSYS_DATADIR)/xilinx/cells_sim.v $(YOSYS_DATADIR)/xilinx/cells_xtra.v

YOSYS_READ := $(YOSYS_LANG) $(foreach d,$(YOSYS_DEFS),-D$(d)) $(foreach i,$(YOSYS_INC),-I$(i))

.PHONY: fpga setup synth pnr bit chipdb program clean-fpga distclean check-tools

ifndef _FPGA_AUTO_WRAP
fpga: $(BIT)
endif

check-tools:
	@command -v yosys >/dev/null || { echo "missing yosys — run: make setup"; exit 1; }
	@command -v nextpnr-xilinx >/dev/null || { echo "missing nextpnr-xilinx — build via $(SCRIPTS)/env.sh"; exit 1; }
	@command -v bbasm >/dev/null || { echo "missing bbasm — build via $(SCRIPTS)/env.sh"; exit 1; }
	@command -v openFPGALoader >/dev/null || { echo "missing openFPGALoader — run: make setup"; exit 1; }
	@test -f "$(BBAEXPORT)" || { echo "missing bbaexport.py — build via $(SCRIPTS)/env.sh"; exit 1; }

setup:
	@chmod +x $(SCRIPTS)/*.sh
	@$(SCRIPTS)/setup-oss-cad.sh
	@$(NIX) shell nixpkgs#cmake nixpkgs#ninja --command $(SCRIPTS)/setup-prjxray-tools.sh
	@echo
	@echo "Toolchain ready. Build with:  make fpga  (or $(SCRIPTS)/env.sh make)"

ifndef _FPGA_AUTO_WRAP
chipdb: $(CHIPDB)

# One-time per part; a few minutes and ~GBs of RAM, then cached in build/.
$(CHIPDB): | $(BUILD)/chipdb
	@$(MAKE) --no-print-directory check-tools
	@echo "==> chipdb $(PART)"
	python3 "$(BBAEXPORT)" --device $(PART) --bba $(BBA)
	bbasm -l $(BBA) $@

synth: $(JSON)

$(JSON): $(SRC) | $(BUILD)
	@$(MAKE) --no-print-directory check-tools
	@echo "==> yosys $(TOP)"
	yosys -q -p 'read_verilog -lib $(XILINX_CELLS); \
	             read_verilog $(YOSYS_READ) $(SRC); \
	             hierarchy -check -top $(TOP); \
	             synth_xilinx -flatten -abc9 $(SYNTH_OPTS) -top $(TOP); \
	             write_json $(JSON)'

pnr: $(FASM)

# --ignore-loops: a distributed-RAM register file feeds its own write-data pins
# from its read outputs. That is a clocked path, but nextpnr's SLICEM model has
# no DI→O arc to break, so the topological sort calls it a combinational loop
# and refuses to run. Skipping those arcs is the only way past it; every real
# path still gets analysed against --freq.
$(FASM): $(JSON) $(CHIPDB) $(XDC)
	@echo "==> nextpnr-xilinx $(TOP) @ $(FREQ_MHZ) MHz"
	nextpnr-xilinx \
		--chipdb $(CHIPDB) \
		--xdc $(XDC) \
		--json $(JSON) \
		--write $(ROUTED) \
		--fasm $(FASM) \
		--freq $(FREQ_MHZ) \
		--ignore-loops $(NEXTPNR_EXTRA)

bit: $(BIT)

$(BIT): $(FASM)
	@test -x $(FASM2FRAMES) || { echo "missing fasm2frames — run: make setup"; exit 1; }
	@test -x $(XC7FRAMES2BIT) || { echo "missing xc7frames2bit — run: make setup"; exit 1; }
	@echo "==> fasm2frames + xc7frames2bit"
	$(FASM2FRAMES) --part $(PART) --db-root $(PRJXRAY_DB)/$(FAMILY) $(FASM) > $(FRAMES)
	$(XC7FRAMES2BIT) \
		--part_file $(PART_YAML) \
		--part_name $(PART) \
		--frm_file $(FRAMES) \
		--output_file $(BIT)
	@echo "wrote $(BIT)"

program: $(BIT)
	openFPGALoader -b nexys_a7_100 $(BIT)

endif # _FPGA_AUTO_WRAP

$(BUILD) $(BUILD)/chipdb:
	@mkdir -p $@

clean-fpga:
	rm -rf $(BUILD)

# Blows away the ~2.7 GB shared toolchain, not just this project.
distclean: clean-fpga
	rm -rf $(TOOLS)

# --- auto-wrap forwarding (only defined when _FPGA_AUTO_WRAP is set) --------
# Each requested FPGA target re-enters through env.sh exactly once; the child
# make sees TOMATO_FPGA_ENV=1 and takes the real recipes above. A bare `make`
# in hdmi_test (whose default builds the bitstream) lands on _fpga_env.
ifdef _FPGA_AUTO_WRAP
_FPGA_FWD := $(filter $(_FPGA_WRAP_MATCH),$(MAKECMDGOALS))
.PHONY: _fpga_env $(_FPGA_FWD)
_fpga_env:
	@$(SCRIPTS)/env.sh $(MAKE)
ifneq ($(_FPGA_FWD),)
$(_FPGA_FWD):
	@$(SCRIPTS)/env.sh $(MAKE) $@
else
.DEFAULT_GOAL := _fpga_env
endif
endif
