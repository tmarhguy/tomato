# Tomato — FPGA (Nexys A7-100T)

![Status](<https://img.shields.io/badge/Status-Active%20Development-2ea043>) ![Architecture](https://img.shields.io/badge/Architecture-32--bit-011F5B) ![License](https://img.shields.io/badge/License-SHL--2.1-990000) ![Logic](<https://img.shields.io/badge/Logic-74xx%20Discrete-EAB308>)

![ALU](<https://img.shields.io/badge/ALU-Dual--LUT%2074ACT-DC2626>) ![ISA](<https://img.shields.io/badge/ISA-512%20Opcodes-2563EB>) ![Microcode](<https://img.shields.io/badge/Microcode-Modular%20Decode-7C3AED>) ![PCB](<https://img.shields.io/badge/PCB-KiCad%2010-F59E0B?logo=kicad&logoColor=white>)

Artix-7 bring-up on the **Digilent Nexys A7-100T**. Two projects: [`hdmi_test`](hdmi_test/), the display bring-up that first lit a monitor, and [`core`](core/), the full **Tomato32** CPU running **Tomato OS** on that same monitor. Same ISA and datapath as the discrete build. Both build entirely with open-source tools — **no Vivado anywhere**.

**Board:** `xc7a100tcsg324-1` · **Stack:** Yosys → nextpnr-xilinx → Project X-Ray → openFPGALoader

**Project map:** [Root README](../../README.md) · [Hardware README](../README.md) · [hdmi_test/](hdmi_test/) · [core/](core/) · Journal: [Open-Source Synthesis Pivot](<../../docs/log/2026-08-28%20-%20Exploring%20Beyond%20Vivado%20-%20Open-Source%20Synthesis%20Pivot.md>) · [Pixels on the Glass](<../../docs/log/2026-08-28%20-%20Pixels%20on%20the%20Glass.md>)

<p align="center">
  <img src="../../web/assets/assembly/fpga-board-pmod.webp" alt="Nexys A7 with iCEBreaker 12-bit DVI PMOD on JC and JD, HDMI connected, DONE lit." width="70%" />
</p>
<p align="center"><em>Nexys A7 · iCEBreaker 12-bit DVI PMOD on JC + JD · <a href="hdmi_test/">hdmi_test</a></em></p>

<video src="../../web/assets/assembly/hdmi-test.mp4" poster="../../web/assets/assembly/hdmi-test.webp" controls playsinline style="display: block; margin: 0 auto; width: 70%;"></video>
<p align="center"><em>640×480 color bars · flashed with the <a href="hdmi_test/">open-source flow</a> below</em></p>

---

## Table of Contents

- [Projects](#projects)
- [The toolchain](#the-toolchain)
- [One-time setup](#one-time-setup)
- [Build and flash](#build-and-flash)
- [Simulation](#simulation)
- [Layout](#layout)
- [Related docs](#related-docs)

---

## Projects

| Project | Top | What it does | Docs |
|---------|-----|--------------|------|
| [`hdmi_test/`](hdmi_test/) | `main` | 640×480@60 colour bars out of the 12-bit DVI PMOD on **JC + JD** | [`hdmi_test/README.md`](hdmi_test/README.md) |
| [`core/`](core/) | `nexys_top` | The whole CPU: Tomato OS on the monitor, D-pad as keyboard, Icarus benches | [`core/README.md`](core/README.md) |

`hdmi_test` came first and stays: it is the pinout and pixel-timing reference the core's board layer reuses verbatim, and the thing to build when video breaks and you need to know whether the CPU is at fault.

---

## The toolchain

openXC7's Nix flake is Linux-only — its `fpga-as` package will not evaluate on Apple Silicon — so the toolchain is assembled from three places and layered onto `PATH` by [`scripts/env.sh`](scripts/env.sh):

| Stage | Tool | Source |
|-------|------|--------|
| Synthesis | `yosys` | OSS CAD Suite |
| Place & route | `nextpnr-xilinx`, `bbasm` | nixpkgs |
| Bitstream | `fasm2frames`, `xc7frames2bit` | Project X-Ray, built locally |
| Programming | `openFPGALoader` | OSS CAD Suite |

`nextpnr-xilinx` from nixpkgs also ships the **prjxray-db** device database and the site metadata `bbaexport.py` needs, so neither is cloned separately.

Both projects share one installation under `.tools/` and one set of build rules in [`common.mk`](common.mk); a project's own Makefile only names its top, sources, constraints, and target frequency.

**Prerequisites:** [Nix](https://nixos.org/download) · Nexys on USB · PMOD on **JC + JD** · HDMI connected

---

## One-time setup

```bash
make -C hardware/fpga/core setup
```

Downloads the OSS CAD Suite (~500 MB) and builds the Project X-Ray bitgen tools into `hardware/fpga/.tools/` (~2.7 GB total, gitignored). Run it from either project — the result is shared.

---

## Build and flash

From the repo root — no `cd`, no wrapper prefix, no nix setup:

```bash
make fpga          # synth → P&R → bit (auto-enters the toolchain)
make fpga-program  # flash the board
```

Or inside a project directory, where bare targets auto-enter the same way:

```bash
cd hardware/fpga/core
make               # synth → P&R → bit
make program       # flash the board
```

`../scripts/env.sh make program` still works — it is what the auto-enter calls under the hood, and what to use from inside an already-active nix shell.

The first build for a part also generates the **chipdb** (`build/chipdb/chipdb.bin`) — several minutes and a few GB of RAM, cached afterwards. `hdmi_test` rebuilds in about 14 seconds after that; the full CPU takes a few minutes.

Individual stages are `make synth`, `make chipdb`, `make pnr`, `make bit`. `make clean` drops `build/` and keeps the toolchain; `make distclean` removes the toolchain too.

**For the core, burn first.** Microcode and the boot image are compiled into the RTL as literal Verilog rather than loaded from a file, so they have to be regenerated after any change to the ISA or the OS:

```bash
make -C hardware/fpga/core burn BOOT=tomato_os
```

---

## Simulation

No FPGA tools required — Icarus Verilog only:

```bash
cd hardware/fpga/core
make test          # units, assembly programs, and the OS end to end
make os            # boot Tomato OS and print the screen as text
make burn-check    # microcode still matches docs/isa/tomato.v1.csv
```

With nix: `nix shell nixpkgs#iverilog -c make test`

---

## Layout

```
fpga/
├── README.md           ← you are here
├── common.mk           shared flow: yosys → nextpnr → prjxray → openFPGALoader
├── scripts/
│   ├── env.sh          toolchain wrapper — run every build through this
│   ├── setup-oss-cad.sh
│   └── setup-prjxray-tools.sh
├── hdmi_test/          → hdmi_test/README.md — DVI PMOD bring-up
│   ├── rtl/main.sv
│   └── constr/hdmi.xdc
└── core/               → core/README.md — the CPU, Tomato OS, benches
    ├── rtl/            the machine, faithful to the Digital sheet
    ├── rtl/board/      the FPGA harness: scanout, font ROM, keypad, DVI, 7-seg
    ├── constr/nexys.xdc
    └── tb/             Icarus benches
```

Generated at build time and gitignored: `.tools/`, each project's `build/`, and `core/sim/`.

---

## Related docs

| Doc | Link |
|-----|------|
| Tomato architecture | [Root README](../../README.md) |
| The CPU on an FPGA | [core/README.md](core/README.md) |
| DVI PMOD bring-up | [hdmi_test/README.md](hdmi_test/README.md) |
| Tomato OS source | [software/os/tomato_os.s](../../software/os/tomato_os.s) |
| ISA burn / microcode | [docs/isa/tomato.v1.csv](../../docs/isa/tomato.v1.csv) |
| Open-source toolchain pivot | [Exploring Beyond Vivado](<../../docs/log/2026-08-28%20-%20Exploring%20Beyond%20Vivado%20-%20Open-Source%20Synthesis%20Pivot.md>) |
| First HDMI on glass | [Pixels on the Glass](<../../docs/log/2026-08-28%20-%20Pixels%20on%20the%20Glass.md>) |
| PMOD decision | [The PMOD Pivot](<../../docs/log/2026-08-26%20-%20The%20PMOD%20Pivot.md>) |
