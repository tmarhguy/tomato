It was only right to start Tomato with the conventional **32 general-purpose registers**. But there was an obvious waste: the discrete register file was already going to use parallel asynchronous SRAMs with thousands of available addresses.

## From 32 GPR to 32,768 GPR

> [!NOTE] Why 32,768 GPR?
>
> Tomato exposes **32,768 32-bit GPR locations** because the selected discrete SRAMs (**AS6C62256-55PCN**, 32K × 8) already provide a full **15-bit address space**. The chips, buses, and mirrored 3R1W structure are already in the design — exposing anything less would leave usable address depth disconnected.
>
> That is **half** the 65,536 × 32-bit physical register file in a single NVIDIA Blackwell SM.

```mermaid
flowchart LR
  A["32 GPR<br/>register:5"] --> B["256 GPR<br/>+ bank:3"] --> C["32,768 GPR<br/>+ superbank:7"]
  style A fill:#efe9d8,stroke:#8b1e1e,color:#1a1612
  style B fill:#e8e3d4,stroke:#8b1e1e,color:#1a1612
  style C fill:#8b1e1e,stroke:#1a1612,color:#f4f0e6
```

1. **32 GPR** — `register:5`
2. **256 GPR** — add the existing `bank:3`
3. **32,768 GPR** — add a latched `superbank:7`

Final SRAM address — **7 + 3 + 5 = 15 bits → 32,768 × 32-bit locations**:

```text
[ superbank:7 ][ bank:3 ][ register:5 ]
```

The 7-bit secondary bank is **not** carried inside every ordinary instruction. It is architectural state. A dedicated custom op changes it:

```text
SETBANK2 0x03          →  superbank_latch ← 0x03
physical_address       =  { superbank_latch, bank, register }
```

One operation changes the entire visible **256-register window** — no copying, no spill to RAM, no widening normal instructions. Ordinary encoding stays:

```text
[ opcode:9 ][ A:5 ][ B:5 ][ C/D:5 ][ bank:3 ]
```

while the upper seven address bits live in the latch until the next `SETBANK2`.

## Why plain SRAM gives Tomato 3R1W

Tomato's ALU needs three independent register operands, so the file needs **three reads and one write**. Ordinary async SRAM does not provide that, so the file is mirrored three times.

Four ×8 SRAMs make one 32-bit mirror (`4 × (32K × 8) = 32K × 32`). Three identical mirrors give the three read ports:

```text
             READ A        READ B        READ C
            Mirror A      Mirror B      Mirror C
             SRAM ×4       SRAM ×4       SRAM ×4
                ↑             ↑             ↑
                └──── broadcast write ─────┘
```

Writes broadcast address and data to all three; reads present independent addresses. Effective **3R1W from 12 ordinary SRAM chips** — no exotic multiported part.

## The waste that started this

On an 8K-deep device, 32 architectural registers used **0.39%** of the address depth. Tomato's existing 3-bit bank field grew that to **256 GPR** — still only **3.125%**. The SRAMs, PCB area, 32-bit buses, and three mirrors were already paid for. The unused depth was just sitting there.

## SRAM upgrade: AS6C6264 → AS6C62256

|                             |       AS6C6264 | **AS6C62256-55PCN** |
| --------------------------- | -------------: | ------------------: |
| Organization                |         8K × 8 |         **32K × 8** |
| Capacity                    |        64 Kbit |        **256 Kbit** |
| Address bits                |             13 |              **15** |
| 32-bit addresses per mirror |          8,192 |          **32,768** |
| Access time                 |          55 ns |           **55 ns** |
| Supply                      |      2.7–5.5 V |       **2.7–5.5 V** |
| Interface                   | Async parallel |  **Async parallel** |
| Chips needed for 3R1W       |             12 |              **12** |
| Approx. 12-chip cost\*      |       ~USD 114 |        **~USD 122** |

\*Pricing observed during this comparison; distributor and quantity pricing will move.

For roughly **USD 7 more** across the whole register file: **4× the depth**, same chip count, same 55 ns class. So instead of leaving two address lines unused, expose the full device:

```text
128 superbanks  ×  8 primary banks  ×  32 registers  =  32,768 GPR
```

And yes — that number is absurd.

## How absurd?

| Architecture     |           Integer / register space |
| ---------------- | ---------------------------------: |
| x86-64           |                             **16** |
| ARM AArch64      |                             **31** |
| RISC-V RV32I     |                             **32** |
| NVIDIA Blackwell | **255 / thread** · **65,536 / SM** |
| **Tomato**       |                         **32,768** |

So: **2,048×** x86-64, **1,024×** RV32I, **half** a Blackwell SM — **32,768**, period. The AS6C62256 presents fifteen address bits; once twelve of those chips are in the BOM for 3R1W, wiring them fully is the only move that isn't waste.

A flat 32K-register ISA would still be terrible: fifteen bits per operand × four → **60 bits** just naming registers. Banking keeps the common 5-bit fields and amortizes the upper bits:

```text
SETBANK2 0x57

ADD r4, r7, r12
MUL r2, r9, r20
…
```

All of those ops stay inside the window selected by `0x57` until another bank op changes it. Huge file; ordinary instruction width unchanged.

## Final organization

```text
                 superbank latch (7)
                            │
Normal instruction: [ bank:3 ][ register:5 ]
                            │
                   15-bit SRAM address
                            │
                     1 of 32,768 GPR
```

```text
read_A = { superbank, bank, reg_A }
read_B = { superbank, bank, reg_B }
read_C = { superbank, bank, reg_C }
write  = { superbank, bank, reg_D }   # broadcast to all mirrors
```

## Next

1. Add the 7-bit secondary-bank latch and custom `SETBANK2`
2. Simulate and test in Hneemann's Digital
3. Update KiCad register-file / control schematics and SRAM routing
4. Update the hand-written Verilog / SystemVerilog FPGA core
5. Test bank switching, isolation, mirrored writes, independent 3R reads, and preservation across superbanks
6. Run architectural / program regressions
7. Yosys and the rest of the open-source FPGA flow for hardware bring-up

This started as trying not to waste an SRAM. Now Tomato has **32,768 GPR** — because the chips come with **15 address bits**, and using any less is a waste.
