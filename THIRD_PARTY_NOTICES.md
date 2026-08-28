# Third-party notices

Tomato (CERN-OHL-P-2.0) bundles or references materials under **other** licenses. Those
components are not “Tomato architecture” and remain under their own terms.

| Component | Location / use | License |
|-----------|------------------|---------|
| SkyWater 130nm PDK liberty | `verification/synthesis/pdk/` (fetched, gitignored) | [Apache-2.0](https://github.com/google/skywater-pdk) (PDK terms apply) |
| OSS CAD Suite (Yosys, ABC, openFPGALoader) | `hardware/fpga/.tools/` (fetched, gitignored) | GPL / ISC / MIT (per component) |
| nextpnr-xilinx + prjxray-db | Fetched via nix; device database for `xc7a100t` | ISC (nextpnr) / Apache-2.0 (prjxray-db) |
| Project X-Ray | `hardware/fpga/.tools/prjxray` (built locally, gitignored) | [Apache-2.0](https://github.com/f4pga/prjxray) |
| Digital (H. Neemann) | `.dig` schematics | Check Digital distribution license |
| KiCad | `.kicad_*` projects | GPL-3.0 (KiCad) |
| GitHub Actions / OSS tooling | CI if present | Per-action license |

Do not assume Tomato’s CERN-OHL-P licence applies to third-party tool outputs or
PDK files you download separately. Consult each upstream license before
redistributing.
