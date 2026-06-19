# Thin wrapper → verification

all:
	@$(MAKE) -C verification help

test:
	@$(MAKE) -C verification signoff

.PHONY: all test
