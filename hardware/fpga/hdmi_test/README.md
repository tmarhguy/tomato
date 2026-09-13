# hdmi_test — 12-bit DVI PMOD bring-up (open-source flow)

640×480@60 color bars pushed out of a Nexys A7-100T through the **PMOD 12-bit DVI
v1.1b** (TFP410) on headers **JC + JD**. This is the pinout and timing reference
for everything that follows on the display side, including Tomato OS.

Story: [Pixels on the Glass](../../../docs/log/2026-08-28%20-%20Pixels%20on%20the%20Glass.md) ·
[The PMOD Pivot](../../../docs/log/2026-08-26%20-%20The%20PMOD%20Pivot.md)

| Item | Value |
|------|-------|
| Part | `xc7a100tcsg324-1` |
| Top | `main` ← [`rtl/main.sv`](rtl/main.sv) |
| Constraints | [`constr/hdmi.xdc`](constr/hdmi.xdc) |
| Pixel clock | 25 MHz (100 MHz ÷ 4), forwarded on `ODDR` |
| Output | R/G on JC, B + `CLK`/`HS`/`VS`/`DE` on JD |

Keep this around after the CPU works. It is the reference the core's board layer
is checked against: if video ever breaks after a core change, building this
isolates PMOD wiring and pixel timing from everything the CPU does.

## Toolchain

Vivado is not required, and openXC7's nix flake does not evaluate on Apple
Silicon (its `fpga-as` package is Linux-only). So the toolchain is assembled
from three sources:

| Stage | Tool | Source |
|-------|------|--------|
| Synthesis | `yosys` | OSS CAD Suite |
| Place & route | `nextpnr-xilinx`, `bbasm` | nixpkgs |
| Bitstream | `fasm2frames`, `xc7frames2bit` | Project X-Ray, built locally |
| Programming | `openFPGALoader` | OSS CAD Suite |

`nextpnr-xilinx` from nixpkgs also ships the **prjxray-db** device database and
the site metadata that `bbaexport.py` needs, so those are not cloned separately.

```
main.sv ──yosys──▶ main.json ──nextpnr-xilinx──▶ main.fasm
                                    ▲
                              chipdb.bin (once per part)

main.fasm ──fasm2frames──▶ main.frames ──xc7frames2bit──▶ main.bit
                                                              │
                                                    openFPGALoader
                                                              ▼
                                                        Nexys A7-100T
```

## One-time setup

```bash
cd hardware/fpga/hdmi_test
make setup
```

This downloads the OSS CAD Suite and builds the two Project X-Ray bitgen tools
into `../.tools/` (all gitignored). It takes several minutes. The toolchain and
the build rules are shared with [`../core`](../core/), so this only ever happens
once for both projects.

## Build and flash

Build directly — FPGA targets auto-enter the toolchain (`../scripts/env.sh` + nix shell) when it is not already active, so no `NIX_CONFIG` export is needed:

```bash
make          # synth → P&R → bit
make program  # flash the board
```

(From the repo root: `make hdmi` / `make hdmi-program`.)

The first build also generates the **chipdb** for `xc7a100tcsg324-1`. That step
takes several minutes and a few GB of RAM, but it is cached in
`build/chipdb/chipdb.bin` and reused by every later build.

Individual stages (same auto-enter):

```bash
make synth    # build/main.json
make chipdb   # build/chipdb/chipdb.bin
make pnr      # build/main.fasm
make bit      # build/main.bit
make clean    # drop build/, keep ../.tools/
```

## Expected result

Board powered, PMOD seated on JC + JD, HDMI connected, `cpu_resetn` not held:

- Red, green, blue, and white vertical bars fill the screen at 640×480
- The LED heartbeat blinks from `blink[23]` in `main.sv`

If the monitor stays dark but the LED blinks, suspect the PMOD seating or the
HDMI cable rather than the bitstream.

## Notes

- `ODDR` is a blackbox in Yosys's `cells_xtra.v` while `BUFG` lives in
  `cells_sim.v`, so synthesis reads both with `read_verilog -lib`.
- The two Vivado-only lines in the XDC (`CFGBVS`, `CONFIG_VOLTAGE`) are ignored
  by `nextpnr-xilinx`; the pin and clock constraints are what matter.
- `openFPGALoader -b nexys_a7_100` targets the 100T. Use `--detect` if the
  board is not found.
