# Thin wrappers — verification (default) + Tomato FPGA core tests + web sanity

FPGA := hardware/fpga/tomato

all:
	@$(MAKE) -C verification help

test:
	@$(MAKE) -C verification signoff

fpga-test:
	@$(MAKE) -C $(FPGA) test

web-test:
	@cd web && npm test

.PHONY: all test fpga-test web-test
