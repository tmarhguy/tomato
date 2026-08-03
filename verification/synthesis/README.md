# ALU synthesis - SkyWater 130nm HD

![status](https://img.shields.io/badge/status-characterized-2ea043?style=for-the-badge)
![architecture](https://img.shields.io/badge/architecture-32_bit-2563EB?style=for-the-badge)
![silicon](https://img.shields.io/badge/silicon-SkyWater_130nm-7C3AED?style=for-the-badge)
![EDA](https://img.shields.io/badge/EDA-Yosys-EAB308?style=for-the-badge)
![PDK](https://img.shields.io/badge/PDK-sky130_fd_sc_hd-0D9488?style=for-the-badge)

Open-source **ASIC characterization** of the Tomato 32-bit ALU: the Digital-export netlist [rtl/alu-32b-final.v](rtl/alu-32b-final.v) mapped to **sky130_fd_sc_hd** standard cells with Yosys + ABC, then measured for gate area, cell count, logic depth, and carry-chain timing. This is not tape-out sign-off. It answers: if this Verilog were silicon on a standard open PDK, how big and how fast is the datapath?

The discrete bench runs at breadboard speeds; this flow reports what the **same logic** looks like at 130nm. Source schematic: [alu-32b-final.dig](../../hardware/digital/modules/alu-32b-final.dig). Functional sign-off lives in [verification/README.md](../README.md).

---

## Table of Contents

- [Results at a glance](#results-at-a-glance)
- [Why this path is shallow](#why-this-path-is-shallow)
- [What each layer measures](#what-each-layer-measures)
- [Layout](#layout)
- [Netlist policy](#netlist-policy)
- [Run synthesis](#run-synthesis)
- [Done checklist](#done-checklist)
- [Related docs](#related-docs)
- [Author](#author)

---

## Results at a glance

**As of August 2026** | Corner **TT 25C 1.8V** | Tool **Yosys 0.67** + ABC

| Metric | Value | Notes |
|--------|-------|-------|
| Chip area | **6531 um^2** | Top module alu-32b-final |
| Sequential area | **9.81%** | Flag latches inside alu_8b_final |
| Mapped cells | **512** | sky130_hd after dfflibmap + ABC |
| Wires / wire bits | 3193 / 4890 | Post-map netlist |
| Ports / port bits | 1830 / 3045 | Includes slice hierarchy |
| LTP depth (top) | **4** | Inter-slice carry chain |
| Critical path (LTP) | lutA[7] through cout0-cout3 | Four 8b slices |
| Comb. delay (est.) | **4.12 ns** | Liberty typical arcs on carry path |
| Fmax comb. (est.) | **243 MHz** | Pre-route, no clock |
| Reg. cycle (est.) | **4.77 ns** | Comb + DFF overhead |
| Fmax registered (est.) | **210 MHz** | CLK to OUT budget |

### Dominant cell types

| Cell | Count | Area (um^2) |
|------|-------|-------------|
| sky130_fd_sc_hd__mux4_2 | 136 | 3060 |
| sky130_fd_sc_hd__mux2_1 | 100 | 1126 |
| sky130_fd_sc_hd__xnor2_1 | 64 | 561 |
| sky130_fd_sc_hd__dfxtp_1 | 32 | 641 |
| sky130_fd_sc_hd__maj3_1 | 32 | 320 |
| sky130_fd_sc_hd__clkinv_1 | 52 | 195 |

Area and cell counts come from Yosys `stat -liberty`. Timing is a **pre-route liberty arc estimate** along the Yosys longest topological path (not OpenSTA slack). Re-run updates [reports/metrics.txt](reports/metrics.txt).

---

## Why this path is shallow

Tomato's ALU is built around **ripple carry across four 8-bit slices**, not a deep Wallace tree or multi-cycle flag reduction. The Yosys LTP report puts the top-level critical structure at exactly **four macro-blocks deep**: one hop per byte-slice cout, from the high bit of the lutA program bus into the first slice and rippling through the rest.

**The carry chain wins.** Flag logic and zero detect add sequential area (~10%) but do not dominate topological depth at the 32-bit boundary the way a 32-bit NOR tree would in a conventional ALU. Programmable LUT planes feed a nibble adder; arithmetic depth is the story.

**Registered vs combinational.** The exported netlist includes CLK, FLAG_WE, and flag latches on the top 8b slice. Combinational OUT can settle in one carry sweep; a clocked system budgets ~0.66 ns for DFF clock-to-Q and setup (~243 MHz comb vs ~210 MHz registered in the estimate).

---

## Carry topology awareness (Kogge-Stone)

The programmable datapath is **`sum = lutB(A,B,C) + lutA(A,B,C) + cin`** — two 3-input LUT mux planes per bit, then carry. We know that replacing the ripple 4b/8b chain with a **Kogge-Stone 32b prefix add** on the same planes is faster on this PDK.

A synthesis benchmark in [test](../../test/README.md) implements that variant (`alu-32b-koggestone.v`): same dual-LUT planes, KS carry, flags stripped for apples-to-apples speed/area.

| Metric | Ripple ALU (this flow) | ALU + Kogge-Stone ([test](../../test/README.md)) |
|--------|------------------------|-------------------------------------|
| Area | 6531 um^2 | **4704 um^2** (~28% smaller) |
| Cells | 512 | **378** (~26% fewer) |
| Comb. delay (est.) | 4.12 ns | **3.25 ns** (~1.27x faster) |
| Fmax comb. (est.) | 243 MHz | **308 MHz** |
| Fmax registered (est.) | 210 MHz | **256 MHz** |

Production Tomato keeps ripple carry for simpler byte-slice physical design and integrated flag/zero logic on the top 8b slice. The benchmark proves the LUT architecture is not the bottleneck — carry topology is.

---

## What each layer measures

| Step | Yosys pass | Proves / reports |
|------|------------|------------------|
| Elaborate | read_verilog + hierarchy | Digital-export netlist elaborates clean |
| Map | synth, dfflibmap, abc | Generic logic to sky130_hd cells |
| Area | stat -liberty | um^2, cell mix, sequential fraction |
| Depth | ltp | Longest topological path (logic levels) |
| Export | flatten + write_verilog | Mapped netlist for optional STA |
| Timing est. | estimate_timing.py | Liberty NLDM typical arcs on LTP carry chain |

Pipeline script: [scripts/synth.ys](scripts/synth.ys). Liberty: `pdk/sky130_fd_sc_hd__tt_025C_1v80.lib` (fetch with scripts/fetch_lib if missing).

---

## Layout

Industry-standard open-source ASIC flow layout (RTL, scripts, PDK, reports):

```
verification/synthesis/
├── README.md
├── run.bat / run.sh         # Entry points (run from this directory)
├── rtl/
│   └── alu-32b-final.v      # Sole synthesis netlist (Digital export)
├── scripts/
│   ├── synth.ys
│   ├── extract_metrics.py
│   ├── estimate_timing.py
│   └── fetch_lib.ps1 / .sh
├── pdk/
│   └── sky130_fd_sc_hd__tt_025C_1v80.lib
├── constraints/
│   └── timing.tcl           # Optional OpenSTA
└── reports/                 # Generated (gitignored)
    ├── synth.log
    ├── metrics.txt
    ├── timing_est.txt
    └── synth_mapped.v
```

---

## Netlist policy

**One netlist, one top:** [rtl/alu-32b-final.v](rtl/alu-32b-final.v) is the only synthesis input. Export from [alu-32b-final.dig](../../hardware/digital/modules/alu-32b-final.dig) when the schematic changes. Copy to `verification/rtl/` for formal/UVM and to `synthesis/rtl/` for this flow.

There is **no** alu-32b-full.v in this tree. That name was a stale export from an older hierarchy (74157/74182 datapath, Opcode/control ports), not the current dual-LUT ladder. Synthesis and sign-off both use alu-32b-final.

| Copy | Path | Consumer |
|------|------|----------|
| Synthesis | synthesis/rtl/alu-32b-final.v | Yosys to sky130 |
| Sign-off | verification/rtl/alu-32b-final.v | Formal, directed, UVM |

---

## Run synthesis

**Prerequisites**

1. [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases) (Windows: `C:\tools\oss-cad-suite\`)
2. PDK liberty in `pdk/` (if missing, run fetch_lib):

```powershell
cd verification/synthesis
powershell -File scripts/fetch_lib.ps1
```

```bash
cd verification/synthesis
bash scripts/fetch_lib.sh
```

**Run**

```powershell
cd verification/synthesis
.\run.bat
```

```bash
cd verification/synthesis
./run.sh
```

Or from the verification harness:

```bash
make synth
```

**Output:** `reports/synth.log`, `reports/metrics.txt`, `reports/synth_mapped.v`.

```powershell
Select-String "Chip area for top module" reports\synth.log
Select-String "Longest topological path in alu-32b-final" reports\synth.log -Context 0,5
```

---

## Done checklist

You are done with ASIC characterization when:

| Check | Command / artifact |
|-------|---------------------|
| Liberty present | `pdk/sky130_fd_sc_hd__tt_025C_1v80.lib` exists |
| Synthesis passes | `run.bat` or `make synth` exits 0 |
| Area reported | `reports/metrics.txt` shows chip_area_um2: 6531.264 |
| LTP depth = 4 | metrics.txt shows carry chain across four slices |
| Mapped netlist | `reports/synth_mapped.v` generated |
| README matches run | Metrics table reflects latest metrics.txt |

Clean generated artifacts: `make synth_clean`.

---

## Related docs

| Doc | Content |
|-----|---------|
| [verification/README.md](../README.md) | ALU formal + UVM sign-off |
| [test/README.md](../../test/README.md) | Kogge-Stone + ALU+KS benchmark vs ripple ALU |
| [07 ALU board doc](../../hardware/kicad/boards/07_alu/README.md) | Physical dual-LUT PCB |
| [alu-32b-final.dig](../../hardware/digital/modules/alu-32b-final.dig) | Logic source of truth |
| [Root README](../../README.md) | Tomato architecture map |

---

## Author

**Tyrone Marhguy** - Computer Engineering '28, [University of Pennsylvania](https://www.upenn.edu/)

Tomato is a solo hardware architecture project: discrete-logic CPU design, KiCad PCBs, Digital simulation, and a public build log.

| Platform | Link |
|----------|------|
| Email | [tmarhguy@gmail.com](mailto:tmarhguy@gmail.com) · [tmarhguy@engineering.upenn.edu](mailto:tmarhguy@engineering.upenn.edu) |
| Twitter | [@marhguy_tyrone](https://twitter.com/marhguy_tyrone) |
| Instagram | [@tmarhguy](https://instagram.com/tmarhguy) |
| Substack | [@tmarhguy](https://substack.com/@tmarhguy) |
| GitHub | [@tmarhguy](https://github.com/tmarhguy) |

![UPenn](https://img.shields.io/badge/UPenn-CE_2028-011F5B?style=for-the-badge)
![Computer Engineering](https://img.shields.io/badge/Computer_Engineering-hardware-990000?style=for-the-badge)
![homebrew hardware](https://img.shields.io/badge/homebrew-hardware-2ea043?style=for-the-badge)
![ASIC synthesis](https://img.shields.io/badge/ASIC-synthesis-EAB308?style=for-the-badge)
![SkyWater 130nm](https://img.shields.io/badge/SkyWater-130nm-7C3AED?style=for-the-badge)
