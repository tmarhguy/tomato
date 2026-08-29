# Tomato FPGA — the machine (`core`)

The whole Tomato32 CPU on a **Nexys A7-100T**, running **Tomato OS** on a monitor over the 12-bit DVI PMOD, driven by the board's five D-pad buttons. Built end to end with open-source tools — no Vivado.

**Part:** `xc7a100tcsg324-1` · **Top:** [`nexys_top`](rtl/board/nexys_top.v) · **Flow:** Yosys → nextpnr-xilinx → Project X-Ray → openFPGALoader

**Project map:** [FPGA README](../README.md) · [hdmi_test/](../hdmi_test/) — the DVI bring-up this reuses · [Tomato OS source](../../../software/os/tomato_os.s) · [ISA](../../../docs/isa/tomato.v1.csv)

---

## Table of Contents

- [What is on the screen](#what-is-on-the-screen)
- [Layout: the machine vs the harness](#layout-the-machine-vs-the-harness)
- [Build and flash](#build-and-flash)
- [Simulation](#simulation)
- [Board contract](#board-contract)
- [Results](#results)
- [Three concessions to the fabric](#three-concessions-to-the-fabric)

---

## What is on the screen

[Tomato OS](../../../software/os/tomato_os.s) paints an 80×60 text field and a menu you drive with the Nexys D-pad. **N17 (center) is Enter** — it opens the highlighted entry. Up/down move the highlight; left goes back; left/right steer in the games.

```
 TOMATO OS  v1.0                            Designed by Tyrone Marhguy
 dual-LUT3 ALU  -  524288 ops  -  32768 GPR 3R1W             READY
 ┌ MAIN MENU ─────────────────┐  ┌ THE MACHINE ──────────────┐
 │ ▶ System info              │  │ Designed by               │
 │   Palette                  │  │ TYRONE MARHGUY            │
 │   Font chart               │  │ Penn Engineering  2028    │
 │   Keypad test              │  │                           │
 │   Fibonacci                │  │ dual-LUT3 ALU, 524288 ops │
 │   Snake                    │  │ 32768 GPR, banked, 3R1W   │
 │   Tetris                   │  │ 512-row modular microcode │
 │   About Tomato             │  └───────────────────────────┘
 │   Memory map               │
 └────────────────────────────┘
 ↑ ↓ move    ENTER select    ← back
```

A boot splash (gold mark, **TOMATO OS v1.0**, progress bar) runs once before this desktop. System info is the spec sheet. About is signed. Fibonacci / Snake / Tetris play from the D-pad. The Nexys 7-seg follows the last nonzero writeback (or store), so it is not stuck at zero while the shell waits for a key.

Every screen is drawn by the CPU storing words into the framebuffer window. Nothing about the display is hardwired into the machine — the scanout just reads tile RAM.

Print it yourself without a board:

```bash
make os          # boots the OS in Icarus and dumps the framebuffer as text
```

---

## Layout: the machine vs the harness

The split is the point. `rtl/` is Tomato — the same datapath as the discrete build, one module per sheet of [`hardware/verilog/main.v`](../../verilog/main.v) as Digital exports it. `rtl/board/` is everything that exists only because this particular FPGA has pins.

```
core/
├── rtl/                the machine — faithful to the Digital sheet
│   ├── main.v          datapath + dmem + the tile RAM window
│   ├── alu.v           dual-LUT ALU, 1b → 4b → 8b → 32b
│   ├── control.v       512-row decode ROMs, microcode burned in
│   ├── muldiv.v shift.v regs.v ir.v pc.v sp.v bus.v wb.v lane.v vga.v
│   └── burn/           generated: microcode + boot image as literal Verilog
├── rtl/board/          the harness — only because this board has pins
│   ├── nexys_top.v     clocks, resets, pin map
│   ├── videoout.v      640×480@60 text-mode scanout
│   ├── font_rom.v      generated: 8×8 glyphs
│   ├── dvi_out.v       12-bit DVI PMOD output stage
│   ├── keypad.v        five buttons → debounced keycodes
│   └── hex.v           7-seg multiplexer
├── constr/nexys.xdc    pin constraints
└── tb/                 Icarus benches, unit through whole-OS
```

`main.v` exposes peripherals as ports, not pins — `kb_data`/`kb_ready`/`kb_rd`, `io_out`, `disp_value`, `halted`, and a tile RAM read port that takes its own clock. The board file is the only thing that knows a pin number.

---

## Build and flash

One-time, from `hardware/fpga/core`:

```bash
make setup     # OSS CAD Suite + Project X-Ray bitgen → ../.tools (~2.7 GB, gitignored)
```

Then always through `env.sh`, which layers the three tool sources onto `PATH`:

```bash
../scripts/env.sh make fpga      # yosys → nextpnr → prjxray → build/nexys_top.bit
../scripts/env.sh make program   # flash the board
```

The first build also generates the **chipdb** for the part (several minutes, a few GB of RAM), cached in `build/chipdb/` afterwards. Steady-state rebuilds are a few minutes.

Changed the OS or the microcode? Re-burn before synthesising — both are compiled into the RTL as literal Verilog, not loaded from a file at runtime:

```bash
make burn BOOT=tomato_os     # → rtl/burn/dmem_init.vh + microcode in control.v
```

---

## Simulation

Icarus only, no FPGA tools:

```bash
make test        # units, assembly programs, and the OS end to end
make os          # boot the OS and print the screen
make burn-check  # microcode still matches docs/isa/tomato.v1.csv
make cpi         # cycles-per-instruction table → reports/CPI.md
```

`make test` ends with `burn_boot`, which compiles *without* `-DTOMATO_SIM` — so it runs the same burned-in dmem and microcode the bitstream carries, and waits for the desktop to appear in tile RAM. If that passes, the image is really in the RTL.

---

## Board contract

| Signal | Pin | Role |
|--------|-----|------|
| `clk` | E3 | 100 MHz oscillator |
| `cpu_resetn` | C12 | red CPU_RESETN button, low when pressed |
| `btnc` | N17 | **Enter** — keycode `0x0D` |
| `btnu` | M18 | Up — `0x1E` |
| `btnd` | P18 | Down — `0x1F` |
| `btnl` | P17 | Left — `0x11` |
| `btnr` | M17 | Right — `0x10` |
| `dvi_*` | JC + JD | 12-bit DVI PMOD, same map as [`hdmi_test`](../hdmi_test/) |
| `seg`, `an`, `dp` | — | last register writeback, in hex |
| `led[15]` | — | heartbeat: the CPU clock is alive even if the monitor is dark |

The four arrow keycodes are also their own CP437 glyphs, so the OS can draw a key it just read without a lookup table.

**Memory map** (word addresses, decoded on `addr[21:19]`):

| Window | Base | Contents |
|--------|------|----------|
| dmem | `0x000000` | 16384 × 32, program and stack |
| framebuffer | `0x300000` | 80×60 tiles: `[7:0]` glyph, `[11:8]` fg, `[15:12]` bg |
| keyboard | `0x780000` | word 0 = keycode (reading consumes it), word 1 = ready |

A tile whose `[15:8]` is zero is a legacy solid-colour cell, so the old 4-bit-index framebuffer still renders.

---

## Results

Post-route, from `nextpnr-xilinx` on `xc7a100tcsg324-1`:

| Resource | Used | Part | % |
|----------|------|------|---|
| LUTs | 8852 | 126800 | 6% |
| Flip-flops | 323 | 126800 | 0% |
| CARRY4 | 508 | 15850 | 3% |
| RAMB36E1 | 20 | 135 | 14% |
| BUFGCTRL | 3 | 32 | 9% |
| DSP48E1 | 0 | 240 | 0% |

| Clock | Runs at | nextpnr Fmax | Margin |
|-------|---------|--------------|--------|
| `cpu_clk` | 6.25 MHz (100/16) | 104.18 MHz | 16× |
| `pix_clk` | 25 MHz (100/4) | 189.93 MHz | 7.6× |

The CPU divider is `CPU_DIV_LOG2` on `nexys_top`; at 6.25 MHz the OS paints its desktop in about 11 ms.

---

## Three concessions to the fabric

The datapath is unchanged, but three things about it do not exist in an Artix-7, and each one has a workaround worth knowing about.

**Data memory reads on the falling edge.** The Digital sheet's RAM is asynchronous, and both phases of the sequencer need the word in the cycle they present the address — FETCH latches it into IR, and a byte store merges it with the write data on the very edge that stores it. Block RAM has no asynchronous port, and 16K × 32 of asynchronous LUT storage is half a megabit of fabric. Sampling on the falling edge instead gives the word mid-cycle, before the edge that consumes it, and still returns pre-write contents to a store. It costs half a clock period of setup, which at 6.25 MHz is 80 ns, and keeps the sequencer at two phases.

**No DSPs.** A 33×33 multiply tiles across several DSP48s wired `PCOUT`→`PCIN`, and nextpnr places the halves in different DSP columns where no cascade wire exists — it places, then fails to route. `synth_xilinx -nodsp` puts the multiplier in LUTs, which the part has to spare. On the way there, `muldiv.v` lost its duplicate signed and unsigned multiplier and divider: one sign-extended multiply covers both signednesses, and dividing magnitudes then re-applying the signs covers both divisions.

**`--ignore-loops`.** The register file lands in distributed RAM, whose write-data pins are fed from its own read outputs. That is a clocked path, but nextpnr's SLICEM model has no `DI`→`O` arc to break, so its topological sort calls it a combinational loop and refuses to run. Skipping those arcs is the only way past it; every real path is still analysed against the target frequency.
