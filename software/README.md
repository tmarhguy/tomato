# Tomato — Software

<p align="center"><strong>Assembler, vocabulary, and Tomato OS — every word a row of the ISA.</strong></p>

![Layer](https://img.shields.io/badge/Layer-Assembler%20%2B%20OS-2563EB) ![Authority](https://img.shields.io/badge/Authority-tomato.v1%20CSVs-011F5B)

Everything Tomato runs on itself: the assembler, the operating system, and the demo programs the testbenches check. Nothing here is cross-compiled — every word in these images is an opcode from [`docs/isa/tomato.v1.csv`](../docs/isa/tomato.v1.csv).

**Project map:** [Root README](../README.md) · [ISA](../docs/isa/README.md) · [FPGA core](../hardware/fpga/core/README.md) · Paper: [software.html](https://tomato.tmarhguy.com/software.html)

<p align="center">
  <img src="../web/assets/os/main-menu-screen.jpg" alt="Tomato OS main menu on HDMI" width="48%" />
  <img src="../web/assets/os/tetris-screen.jpg" alt="Tetris on Tomato OS" width="48%" />
</p>
<p align="center"><em>Tomato OS · menu and Tetris · <a href="https://tomato.tmarhguy.com/software.html">software sheet</a></em></p>

| Path | What |
|------|------|
| `assembler.py` | Two-pass assembler; the ISA CSVs are its only opcode source |
| `os/tomato_os.s` | Tomato OS — desktop, menu, six screens, four games |
| `asm/` | Small programs, each with a value a testbench asserts on |

---

## Table of Contents

- [Assemble](#assemble)
- [Two authorities](#two-authorities)
- [Syntax](#syntax)
- [Directives](#directives)
- [Tomato OS](#tomato-os)
- [Samples](#samples)

---

## Assemble

```bash
python3 software/assembler.py software/asm/counter.s -o hardware/fpga/core/tb/mem/counter.mem --list
```

From `hardware/fpga/core`: `make asm` builds every image, `make burn` packs them into the FPGA burn headers, `make os` runs the OS in simulation.

---

## Two authorities

The assembler holds no opcode table of its own. It reads both CSVs at startup, so growing the machine's vocabulary is a data change, not a code change.

| File | Holds |
|------|-------|
| [`tomato.v1.csv`](../docs/isa/tomato.v1.csv) | The 512 microcode ROM rows. 52 opcodes are burned; the rest are empty. |
| [`tomato.v1.pseudo.csv`](../docs/isa/tomato.v1.pseudo.csv) | 19 pseudo-instructions, each expanding into already-burned opcodes |

Check the second one against the first at any time:

```bash
python3 software/assembler.py --selftest
```

That assembles every pseudo twice — once as the pseudo, once as the instructions it claims to expand into — and fails if the two word images differ. `make -C hardware/fpga/core test` runs it as `asm-check`.

---

## Syntax

| Form | Example |
|------|---------|
| RRR | `ADD r4, r1, r2` |
| MOV | `MOV r1, r2` (rd ← rB) |
| unary | `ZERO r5` |
| ADDI/LW | `ADDI r1, r0, 10` / `LW r6, r5, 0` |
| SW | `SW r1, r5, 0` (data, base, imm8) |
| branch | `BNE loop` / `BEQ done` (PC-relative) |
| jump | `JMP loop` (absolute word address) |
| system | `NOP` / `HALT` / `RET` |

Comments: `;` or `#`. Labels: `name:`.

### Vocabulary

The CPU has only `BEQ` / `BNE` / `BLT` / `BGE`, and the compare that feeds them is a separate instruction, so plain intent used to read as two unrelated lines. These say it in one:

| Write | Get |
|-------|-----|
| `CALL puts` | `JAL r16, puts` — the link register |
| `BEQZ r22, done` | `CMP r22, r0` + `BEQ done` |
| `BNEZ`, `BLTZ`, `BGEZ` | the same shape, other conditions |
| `BLE done` | `BEQ done` + `BLT done` |
| `BGT done` | skip the `BGE` when the compare was equal |
| `LI r5, 100` | `ADDI r5, r0, 100` — value, not address |
| `TST r6` | `CMP r6, r0` |
| `INC` / `DEC` / `NEG` / `CLR` | in-place arithmetic, spelled out |
| `BZ` / `BNZ` / `BMI` / `BPL` | the conditionals, read after a `TST` |
| `BRA` / `ASL` | `JMP` / `LSL` under their usual names |

`LA rd, label` loads an address, and is the one thing limited to the low 4 KB — it assembles to `ADDI rd, r0, addr`, so the label must fit an unsigned 12-bit immediate. Pointer tables have no such limit: a `.word label` holds the full 32-bit address, which is how Tomato OS keeps its prose above `0x1000`.

---

## Directives

| Directive | Effect |
|-----------|--------|
| `.org addr` | Set the next word address (sparse image; holes are 0) |
| `.word n, n` | Emit raw 32-bit words — glyphs, tables, pointers |
| `.space n` | Reserve n zeroed words for something written at runtime |
| `.ascii "text"` | One word per character (memory is word-addressed) |
| `.asciz "text"` | The same, NUL-terminated |

---

## Tomato OS

`os/tomato_os.s` is the whole shell: boot splash, an 80×60 text desktop, a six-entry menu, and the screens behind it. See [hardware/fpga/core/README.md](../hardware/fpga/core/README.md) for what is on the screen and how the memory map is laid out.

---

## Samples

| Program | Check |
|---------|-------|
| `asm/counter.s` | r1 = disp = 10 |
| `asm/fib.s` | fib(8) → r1 = r6 = 21 |
| `asm/collatz.s` | n=27 → 111 steps in r1/disp |
| `asm/call.s` | JAL/RET → r1=99 r2=42 |
| `asm/bytes.s` | SB/LB signed byte |
| `asm/ecall.s` | trap + RET → r1=42 |
| `asm/softops.s` | ROR/LBU → r1=r6=129 |
| `asm/io.s` | IN/OUT keyboard echo |
| `asm/kb_mmio.s` | LW MMIO kb data/status |
