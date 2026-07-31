# The lingering catch

**Date:** 2026-07-31  
**Status:** Decision in progress — bring-up strategy  
**Related:** [Redesign into 40b](2026-07-30%20-%20Redesign%20into%2040b%20(Old%20design%20=%2032b).md)

---

## Context

The ALU is routed and ready for PCB fabrication. That was the hardest slice of the datapath — three-operand LUT3, carry select, the full combinational core. The lingering problem is not the ALU itself but **what drives it**.

To test an ALU in isolation you need something to sequence operands, select microcode, and clock writeback. That means either:

1. A **minimal custom FSM** — enough logic to exercise the slice, not a full CPU.
2. A **control unit** — which is, by definition, Tomato.

Both paths have the same trap.

---

## The FSM option

A bare FSM can be kept simple — counter, a few mux selects, hard-wired test vectors. Simple FSMs tend to **only count**: increment, wrap, maybe toggle a carry bit. Useful for smoke tests, not for validating real ISA behavior or multi-cycle sequences.

A complex FSM that actually exercises LUT programs, operand routing, and multi-phase timing starts to **duplicate the control unit** — same ROM decode, same field fanout, same wiring problem documented in the microcode modularization log. Building that twice is double work.

The FSM path is proving slow anyway. The design keeps drifting toward "just enough control to be Tomato" without the payoff of a runnable machine.

---

## The peripherals option

The alternative: **skip the interim FSM** and build the rest of the machine while the ALU goes to fab.

The control boards (`alu-control`, `ir-reg-control`, `mem-io-control`, `mem-bus-control`, `pc-control`, `shift-mul-control`) already exist in simulation on `main`. Register file, memory bus, PC/stack, mul-div — these are the remaining physical slices. The ALU was the most complex combinatorial block; the peripherals are mostly sequencing, decode fanout, and standard 74xx glue.

With the move to 40-bit (see 2026-07-30 log), some of those boards need widening and a fourth read port — but the modular split means each board can be validated against its local decode ROM before the full system is wired.

---

## Fabrication leverage

A PCB house can **route and assemble** the ALU board. That removes the weeks of hand-wiring that made the ALU bring-up so painful. While the fab runs, peripheral boards can be designed, simulated, and partially built in parallel — time that would otherwise sit idle waiting on the ALU.

The question is whether to spend that parallel window on a throwaway FSM or on slices that ship inside the final machine.

---

## Open questions

- Is a minimal FSM still worth building for ALU board acceptance testing before the full control unit exists?
- If yes, what is the minimum test set? (Known LUT pairs, carry-chain walk, display bus sanity?)
- If no, can `alu-display-control` plus hard-wired vectors on the fab board prove the slice without a sequencer?
- Order of peripheral builds: control unit first (unblocks everything) vs register file first (unblocks ALU loopback tests in sim)?

---

## Lean recommendation (today)

Build the **peripherals**, not a standalone FSM. Use `alu-display-control` and simulation test vectors for ALU board bring-up. Invest design time in control-unit ROM images and the 40-bit widening rather than a second decode tree that gets discarded.

The lingering catch was always "I need control logic to test control logic." The modular control boards are the answer — they were designed to be built and tested piecemeal. Use that.
