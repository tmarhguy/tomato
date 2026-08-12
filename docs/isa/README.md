# Tomato ISA

**Single authority:** [`tomato.v1.csv`](tomato.v1.csv) — 512-row opcode ROM.

| File | Role |
|------|------|
| `tomato.v1.csv` | **Source of truth** — burn opcodes + unused NOP slots |
| `datapath-audit.csv` | Derived checklist vs FPGA RTL (keep in sync with v1) |
| `lut.csv` | ALU LUT primitive catalog (hardware reference) |
| `profiles/` + `profiles.csv` | External-ISA *mnemonic maps* onto Tomato (not more opcodes) |

Pack microcode / FPGA burn:

```bash
python3 tools/gen_microcode_v1.py --pack-rom   # regenerate v1 + .mem
cd hardware/fpga/tomato && make burn           # embed into rtl/burn/
```

**Policy:** solidified burn ops stay. Add new burns in `burn_core_rows()` when you need them. Do not invent hundreds of growth phantoms. Empty ROM rows are `status=nop`.
