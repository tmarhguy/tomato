# Tomato FPGA metrics (evidence log)

Only numbers with an in-tree artifact. Gaps stay gaps.

## Full CPU — `hardware/fpga/core`

Post-route on `xc7a100tcsg324-1`, top `nexys_top`, from `nextpnr-xilinx`. Reproduce with `../scripts/env.sh make fpga` from `hardware/fpga/core`; the log is not checked in, `build/` is gitignored.

| Metric | Value |
|--------|-------|
| Flow | yosys → nextpnr-xilinx → prjxray → openFPGALoader (no Vivado) |
| Synthesis options | `synth_xilinx -flatten -abc9 -nodsp` |
| Board oscillator | 100 MHz (Digilent pin E3) |
| CPU clock | **6.25 MHz** (100 ÷ 16, `CPU_DIV_LOG2 = 4`) |
| Pixel clock | **25 MHz** (100 ÷ 4), 640×480@60 |
| Bitstream | `build/nexys_top.bit`, 3.8 MB |

### Utilisation

| Resource | Used | Available | % |
|----------|------|-----------|---|
| LUTs | 8852 | 126800 | 6% |
| Flip-flops | 323 | 126800 | 0% |
| CARRY4 | 508 | 15850 | 3% |
| RAMB36E1 | 20 | 135 | 14% |
| RAMB18E1 | 1 | 270 | 0% |
| BUFGCTRL | 3 | 32 | 9% |
| DSP48E1 | 0 | 240 | 0% |
| IOB | 71 | 630 | 11% |

The block RAM is 16K × 32 of data memory (20 RAMB36) plus the glyph ROM. No DSPs by choice — see the third section of [core/README.md](../README.md#three-concessions-to-the-fabric).

### Timing

`nextpnr` analyses every domain against `--freq 100`, which is far above what any of them actually runs at.

| Clock | Runs at | Post-route Fmax | Margin |
|-------|---------|-----------------|--------|
| `cpu_clk` | 6.25 MHz | **104.18 MHz** | 16× |
| `pix_clk` | 25 MHz | **189.93 MHz** | 7.6× |

The old Vivado project closed against a relaxed 125 ns (8 MHz) constraint and never had a checked-in report. This supersedes it: the constraint is now the real 10 ns oscillator period, and the CPU's own critical path measures under 10 ns.

## Icarus CPI — `hardware/fpga/core` (`make cpi`)

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

At 6.25 MHz and ~2.13 CPI that is roughly **2.9 M instructions/s**, which paints the OS desktop — 4800 cells cleared plus chrome — in about 11 ms.

## ALU Sky130 (not the FPGA CPU)

See [verification/synthesis/README.md](../../../../verification/synthesis/README.md): **6531 µm²**, **512** cells, **~210 MHz** registered estimate (TT liberty, pre-route).
