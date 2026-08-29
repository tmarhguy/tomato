# Tomato — Verilog exports

<p align="center"><strong>Digital netlists are read-only · regenerate, do not hand-edit.</strong></p>

![Policy](https://img.shields.io/badge/Policy-read--only%20export-990000) ![Source](https://img.shields.io/badge/Source-Digital%20.dig-0891B2)

**Golden rule:** do not hand-edit the exported / golden netlist folders. Logic changes go into [hardware/digital/modules/*.dig](../digital/modules/), then re-export.

**Project map:** [Hardware](../README.md) · [Digital](../digital/README.md) · [Verification RTL](../../verification/rtl/README.md) · [FPGA core](../fpga/core/README.md)

| Consumer | Path | Notes |
|----------|------|-------|
| ALU sign-off | `verification/rtl/` | Copy Digital exports, then `make signoff` |
| FPGA CPU | `hardware/fpga/core/rtl/` | Hand-written Verilog faithful to the sheets — not a raw Digital dump |
| Digital export stash | this tree / `exported/` if present | Reference only |

Hand-edits here drift from the schematic and break formal / directed replay.
