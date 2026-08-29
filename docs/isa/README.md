# Tomato ISA

**Single authority:** [`tomato.v1.csv`](tomato.v1.csv) — 512-row opcode ROM.

| File | Role |
|------|------|
| `tomato.v1.csv` | **Source of truth** — burn opcodes + unused NOP slots |
| `datapath-audit.csv` | Derived checklist vs FPGA RTL (keep in sync with v1) |
| `lut.csv` | ALU LUT primitive catalog (hardware reference) |
| `profiles/` + `profiles.csv` | Parametric maps onto Tomato (not more opcodes; CSV rows are the sweep database, not a trophy count) |

Pack microcode / FPGA burn:

```bash
python3 tools/gen_microcode_v1.py --pack-rom   # regenerate v1 + .mem
cd hardware/fpga/core && make burn           # embed into rtl/burn/
```

**Policy:** solidified burn ops stay. Add new burns in `burn_core_rows()` when you need them. Do not invent hundreds of growth phantoms. Empty ROM rows are `status=nop`.

## Locked decisions

- **Not a ~20-opcode lean map.** v1 is ~51 `status=burn` ops; unused ROM rows are `status=nop` (no growth phantoms).
- **No tile VPU.** Display is CPU-painted tile RAM + independent VGA scanout (`software/os/DISPLAY.md`). Games stay software; a future rect blitter is optional — not a sprite VPU.
- **ISA is a first-class input.** Overlay word + immediate box + dual-LUT absorb foreign encodings as maps onto muxes — not an emulator. Casual family count ~37 (CSV has more rows). See [ISA as a Wire](../log/2026-08-15%20-%20ISA%20as%20a%20Wire.md). Maps cover compute, shift, and register-access; not x86 segmentation or ARM TrustZone.
