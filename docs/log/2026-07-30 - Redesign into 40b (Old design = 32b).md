# Redesign into 40b

**Date:** 2026-07-30  
**Status:** Decision in progress — full rebuild planned  
**Supersedes:** Tomato32 (32-bit word, 32-bit instruction)

---

## Context

After roughly three months working on Tomato32, the recurring bottleneck has been **instruction width**, not the ALU itself.

Convention says a 32-bit machine gets a 32-bit instruction word. That fit was always tight: 10 bits of opcode, three 6-bit register fields, and 4 bits of bank select exactly fill 32 bits — with no room for a fourth operand and with the lower 22 bits double-booked as offset/immediate overlay. The CPU was designed around a powerful ALU but forced to speak about it through a cramped encoding.

---

## What the ALU actually is

Tomato's ALU is built for **three operands in one combinational pass**:

```
alu_out = adder( f(a, b, c), g(a, b, c), carry_in )
```

where `f` and `g` are independent 3-input LUTs (`lutA`, `lutB`) and `carry_in` is selected by `csel`.

At the bit-slice level that is **524,288** distinct `(lutA, lutB, csel)` combinations. The current 10-bit opcode indexes only **1,024** microcode rows. That is enough for a practical ISA, but it uses a small fraction of what the hardware can express — the catalog today covers on the order of ~90 verified primitives, and most mnemonics share the same LUT program anyway.

Matching every theoretical LUT pair to its own opcode was never the goal. The real loss in the 32-bit design is narrower:

- No honest fourth register field (`C` was aliased to dest readback).
- Opcode space and immediate layout fighting over the same bits.
- Instruction word ≠ machine word — constants, literals, and fetched insns are different types.

---

## The move to 40 bits

The decision: **rebuild as a unified 40-bit machine** — not a 32-bit core with a wider instruction sidecar.

One word type everywhere: fetch, IR, registers, ALU, memory, and writeback.

### Canonical word layout

| Field      | Bits   | Role                                      |
|------------|--------|-------------------------------------------|
| `INS`      | 12     | Control index → microcode ROMs (4096 rows) |
| `ADDR_W`   | 6      | Destination (write port)                  |
| `ADDR_A`   | 6      | ALU operand A                             |
| `ADDR_B`   | 6      | ALU operand B                             |
| `ADDR_C`   | 6      | ALU operand C (independent third source)  |
| `BANK_SEL` | 4      | Register bank select                      |
| **Total**  | **40** |                                           |

```
[39:28]  INS
[27:22]  ADDR_W
[21:16]  ADDR_A
[15:10]  ADDR_B
[ 9: 4]  ADDR_C
[ 3: 0]  BANK_SEL
```

Syntax becomes what the datapath always wanted:

```asm
INS  d, a, b, c    ; rd = f(a,b,c) + g(a,b,c) + cin
```

`INS` selects behavior (ALU primitive, mem op, branch, immediate repacking). The four address fields are operands — or reinterpreted as offset/immediate chunks when microcode says so.

---

## Why 40 is the right number

Forty bits sounds odd until you account for what was already odd in Tomato32:

| Quirk                         | 32-bit world              | 40-bit world                    |
|-------------------------------|---------------------------|---------------------------------|
| Dual-LUT ALU (`f + g + cin`)  | Hidden behind microcode   | Same hardware, honest 4-operand |
| Immediate / offset overlay    | Fights register fields    | `INS` picks field repacking     |
| Byte lane decoder             | 4 bytes per word          | 5 bytes per word (or word-only v1) |
| 3R1W register file            | C tied to W readback      | Fourth read port for `ADDR_C`   |
| Physical reg RAM capacity     | 8k locations per slice    | 6-bit addr × bank — not capped at 16 |

The oddity was never the word width. It was hiding non-conventional structure inside a conventional 32-bit envelope.

With 40 bits, fetch is one memory read → IR. Writeback, literals, and jump-table entries share the same format as instructions. **Instruction = machine word.**

---

## What changes in practice

**Hardware (full rebuild):**

- Widen reg file, ALU, wb_mux, and main RAM datapath to 40 bits.
- Add a fourth register read port wired to `ADDR_C`.
- Expand control ROM address from 10 to 12 bits (`INS[11:0]`).
- PC/SP: word-oriented increment (`PC+1` per instruction).
- VGA and narrow I/O stay 32-bit at the port boundary (`[31:0]` slice).

**Memory (decision pending):**

- **v1 recommendation:** word-addressed — no divide-by-5 byte logic on bring-up.
- **Physical storage:** 64-bit RAM slots holding one 40-bit logical word is synthesis-friendly.
- Byte load/store can follow once the core runs.

**Software / ISA docs:**

- `opcodes.csv` grows to 4096-row address space.
- ISA profiles (RV32, MIPS, etc.) still map at assembly level onto native `INS` + four fields; binary format changes.
- Project may rename to Tomato40; name TBD.

---

## What this machine becomes

Tomato stops trying to be "a 32-bit RISC with a fancy ALU bolted on." It becomes a **programmable logic + adder machine with registers and memory** — Von Neumann, multi-cycle, single native encoding.

It can still *emulate* other ISAs through profiles, but the ground truth is one 40-bit word and a 12-bit control catalog. The ALU's `f(a,b,c) + g(a,b,c) + carry_in` model is the center; the instruction word is finally wide enough to describe it without compromise.

---

## Open questions

- Word-addressed only at first, or byte-addressed with 48-bit physical containers?
- How aggressively to populate the 4096-row `INS` table with raw LUT primitives vs named mnemonics?
- Sub-word store merge hardware — same problem as Tomato32, still needs a policy (RMW vs write-mask).
