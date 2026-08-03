# Designing additional boards

**Date:** 2026-08-02  
**Status:** In progress — peripheral PCB design  
**Related:** [Falling back to 32b](2026-07-31%20-%20Falling%20back%20to%2032b.md) · [The lingering catch](2026-07-31%20-%20The%20lingering%20thoughts.md) · [07 ALU board doc](../../hardware/kicad/boards/07_alu/README.md)

---

## Context

I am pushing to design the remaining boards.

I had assumed that the most complicated one to design was the main board — the **ALU** — which is done and routed ([`07_alu`](../../hardware/kicad/boards/07_alu/README.md)). The next thing is everything else: register file, memory, PC/stack, data bus, shift/mul-div. The ALU was the deep combinational problem; what is left is mostly **32-bit plumbing** — mux trees, decode fanout, and connectors that do not fight the floor plan.

That is the plan [from last week](2026-07-31%20-%20The%20lingering%20thoughts.md): while the ALU fab runs, design slices that ship in the final machine instead of a throwaway FSM.

---

## Starting with multiplexers

The first slice I am tackling is the **multiplexers** on the data path — writeback mux, bus arbitration, and the glue that ties ALU, memory, and register ports onto one 32-bit highway.

A naïve 32-bit mux bank (one huge `74257` tree per source, every bit routed independently) costs **hundreds of millimetres** of trace and real estate. The approach for Tomato:

1. **Bus drivers** (`74AC125` / tri-state family) on each contributor — ALU result, memory read, PC+1, shift/mul, etc.
2. **Matched decode enables** from the modular control boards — only one driver active per phase, same idea as the [ALU display scan chain](2026-06-19%20-%20ALU%20segment%20display%20design.md) (one hot index, shared bus).
3. **KiCad target:** [06_data_bus](../../hardware/kicad/boards/06_data_bus/) — `wb_mux.kicad_sch`, `bus_arbitration.kicad_sch`, tied to Digital [`wb_mux.dig`](../../hardware/digital/modules/wb_mux.dig) and [`bus-arbitration.dig`](../../hardware/digital/modules/bus-arbitration.dig).

Digital already has the behavior; the board work is making the 32-bit fanout **physically tolerable**.

---

## Contention and timing

Contention is a real issue on a shared tri-state bus — two drivers fighting the same line is not theoretical.

But I am not running at GHz. At breadboard / bring-up clock rates, the window where two enables overlap badly is small. From earlier calculations, the chance of meaningful contention during switching is **~1%**, or more accurately **under 5%** of transitions — acceptable for lab bring-up if decode is one-hot and enables are never deliberately stacked.

Heat from brief overlap at these speeds should be ok. Production hygiene still matters: **one active driver per bus**, decode timed to the sequencer phases documented in [Load Store Pipeline Analysis](2026-06-11%20-%20Load%20Store%20Pipeline%20Analysis.md).

---

## Board queue (after ALU)

| Board | KiCad | Digital anchor | Notes |
|-------|-------|----------------|-------|
| **06** data bus | [06_data_bus/](../../hardware/kicad/boards/06_data_bus/) | `wb_mux`, `bus-arbitration` | **Current focus** — mux + drivers |
| 04 register | [04_register/](../../hardware/kicad/boards/04_register/) | `register.dig`, `ir.dig` | 3R1W, 32 GPR × 8 banks |
| 05 PC / SP | [05_program_counter/](../../hardware/kicad/boards/05_program_counter/) | `program-counter.dig`, `sp.dig` | Fetch address source |
| 03 memory | [03_memory/](../../hardware/kicad/boards/03_memory/) | `memory.dig`, `byte-lane-decoder` | Load/store path |
| 02 shift / mul-div | [02_shift_encoder/](../../hardware/kicad/boards/02_shift_encoder/) | `mul-div.dig`, `shift-mul-control` | [Priority-encoder mul](2026-06-15%20-%20Multiplication%20and%20Division.md) |
| 08 display / FSM | [08_display/](../../hardware/kicad/boards/08_display/), `08_alu_fsm` | `alu-display-control` | Bench debug |

Control ROM boards ([microcode modularization](2026-06-16%20-%20Microcode%20Control%20Modularization.md)) ride with their datapath slices — not a separate queue item.

---

## Open questions

- One consolidated **06_data_bus** PCB vs split wb_mux and arbitration across connectors?
- Which `74xx` driver family on the 32-bit backplane — `AC125` vs `HC125` vs registered enables for cleaner turn-off?
- Order after mux: register file (loopback tests) vs memory (load/store integration)?
- Re-run contention estimate at target max clock once sequencer timing is nailed down.

---

## Lean recommendation (today)

Finish the **mux + driver** plan on `06_data_bus` in KiCad first — it unblocks every other board that needs to read or write the shared 32-bit word. Keep enables decode-driven and one-hot; do not sprawl a discrete 32-bit mux forest across the whole CPU footprint.

The ALU was the hard part. The rest is wiring Tomato's existing simulation into boards that fit the bench.
