# Tomato FPGA metrics (evidence log)

Only numbers with an in-tree artifact. Gaps stay gaps.

## Full CPU — `hardware/fpga/core`

| Metric | Value | Evidence |
|--------|-------|----------|
| Vivado project | `core.xpr`, Vivado 2025.2 | [core.xpr](../core.xpr) |
| Part / top | `xc7a100tcsg324-1` / `nexys_top` | same |
| Timing constraint used for closure | **125.000 ns (8.0 MHz)** | [nexys.xdc](../core.srcs/constrs_1/nexys.xdc) |
| Board oscillator | 100 MHz | XDC comment + Digilent pin E3 |
| Bitstream | Produced (`nexys_top.bit` path in `program_bit.tcl`) | [program_bit.tcl](../program_bit.tcl); runs dir gitignored |
| Post-route WNS / LUT% / Fmax-from-slack | **Not checked in** | Need local `impl_1/*timing_summary*.rpt` |

## Icarus CPI — `hardware/fpga/tomato` (`make cpi`)

Sim-only: cycle + fetch-retire from reset release to halt. **Not** a board MHz claim.

| Program | Cycles | Instr retired | CPI |
|---------|--------|---------------|-----|
| counter | 68 | 34 | **2.000** |
| fib | 134 | 66 | **2.030** |
| collatz | 2096 | 1048 | **2.000** |
| call | 12 | 6 | **2.000** |
| bytes | 23 | 9 | **2.556** |
| softops | 20 | 9 | **2.222** |

Mixed average ≈ **2.13**. Microcode `cycles` is 1 (F+E) or 2 (F+E+M). Full table: [CPI.md](CPI.md).

## Peripheral only — `hex_display` (do not sell as CPU)

| Metric | Value | Evidence |
|--------|-------|----------|
| WNS @ 10 ns | **+6.485 ns** → Fmax≈**284.5 MHz** | `hex_display.runs/impl_1/hex_seg_timing_summary_routed.rpt` |
| Slice LUTs | **16 / 63400 (0.03%)** | `hex_seg_utilization_placed.rpt` |

## ALU Sky130 (not the FPGA CPU)

See [verification/synthesis/README.md](../../../verification/synthesis/README.md): **6531 µm²**, **512** cells, **~210 MHz** registered estimate (TT liberty, pre-route).
