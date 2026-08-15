# Tomato FPGA — Vivado project (`core`)

This is the **Nexys A7 bitstream project** for the full Tomato CPU (`nexys_top`), not a peripheral toy.

| Item | Value |
|------|-------|
| Project | [`core.xpr`](core.xpr) (Vivado **2025.2**) |
| Part | `xc7a100tcsg324-1` |
| Top | `nexys_top` ← sources under [`../tomato/rtl/`](../tomato/rtl/) |
| Constraints | [`core.srcs/constrs_1/nexys.xdc`](core.srcs/constrs_1/nexys.xdc) |
| Program script | [`program_bit.tcl`](program_bit.tcl) → `core.runs/impl_1/nexys_top.bit` |

Commit note: `fpga: tomato fpga implementation (success)` (bitstream produced on the Windows/OneDrive tree).

## Timing target (what actually closed)

From the **checked-in** XDC (authoritative for this project):

```tcl
# temporary: relaxed for impl closure
# Board oscillator is still 100 MHz; this only sets Vivado's analysis period.
# Restore 10.000 / {0.000 5.000} once muldiv/dmem timing is fixed.
create_clock -period 125.000 -name sys_clk -waveform {0.000 62.500} [get_ports clk]
```

| Claim | Number | Confidence |
|-------|--------|------------|
| Analysis period used for impl closure | **125 ns → 8.0 MHz** | **High** (in-repo XDC) |
| Board oscillator | **100 MHz** (Digilent E3) | **High** (board + comment) |
| Post-route WNS / util / Fmax-from-slack | *not in git* | Runs under `core.runs/` are gitignored; no `.rpt` checked in |
| “Runs at 100 MHz on the wire” | **Not proven** in-repo | Would need a 10 ns constraint that closes, or measured board Fmax |

Do **not** cite hex_display WNS (+6.485 ns @ 100 MHz, 16 LUTs) as Tomato CPU timing — that project is a 7-seg stub only.

## Port contract

`nexys_top` uses Digilent **`cpu_resetn`** (active-low press). The local XDC matches that. Older notes pointing at a `reset` port are stale.

## Bring-up

```bash
# Refresh burned microcode + boot image first
make -C ../tomato burn

# In Vivado: open core.xpr → synth → impl → bitstream
# Or program an existing bit:
vivado -mode batch -source program_bit.tcl
```

When you re-run impl, copy the timing/utilization summaries into [`reports/`](reports/) (tracked markdown summaries only — raw `.rpt` stay gitignored) so the README can cite measured WNS.
