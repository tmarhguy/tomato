# Third-party notices

Tomato (SHL-2.1) bundles or references materials under **other** licenses. Those
components are not “Tomato architecture” and remain under their own terms.

| Component | Location / use | License |
|-----------|------------------|---------|
| Apache License 2.0 | Incorporated under SHL-2.1 | See [LICENSE-APACHE](LICENSE-APACHE) |
| SkyWater 130nm PDK liberty | `verification/synthesis/pdk/` (fetched, gitignored) | [Apache-2.0](https://github.com/google/skywater-pdk) (PDK terms apply) |
| Xilinx / AMD Vivado | `hardware/fpga/**` generated logs, reports, IP | Xilinx / AMD proprietary (tool output) |
| OSS CAD Suite (Yosys, ABC) | External tool for synthesis scripts | GPL / ISC (per component) |
| Digital (H. Neemann) | `.dig` schematics | Check Digital distribution license |
| KiCad | `.kicad_*` projects | GPL-3.0 (KiCad) |
| GitHub Actions / OSS tooling | CI if present | Per-action license |

Do not assume Tomato’s SHL-2.1 license applies to third-party tool outputs or
PDK files you download separately. Consult each upstream license before
redistributing.
