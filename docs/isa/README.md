# Tomato — ISA

<p align="center"><strong>512-row opcode ROM · assembler vocabulary · parametric maps.</strong></p>

![ROM](https://img.shields.io/badge/ROM-512%20rows-2563EB) ![Burn](https://img.shields.io/badge/Burn-62%20rows-DC2626)

**Burn authority:** [`tomato.v1.csv`](tomato.v1.csv) — the microcode ROM.  
**Assembler vocabulary:** [`tomato.v1.pseudo.csv`](tomato.v1.pseudo.csv) — mnemonics that expand into burns (no new ROM rows).

**Project map:** [Root README](../../README.md) · [Software](../../software/README.md) · [Microcode](../../microcode/README.md) · Paper: [isa.html](https://tomato.tmarhguy.com/isa.html)

<p align="center">
  <img src="../../web/assets/compiler/opcode-sweep-sim.webp" alt="Opcode sweep in simulation" width="48%" />
  <img src="../../web/assets/compiler/opcode-sweep-fpga.webp" alt="Opcode sweep on FPGA" width="48%" />
</p>
<p align="center"><em>Opcode-sweep evidence from simulation and a documented FPGA run; see the source record for provenance.</em></p>

| File | Role |
|------|------|
| `tomato.v1.csv` | Microcode ROM rows — burn opcodes + unused NOP slots |
| `tomato.v1.pseudo.csv` | Pseudos (`CALL`, `BEQZ`, `LI`, …) for the assembler |
| `datapath-audit.csv` | Derived checklist vs FPGA RTL (keep in sync with v1) |
| `lut.csv` | Curated ALU LUT primitives (hardware reference subset) |
| `luts.csv` | Full 256-entry Dual-LUT `f` map + nested Boolean names |
| `lut-nested-fuse.csv` | `outer(A, inner(B,C))` nests that fuse to one LUT cycle |
| `profiles/` + `profiles.csv` | Parametric maps onto Tomato (CSV rows are the sweep database) |

---

## Pack and check

```bash
python3 tools/gen_microcode_v1.py --pack-rom   # regenerate v1 + .mem
cd hardware/fpga/core && make burn             # embed into rtl/burn/
python3 software/assembler.py --selftest       # vocabulary vs burns
```

**Policy:** solidified burned instructions stay. Add new burns in
`burn_core_rows()` only with an intentional ISA change. Empty ROM rows are
`status=nop`. Pseudos never invent opcodes.

---

## Locked decisions

- **Exact count.** v1 has **91 instructions plus NOP, 92 burned rows**.
  Unused rows are safe NOP rows. The Dual-LUT configuration space
  (`256 × 256 × 8` carry selections) is much larger; it is not an installed
  instruction count.
- **Physical register array is 256 × 32-bit.** Current FPGA RTL combines three
  bank bits with each five-bit register field and keeps `r0` hardwired to zero.
  The historical 32,768-entry discrete-SRAM proposal required a seven-bit
  superbank and `SETBANK2`; neither is present in the current RTL or burned
  ISA. This is not a documented Artix-7 capacity limit.
- **Display is CPU-painted tile RAM plus independent scanout.** Games remain
  software; a future blitter is not a current capability.
- **ISA is a first-class input.** Overlay word + immediate box + dual-LUT absorb foreign encodings as maps onto muxes. Casual family count ~37 (CSV has more rows). See [ISA as a Wire](../log/2026-08-15%20-%20ISA%20as%20a%20Wire.md). Maps cover compute, shift, and register-access; not x86 segmentation or ARM TrustZone.
- **Software.** OS, assembler, and stack live in
  [`software/`](../../software/) and are summarized in the
  [Tomato OS guide](../../software/os/README.md).

Current fact wording comes from [`../status.md`](../status.md); dated journal
entries remain historical and may describe superseded ISA or register designs.
