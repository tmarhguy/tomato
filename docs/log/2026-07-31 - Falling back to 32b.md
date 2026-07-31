# Falling back to 32b

**Date:** 2026-07-31  
**Status:** Decision settled — revert to Tomato32  
**Supersedes:** [Redesign into 40b](2026-07-30%20-%20Redesign%20into%2040b%20(Old%20design%20=%2032b).md)  
**Related:** [The lingering catch](2026-07-31%20-%20The%20lingering%20thoughts.md)

---

## Context

In a rather if not seemingly swing between implementations, I have reconsidered and am falling back to the **32b design**.

The [40b redesign](2026-07-30%20-%20Redesign%20into%2040b%20(Old%20design%20=%2032b).md) was intellectually clean — one word type, a fourth operand field, room for a larger INS table. I spent a day on the catalogs and the widening math. But building is the constraint, not the spreadsheet.

---

## Why not 40b (for now)

40b is admittedly weird — perhaps as weird a number as Tomato has always been. But that sheer narrative needs no regularly accompanying weirdness.

40b does offer the balance to access a large **~8000 GPR** address space if you widen every field and rebuild every board. That should be treated as a **possibility**, not a required discipline to follow. Tomato was already unconventional; stacking an unconventional word width on top of an unconventional ALU doubles the explanation burden without doubling the silicon on the bench.

---

## What I'm keeping

With that, I am **reverting from 40b to 32b**, and:

- **Limiting the opcode space to 512 rows** — **9-bit** ROM index (`[31:23]`).
- **Four 5-bit operand fields** (`rd`, `rA`, `rB`, `rC`) plus **3-bit `BANK`** (`[2:0]`) — 32 GPR per bank × 8 banks = **256** addressable registers.

256 GPR is a tiny percentage of ~8000. It is still real memory real estate in conventional computing terms — banks you can actually name, spill to, and wire on modular boards without a full datapath rebuild.

The persisting **dark silicon** — the address space and LUT catalog we did not map into opcodes — can be accessed in the future whenever a need arises. The ALU still knows more functions than the instruction ROM exposes today; that was always the plan.

---

## What changes in practice

| Area | 40b experiment (set aside) | 32b (current) |
|------|---------------------------|---------------|
| Instruction / machine word | 40 bits, unified | 32 bits |
| Opcode ROM | 4096-row INS table | **512 rows** |
| Register file | 4 read ports, 6-bit addr | 3R1W, 32 GPR × 8 banks |
| Digital target | `alu-40b-final.dig`, widened `main` | `alu-32b-final.dig`, `main.dig` |
| ISA authority | `tomato.csv` at 4096 | `opcode-map.csv`, 9-bit opcode + 5-bit fields |

No fourth read port. No 40-bit RAM widening on bring-up. The ALU PCB (`07_alu`) stays as built — the slice is still 32-bit wide per lane in the current KiCad tree.

---

## Open questions

- Exact 512-row region map: which 256 slots stay native, which hold LUT catalog entries, which remain reserved?
- Whether `C` stays on a dedicated `rC` field (`[7:3]`) vs W readback for some mnemonics.
- How much of the 40b catalog work in `docs/isa/` to keep as reference vs trim.

---

## Lean recommendation (today)

Ship **32b Tomato**. Run Digital on `main.dig`, keep verification on the 32b ALU export, and put fab time toward peripherals and control boards — not another word-width pivot.

The swing was useful. The answer is not more weirdness; it is the machine we already know how to wire.
