# Tomato web

The static project site and functional Virtual Tomato emulator, deployed at
[tomato.tmarhguy.com](https://tomato.tmarhguy.com/).

The site has no application framework, bundler, database, or server runtime.
Vercel serves this directory directly after running asset hashing and the test
suite.

## Run locally

Use the repository server so ES modules, media ranges, compression, and cache
headers behave like deployment:

```bash
cd web
npm run serve
# http://localhost:8080/
```

Do not open pages through `file://`.

## Validate

```bash
cd web
npm test
```

The Node test suite checks local links and assets, JavaScript syntax, static
delivery budgets, the generated OS image, ISA-facing copy, and browser-emulator
behavior. From the repository root, use `make web-test`.

## Structure

| Path | Role |
|---|---|
| `index.html` | Project front page |
| `virtual.html` | Browser emulator interface |
| `architecture.html`, `isa.html`, `software.html`, `os.html` | Current technical explanations |
| `status.html` | Public scope and evidence boundaries |
| `gallery.html`, `journal.html`, `boards.html` | Build evidence and history |
| `js/tomato-cpu.js` | DOM-free functional ISA emulator |
| `js/virtual.js`, `js/tomato-screen.js` | Emulator run loop, controls, and tile rendering |
| `js/bench.js`, `js/viewer.js`, `js/pcb-look.js` | Interactive KiCad model presentation |
| `css/` | Shared identity plus page-specific layouts |
| `assets/` | Images, video, 3D models, fonts, and generated diagrams |
| `data/tomato-os.bin` | Generated browser firmware package |
| `scripts/` | Asset, metadata, firmware, and documentation generators |
| `tests/` | Static-site and emulator regressions |

## Generated artifacts

The checked-in browser image is derived from OS assembly, burned control
planes, and FPGA display assets:

```bash
python3 tools/build_web_image.py
python3 tools/build_web_image.py --check
```

The root README diagrams are generated from `docs/diagrams/*.mmd`. After
installing development dependencies, rebuild both light and dark SVGs with:

```bash
cd web
npm install
npm run build:diagrams
```

Asset URLs are content-versioned. Refresh hashes before deployment:

```bash
cd web
npm run hash:assets
```

Generated files are derivatives, not design authorities. Do not hand-edit the
browser image or rendered SVG diagrams.

## Deployment

[`../vercel.json`](../vercel.json) deploys `web/` as a raw static directory.
The build runs `npm run hash:assets` followed by `npm test`; no framework build
or dependency installation is required to serve the checked-in site.

[`../.github/workflows/web.yml`](../.github/workflows/web.yml) runs the same
sanity suite for web changes. A passing local test or source change does not
prove that the public deployment has updated.

## Authority and boundaries

- Current project facts: [`../docs/status.md`](../docs/status.md)
- Architecture: [`../docs/architecture.md`](../docs/architecture.md)
- Browser/FPGA execution labels: [`../docs/compute.md`](../docs/compute.md)
- Asset captions and provenance: [`../docs/assets.md`](../docs/assets.md)
- Documentation precedence: [`../docs/documentation-policy.md`](../docs/documentation-policy.md)

Virtual Tomato executes the generated OS image in a functional ISA emulator.
It is not cycle-accurate RTL, an FPGA session, or the discrete ALU hardware.
