# Verification helper scripts

| Script | Role |
|--------|------|
| [`generate.py`](generate.py) | Parse `144'b…` pattern lines out of the three Digital TBs in `directed/` and emit `directed/run_extracted_tb.v` (482 stimulus rows applied, 476 checked). Output order matches `uvm/common/directed_vectors_pkg.sv`. |
| [`inventory_formal.py`](inventory_formal.py) | Recount ALU formal assert/cover → `formal/PROPERTY_INVENTORY.md` |

```bash
make -C verification generate formal_inventory
```

Note: the committed packages under `uvm/common/` (op table, directed vectors, ref model) remain authoritative — `generate.py` only rebuilds the Icarus replay bench from the same sources.
