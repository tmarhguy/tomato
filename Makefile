# Thin wrappers — verification (default) + Tomato FPGA core tests + web sanity

FPGA := hardware/fpga/core
HDMI := hardware/fpga/hdmi_test
FPGA_ENV := hardware/fpga/scripts/env.sh

all:
	@$(MAKE) -C verification help

help:
	@$(MAKE) -C verification help

# `test` is the no-license tier (no Digital exports, no Questa);
# `signoff` is the strict fast sign-off (needs Digital-export rtl/).
test:
	@$(MAKE) -C verification signoff_open

signoff:
	@$(MAKE) -C verification signoff

# FPGA ALU gauntlet (Verilator + SymbiYosys on hardware/fpga/core copy).
# smoke: ~1 min · 10b: ~7 min · 130b: ~2-3 h · claim: formal + 10b + 130b.
gauntlet-smoke:
	@$(MAKE) -C verification gauntlet_smoke

gauntlet-10b:
	@$(MAKE) -C verification gauntlet_10b

gauntlet-130b:
	@$(MAKE) -C verification gauntlet_130b

gauntlet-claim:
	@$(MAKE) -C verification gauntlet_claim

fpga-test:
	@$(MAKE) -C $(FPGA) test

# Lowest friction FPGA flow — no cd, no env.sh prefix, no nix setup.
# Each target auto-enters the OSS CAD Suite + nixpkgs toolchain.
fpga:
	@$(FPGA_ENV) $(MAKE) -C $(FPGA) fpga

fpga-program:
	@$(FPGA_ENV) $(MAKE) -C $(FPGA) program

fpga-setup:
	@$(MAKE) -C $(FPGA) setup

hdmi:
	@$(FPGA_ENV) $(MAKE) -C $(HDMI)

hdmi-program:
	@$(FPGA_ENV) $(MAKE) -C $(HDMI) program

web:
	@cd web && npm run serve

web-test:
	@cd web && npm test

.PHONY: all help test signoff gauntlet-smoke gauntlet-10b gauntlet-130b gauntlet-claim fpga-test fpga fpga-program fpga-setup hdmi hdmi-program web web-test
