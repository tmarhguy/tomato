# Sky130 benchmark — Kogge-Stone vs Tomato ALU variants

![status](https://img.shields.io/badge/benchmark-Kogge_Stone-2ea043?style=for-the-badge)
![PDK](https://img.shields.io/badge/PDK-sky130_fd_sc_hd-0D9488?style=for-the-badge)

Side-by-side synthesis on **SkyWater 130nm HD** (same Yosys + ABC flow as [verification/synthesis](../verification/synthesis/README.md)):

| Design | What it is |
|--------|------------|
| **Ripple ALU** | Production netlist — dual-LUT + ripple 4b/8b carry + flags ([rtl](../verification/synthesis/rtl/alu-32b-final.v)) |
| **KS adder only** | Fastest classical carry topology — parallel prefix adder ([rtl/kogge_stone_32.v](rtl/kogge_stone_32.v)) |
| **ALU + KS** | Same dual-LUT datapath, Kogge-Stone 32b sum instead of ripple ([rtl/alu-32b-koggestone.v](rtl/alu-32b-koggestone.v)) |

We are **aware** that the programmable path is `adder(mux3_LUT, mux3_LUT, carry_in)` — the same mux3 planes per bit on both sides. Swapping ripple carry for Kogge-Stone is the standard way to close the speed gap while keeping LUT flexibility. Production Tomato keeps ripple for simpler physical design and integrated flag/zero logic.

---

## Results (2026-08-02)

| Metric | Ripple ALU | KS adder only | ALU + KS | Notes |
|--------|------------|---------------|----------|-------|
| Chip area | **6531 um^2** | **1101 um^2** | **4704 um^2** | ALU+KS **28% smaller** than ripple ALU |
| Cells | **512** | **186** | **378** | ALU+KS **26% fewer** cells than ripple |
| Sequential area | 9.81% | 0% | 0% | Flags stripped in ALU+KS benchmark |
| LTP depth (top) | **4** | ~5 prefix | **2** | Hierarchical LTP understates flattened KS |
| Comb. delay (est.) | **4.12 ns** | **2.23 ns** | **3.25 ns** | ALU+KS **1.27x** faster than ripple |
| Fmax comb. (est.) | **243 MHz** | **449 MHz** | **308 MHz** | ALU+KS **1.27x** faster than ripple |
| Reg. cycle (est.) | **4.77 ns** | **2.88 ns** | **3.90 ns** | ALU+KS **1.22x** faster than ripple |
| Fmax registered (est.) | **210 MHz** | **347 MHz** | **256 MHz** | ALU+KS **1.22x** faster than ripple |

Full machine-readable output: [reports/comparison.txt](reports/comparison.txt), [reports/metrics.txt](reports/metrics.txt), [reports/alu_ks_metrics.txt](reports/alu_ks_metrics.txt).

---

## What this means

**Same datapath, faster carry.** ALU+KS keeps the dual 3-input LUT planes (`lutA`, `lutB` mux3 per bit) and replaces the four-slice ripple chain with one Kogge-Stone 32b add. That recovers most of the speed lost to ripple (~308 MHz comb vs ~243 MHz) while staying programmable.

**KS adder-only is still the speed ceiling.** A hardened prefix adder with no LUT muxes is ~1.45x faster comb than ALU+KS and ~4.3x smaller — expected, since it only adds.

**Ripple ALU trades speed for integration.** Flags, carry select, and byte-slice hierarchy add ~10% sequential area and keep carry depth at four slice boundaries — a deliberate PCB/PD choice, not an unawareness of prefix adders.

Timing uses the same **pre-route liberty arc estimate** methodology as the synthesis README (LUT mux depth + KS prefix levels for ALU+KS; not OpenSTA sign-off).

---

## Run

Requires OSS CAD Suite and liberty in `../verification/synthesis/pdk/` (run `verification/synthesis/scripts/fetch_lib.ps1` if missing).

```powershell
cd test
.\run.bat
```

```bash
cd test
./run.sh
```

Outputs: `reports/synth.log`, `reports/metrics.txt`, `reports/alu_ks_synth.log`, `reports/alu_ks_metrics.txt`, `reports/comparison.txt`.

---

## Layout

```
test/
├── README.md
├── run.bat / run.sh
├── rtl/
│   ├── kogge_stone_32.v
│   ├── alu_slice_support.v      # Mux_8x1 + alu_1b_final
│   ├── alu_lut_planes_32.v
│   └── alu-32b-koggestone.v     # dual-LUT + KS top
├── scripts/
│   ├── synth.ys / synth_alu_ks.ys
│   ├── extract_metrics.py / extract_metrics_alu_ks.py
│   ├── estimate_timing.py / estimate_timing_alu_ks.py
│   └── compare.py
└── reports/                     # generated (gitignored)
```
