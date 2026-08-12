# Tomato — FPGA bring-up (Nexys A7)

Artix-7 bitstream of Tomato32. Same ISA / datapath as discrete; board I/O below.

## Board I/O

| Pins | Role |
|------|------|
| `seg` / `an` / `dp` | 8-digit hex of **last register writeback** |
| `vga_hs` / `vga_vs` / `vga_r/g/b` | 640×480@60 from tile RAM scanout |
| `clk` / `reset` | 100 MHz, CPU_RESET |

No top-level `WB_MUX`, `DISP`, or `disp_read` — the FPGA polls tile RAM itself.

## Layout

```
tomato/
  rtl/            datapath + board top (main, hex, vga, vgatiming, …)
  constr/nexys.xdc
  tb/*_tb.v       self-checking Icarus benches
  Makefile
  sim/            build artifacts (gitignored)
```

## Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`). From this directory (not the repo-root `Makefile`):

```bash
cd hardware/fpga/tomato
make test          # all unit + main TBs
make shift         # one TB: shift lane wb bus sp regs ir pc vga
make main          #         muldiv alu control hex vgatiming main
make clean
```

With nix: `nix shell nixpkgs#iverilog -c make test` (or `./run_tb.sh`).

Self-checking benches print `PASS: <unit>` or `FAIL: …`.
`main` / `counter` are hand-coded smokes; **asm programs** load `tb/mem/*.mem` from `software/asm/*.s`.
`./run_tb.sh` or `make test` (adds `~/.nix-profile/bin` to `PATH` for iverilog).

## Microcode (512 rows)

Single ISA table: [tomato.v1.csv](../../../docs/isa/tomato.v1.csv).

```bash
python3 tools/gen_microcode_v1.py          # pack
python3 tools/gen_microcode_v1.py --check  # verify burn matches CSV
```

Packs `microcode/*.hex` + `tb/mem/*.mem` (control ROMs). Edit the CSV; re-run to burn.

## Mul / div (FPGA vs discrete)

FPGA `rtl/muldiv.v` uses operator `*` / `/` / `%` (synth to DSP/LUTs). The discrete priority-encoder multiply loop stays a KiCad story — not ported into this RTL.

## Assembly → hex

```bash
make asm                 # counter.mem
python3 ../../../software/assembler.py ../../../software/asm/counter.s -o tb/mem/counter.mem --list
```

See [software/README.md](../../../software/README.md).

## VGA tiles

MMIO window `mem_addr[21:19]==3'b110`, index `mem_addr[12:0]`.
**Locked geometry:** 80×60 cells of **8×8** pixels; color from tile word `[3:0]` (16-color palette).
See [software/os/DISPLAY.md](../../../software/os/DISPLAY.md).

## Vivado (Nexys A7 bitstream)

Self-contained RTL burn — see [rtl/VIVADO.md](rtl/VIVADO.md).

```bash
make burn              # opcodes + Tomato OS → rtl/burn/*.vh
make burn-boot         # Icarus proof: OS boots from burned dmem (no TB load)
# Vivado: add rtl/, top=nexys_top, constr/nexys.xdc, include dir=rtl/
make burn BOOT=snake   # re-burn a game image instead of OS (re-synth)
```

Microcode and the selected boot program are **literal Verilog** (`initial` + `.vh`), not external `$readmemh` paths Vivado can miss.

## Games (VGA)

| Target | What |
|--------|------|
| `make snake` | Snake: playfield + food; demo auto-eats → score≥1 (`wasd` / `q` interactive) |
| `make bounce` | Ball in a box; HALT after 12 wall hits |
| `make sudoku` | 9×9 board; demo fills one cell; row/col/box validate → r1=1 |
| `make shooter` | Space shooter: starfield + ship + aliens; demo kill → score≥1 |

Sources: `gen_snake.py`, `bounce.s`, `gen_sudoku.py`, `gen_shooter.py`.

## Tomato OS

Splash + menu launcher: [software/os/](../../../software/os/). Sim: `make tomato_os`.

```bash
make vga-snap   # 640×480 PNG of splash/menu → sim/vga_snap.png
make vga-live   # pygame window; keys 1/2/3/0 → real RTL IN
```

## Keyboard / UART glue

| Port / window | Role |
|---------------|------|
| `kb_data[7:0]` / `kb_ready` | Board inputs (PS/2 or UART RX) |
| `IN rd` (0xC8) | `rd ← {24'0, kb_data}` via lane sel=2 |
| `OUT rA` (0xC9) | latch `rA[7:0]` → `io_out` |
| MMIO `[21:19]==111` | word0 = data, word1 = `{ready}` (LW/LB alternate) |

Enforced by `make kb_io` / `tb/kb_io_tb.v` (IN/OUT, live key update, MMIO, IRQ-off, asm).
Asm: `software/asm/io.s`, `software/asm/kb_mmio.s`.

## ECALL

Trap vector `0x100`; `pc_link` = fall-through. Firmware: `software/asm/ecall.s` (SYS_PUT / SYS_GETC / exit).

## Control / hex

`control.v` loads `tb/mem/*.mem` via `$readmemh` (regenerate with `gen_microcode_v1.py`).
