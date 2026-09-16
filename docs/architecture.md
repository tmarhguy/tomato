# Tomato architecture

Tomato is a 32-bit architecture centered on a Dual-LUT ALU. This document
describes the current design shared by the repository's editable schematics,
FPGA implementation, ISA contract, and software. For concise status and exact
claim boundaries, see [`status.md`](status.md).

## Scope

Tomato exists in several forms, which must not be conflated:

- The **discrete ALU slice** is physically assembled 74xx hardware. It proves
  the ALU construction, not a complete discrete computer.
- **FPGA Tomato** is the complete machine implemented on a Nexys A7-100T. It
  can boot Tomato OS and drive the display and controls.
- **Virtual Tomato** is a functional browser ISA emulator. It is neither
  cycle-accurate RTL nor physical hardware.
- **RTL simulation** runs the machine and testbenches locally with Icarus.

The complete discrete computer remains a goal.

## Datapath

The instruction register, general-purpose data path, registers, and ALU are
32 bits wide. The core is a multi-cycle Von Neumann machine.

```text
program counter → memory → instruction register
                         ↓
                  register file 3R1W
                         ↓
               dual-LUT ALU / shift / mul-div
                         ↓
                 writeback and memory
```

The current FPGA register file is **256 × 32-bit**, arranged as eight banks of
32 registers. `r0` is hardwired to zero. Older journal entries describe a
32,768-register superbank design; that design is historical and is not present
in the current FPGA RTL. Authority:
[`hardware/fpga/core/rtl/regs.v`](../hardware/fpga/core/rtl/regs.v).

## Dual-LUT ALU

Each ALU bit applies two independently programmed three-input truth tables,
then combines their outputs through the arithmetic carry path:

```text
out = f(a, b, c) + g(a, b, c) + carry_in
```

The theoretical LUT/carry configuration space is not an instruction count.
The installed ISA is the subset named by the control ROM: **61 instructions
plus NOP, 62 burned rows** in a 512-row ROM.

The editable architecture source is under
[`hardware/digital/`](../hardware/digital/); the current FPGA realization is
under [`hardware/fpga/core/rtl/`](../hardware/fpga/core/rtl/); the burned
contract is [`isa/tomato.v1.csv`](isa/tomato.v1.csv).

## Instruction and control model

The 32-bit instruction word uses a 9-bit opcode and overlays operand,
immediate, branch, and jump fields according to instruction class. The opcode
addresses a 512-row control space. Burned rows cover ALU operations, memory,
control flow, shift, multiply/divide, and system behavior; unused rows are
safe NOP rows.

In the discrete design, decode is divided among local control boards so control
travels with the subsystem it drives. In FPGA Tomato, equivalent control is
implemented in RTL and generated burn tables. The machine-readable ISA wins
over prose when row names or counts disagree.

See [`isa/README.md`](isa/README.md) for editing and verification rules.

## Memory and I/O in FPGA Tomato

The FPGA machine uses word addressing. Its principal windows are:

| Window | Base word address | Purpose |
|---|---:|---|
| Data/program memory | `0x000000` | 16,384 × 32-bit program, data, and stack |
| Framebuffer | `0x300000` | 80 × 60 text tiles |
| Keyboard | `0x780000` | Keycode and ready/consume interface |

The board harness provides 640×480 scanout, five-button input, clock/reset,
and seven-segment output. These board-specific facilities are kept outside the
machine RTL where practical.

## Clock language

The Nexys A7 oscillator is 100 MHz. FPGA Tomato divides it by 16, so the CPU
runs at **6.25 MHz** by default; the pixel clock is 25 MHz. The **90 MHz**
number in the build is nextpnr's configured timing target. It is not the CPU
runtime frequency and does not by itself prove operation on a board.

## Software stack

[`software/assembler.py`](../software/assembler.py) is a two-pass assembler
driven by the ISA CSVs. [`software/os/`](../software/os/) contains TOMATO OS
v3.0 and linked firmware modules. The current OS has 14 menu entries, including
Envelop and Compiler. See the [OS guide](../software/os/README.md).

## Authority map

| Question | Current authority |
|---|---|
| Architecture schematic | `hardware/digital/` |
| FPGA behavior | `hardware/fpga/core/rtl/` |
| Burned ISA | `docs/isa/tomato.v1.csv` |
| Pseudo-instructions | `docs/isa/tomato.v1.pseudo.csv` |
| OS version/menu | `software/os/*.s` |
| Current prose/status | `docs/status.md` |
| Historical rationale | `docs/log/` |

The full precedence and update procedure are in
[`documentation-policy.md`](documentation-policy.md).
