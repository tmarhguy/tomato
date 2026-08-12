# Thin wrappers — verification (default) + Tomato FPGA core tests

FPGA := hardware/fpga/tomato

all:
	@$(MAKE) -C verification help

test:
	@$(MAKE) -C verification signoff

fpga-test:
	@$(MAKE) -C $(FPGA) test

.PHONY: all test fpga-test
