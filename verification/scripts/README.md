# Verification helper scripts

| Script | Role |
|--------|------|
| [`inventory_formal.py`](inventory_formal.py) | Recount ALU formal assert/cover → `formal/PROPERTY_INVENTORY.md` |

```bash
make -C verification formal_inventory
```

Note: `generate.py` (vector codegen) is optional; committed UVM packages under `uvm/common/` are authoritative until it ships.
