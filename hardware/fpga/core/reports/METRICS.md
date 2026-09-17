# Tomato FPGA metrics (evidence log)

Runtime clocks and CPI below are reproducible from in-tree source and tests.
The post-route resource/Fmax figures are a recorded prior run; its raw
nextpnr log is not checked in, so treat them as an evidence note, not as a
result reproducible from this file alone.

## Full CPU — `hardware/fpga/core`

Post-route on `xc7a100tcsg324-1`, top `nexys_top`, from `nextpnr-xilinx`. Reproduce with `../scripts/env.sh make fpga` from `hardware/fpga/core`; the log is not checked in, `build/` is gitignored.

| Metric | Value |
|--------|-------|
| Flow | yosys → nextpnr-xilinx → prjxray → openFPGALoader (no Vivado) |
| Synthesis options | `synth_xilinx -flatten -abc9 -nodsp` |
| Board oscillator | 100 MHz (Digilent pin E3) |
| CPU clock | **6.25 MHz** (100 ÷ 16, `CPU_DIV_LOG2 = 4`) |
| Pixel clock | **25 MHz** (100 ÷ 4), 640×480 nominal-60-Hz timing: 800×525 totals produce **~59.52 Hz** |
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

The current Makefile passes `--freq 90`. That is the configured
place-and-route timing target for named clocks, not a runtime frequency or a
measured Fmax. The table below records a prior nextpnr run; no raw log is
checked in.

| Clock | Runs at | Post-route Fmax | Margin |
|-------|---------|-----------------|--------|
| `cpu_clk` | 6.25 MHz | **104.18 MHz** | 16× |
| `pix_clk` | 25 MHz | **189.93 MHz** | 7.6× |

The old Vivado project closed against a relaxed 125 ns (8 MHz) constraint and
never had a checked-in report. The current XDC instead constrains the real
100 MHz input oscillator with a 10 ns period. The recorded CPU-domain Fmax
above is not the 6.25 MHz runtime clock and is not the 90 MHz build target.

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

The unweighted mean of these six samples is ~2.13 CPI. Applying that simulated
instruction mix to the configured 6.25 MHz clock projects roughly **2.9
million instructions/s**. This is a workload-derived calculation, not measured
board throughput, emulator speed, or a universal operations/s rating. The
roughly 11 ms desktop-paint figure is likewise a cycle-model projection, not a
wall-clock FPGA measurement.

## ALU Sky130 (not the FPGA CPU)

See [verification/synthesis/README.md](../../../../verification/synthesis/README.md): **6531 µm²**, **512** cells, **~210 MHz** registered estimate (TT liberty, pre-route).
