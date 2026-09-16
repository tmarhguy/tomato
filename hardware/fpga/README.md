# Tomato FPGA

This directory contains the complete Tomato machine for the Digilent Nexys
A7-100T (`xc7a100tcsg324-1`) and a smaller display bring-up project.

<p align="center">
  <img src="../../web/assets/assembly/fpga-board-pmod.webp" alt="Nexys A7 used by FPGA Tomato" width="70%">
</p>

## Projects

| Project | Purpose |
|---|---|
| [`core/`](core/) | Complete 32-bit Tomato CPU, Tomato OS, board harness, and Icarus tests |
| [`hdmi_test/`](hdmi_test/) | Independent 640×480 display/pinout bring-up |

The core implements **256 × 32-bit registers**, **61 instructions plus NOP
(62 burned rows)**, and TOMATO OS v3.0 with 14 menu entries. The CPU runs at
**6.25 MHz** by default from the board's 100 MHz oscillator; display scanout
uses 25 MHz.

The `FREQ_MHZ := 90` build setting is a nextpnr timing target, not the runtime
CPU frequency and not a hardware-performance claim.

## Build flows

The default flow is:

`Yosys → nextpnr-xilinx → Project X-Ray`

Programming uses `openFPGALoader`. An optional Linux-only Vivado batch target
is available for the same core and board. Neither build route proves that a
board is currently programmed.

One-time open-source setup:

```bash
make -C hardware/fpga/core setup
```

Build from the repository root:

```bash
make fpga
```

Or build the core directly:

```bash
make -C hardware/fpga/core fpga
```

The hardware-changing programming step is deliberately separate:

```bash
make fpga-program
```

After changing the ISA or OS, regenerate the burn before synthesis:

```bash
make -C hardware/fpga/core burn BOOT=tomato_os
```

## Focused simulation

No FPGA toolchain is required for the Icarus checks:

```bash
make -C hardware/fpga/core burn-check
make -C hardware/fpga/core os
make -C hardware/fpga/core test
```

Simulation results must be labeled RTL simulation. Building or simulating is
not evidence of physical execution.

## Layout

| Path | Contents |
|---|---|
| [`common.mk`](common.mk) | Shared open-source build rules |
| [`scripts/`](scripts/) | Toolchain setup and environment |
| [`core/rtl/`](core/rtl/) | Machine RTL |
| [`core/rtl/board/`](core/rtl/board/) | Board clocks, reset, display, buttons, and seven-segment harness |
| [`core/tb/`](core/tb/) | Unit, program, OS, and integration testbenches |
| [`core/constr/`](core/constr/) | Nexys A7 constraints |

Generated `.tools/`, `build/`, and `sim/` directories are not source
authorities.

## Continue

- [FPGA core](core/README.md)
- [Architecture](../../docs/architecture.md)
- [Tomato OS](../../software/os/README.md)
- [ISA](../../docs/isa/README.md)
- [Current status](../../docs/status.md)
