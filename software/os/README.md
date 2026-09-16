# Tomato OS

Tomato OS is the assembly-written interface and application collection that
boots on FPGA Tomato and in the repository's simulation/emulation targets.
The current source identifies **TOMATO OS v3.0** and contains **14 menu
entries**. **Desktop v1.2** names the workspace UI revision, not the OS version.

## Source layout

| File | Role |
|---|---|
| [`tomato_os.s`](tomato_os.s) | Boot, desktop, menu, applications, games, framebuffer and input services |
| [`envelop_lite.s`](envelop_lite.s) | Tomato-side Envelop client |
| [`envelop_setup.s`](envelop_setup.s) | Generated/static setup records consumed by the client |
| [`remote_exec.s`](remote_exec.s) | Bounded machine-side compute executor |

The FPGA build concatenates these assembly sources into one checked image.
Generated `.mem` and Verilog burn files are derivatives, not editable sources.

## Current menu

The 14 entries declared by `menu_items` and `n_menu` are:

1. System info
2. Tribonacci
3. Font chart
4. Keypad test
5. Fibonacci
6. Snake
7. Tetris
8. About Tomato
9. Memory map
10. Sudoku
11. ALU Studio
12. Racer
13. Compiler
14. Envelop

The OS paints an 80×60 tile framebuffer and reads the Nexys A7's five-button
input through the machine's memory-mapped interfaces. Screen drawing is
performed by Tomato code; the board scanout reads the resulting tile memory.

## Build and simulate

Assemble the complete OS image:

```bash
make -C hardware/fpga/core asm
```

Boot it in RTL simulation and print the framebuffer:

```bash
make -C hardware/fpga/core os
```

Run focused OS, menu, game, firmware, and core regressions:

```bash
make -C hardware/fpga/core test
```

These are software/simulation checks. They do not program a board and are not
evidence of a current physical deployment.

## Burned image

The OS and control tables are compiled into FPGA RTL burn headers:

```bash
make -C hardware/fpga/core burn BOOT=tomato_os
```

Run this before building a bitstream after OS or ISA changes. Burning here means
regenerating checked build inputs; programming the FPGA is a separate action.

## Envelop and Compiler

Envelop is one OS entry. Its machine-side client and bounded executor are linked
into the image, while user clients, backend, and nearby bridge are maintained
in the separate Envelop project.

Compiler/compute requests produce Tomato programs and results through explicit
execution targets. A local simulation or browser result must not be labeled as
physical FPGA execution. See [`../../docs/compute.md`](../../docs/compute.md).

## Authorities

- Version, menu, strings, and behavior: the assembly files in this directory.
- Opcode encoding: [`../../docs/isa/tomato.v1.csv`](../../docs/isa/tomato.v1.csv).
- Assembler expansions:
  [`../../docs/isa/tomato.v1.pseudo.csv`](../../docs/isa/tomato.v1.pseudo.csv).
- Current project facts: [`../../docs/status.md`](../../docs/status.md).
- FPGA memory map and board behavior:
  [`../../hardware/fpga/core/README.md`](../../hardware/fpga/core/README.md).

Historical screenshots and journal entries may show earlier splash versions,
entry counts, or labels. They remain historical evidence and do not override
the current assembly.
