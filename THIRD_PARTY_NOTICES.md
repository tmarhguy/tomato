# Third-party notices

Tomato is offered under `Apache-2.0 WITH SHL-2.1`; see [LICENSE](LICENSE),
[LICENSE-APACHE](LICENSE-APACHE), and [NOTICE](NOTICE). The items below are
separate dependencies, tools, data, or reference media. Their own terms remain
authoritative.

## Material stored or generated in this repository

| Material | Location / provenance | Terms and decision |
|---|---|---|
| ENIAC photograph | `web/assets/engravings/eniac-penn.jpg`; U.S. Army photograph via [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Classic_shot_of_the_ENIAC.jpg) | Public-domain U.S. government photograph; source attribution is preserved in `web/ATTRIBUTION.md`. |
| Printable ASCII font ROM | Generator `tools/gen_font_rom.py` and generated `font_rom.v` | Project-authored data under Tomato's project licence unless a more specific notice appears in the generated file. |

Nordic-generated nRF8001 ACI setup bytes are intentionally not stored or
redistributed. The repository ships only independently written transport RTL
and project-authored simulator placeholders. Those placeholders do not
configure a physical radio.

## Tools and fetched dependencies

| Component | Location / use | Upstream licence |
|---|---|---|
| Digital by Helmut Neemann | Authoring/viewing `.dig` schematics | [GPL-3.0](https://github.com/hneemann/Digital/blob/master/LICENSE) for the application. Running a GPL tool does not by itself relicense Tomato-authored `.dig` design files. |
| KiCad | Authoring `.kicad_*` projects and renders | GPL-3.0 for the application. Tomato-authored board sources and renders remain under their stated project terms. |
| SkyWater 130 nm PDK liberty | `verification/synthesis/pdk/` (fetched and gitignored) | [Apache-2.0](https://github.com/google/skywater-pdk); the fetched PDK's own notices and terms apply. |
| OSS CAD Suite | `hardware/fpga/.tools/` (fetched and gitignored) | Mixed licences, including GPL, ISC, and MIT; inspect the bundled notice for each component. |
| nextpnr-xilinx and Project X-Ray database | Fetched through the FPGA flow | ISC for nextpnr; Apache-2.0 for Project X-Ray/prjxray-db. |
| Project X-Ray tools | `hardware/fpga/.tools/prjxray` (built locally and gitignored) | [Apache-2.0](https://github.com/f4pga/prjxray). |
| GitHub Actions | `.github/workflows/` | Each action retains its upstream licence; workflow references are commit-pinned for reproducibility. |

Generated schematics, renders, bitstreams, databases, and reports can contain
or depend on third-party material. Do not infer redistribution permission from
the licence of the tool that produced them. Review the relevant upstream terms
before redistributing fetched dependencies or their embedded data.
