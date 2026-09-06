<h1 align="center">TOMATO</h1>
<p align="center"><strong>32-bit Computer.</strong> The oddest machine still built from chips.</p>

![Form](https://img.shields.io/badge/Form-Static%20broadsheet-011F5B) ![Deploy](https://img.shields.io/badge/Deploy-tomato.tmarhguy.com-2563EB)

<p align="center">
  <img src="assets/plates/front-page.webp" alt="The Tomato, Vol. 32 No. 1 — front page, August 2026" />
</p>
<p align="center"><em>Vol. 32 · No. 1 · Magnesium Alley, Ashtown-Bay Perimeter · August 2026</em></p>

This is not a SaaS product page. It is not a bloated React template. It is a **90s broadsheet**—typeset in Playfair and Source Serif—that acts as a temporal bridge to the hardware. It features a fully interactive 3D KiCad GLB of [`07_alu`](https://tomato.tmarhguy.com/board.html), a bit-level **[Dual-LUT playground](https://tomato.tmarhguy.com/playground.html)**, **[ALU verification sign-off](https://tomato.tmarhguy.com/verification.html)** (SymbiYosys, 476 directed, 10B/130B Verilator), and the project's **[engineering journal](https://tomato.tmarhguy.com/journal.html)**.

**Live:** [tomato.tmarhguy.com](https://tomato.tmarhguy.com/)  
**Core CPU architecture:** [Root README](../README.md)  
**Design journal:** [docs/log/](../docs/log/)

### Run locally

Do not open HTML via `file://` — the GLB and ES modules need a server.

```bash
cd web && python3 -m http.server 8080
```

Then open **[http://localhost:8080/](http://localhost:8080/)**. Same thing: `cd web && npm run serve`.

---

## Current website direction

The homepage leads with the interactive ALU board and the sentence “A computer whose logic changes with each instruction.” The text keeps its natural height; the board fills the remaining opening viewport. The site explains the configurable datapath, running FPGA software, discrete build, hardware compiler, and verification with diagrams and working examples.

Read [BRANDING.md](BRANDING.md) before changing the design or project claims. It records the approved voice, evidence boundaries, and recovery workflow. The old newspaper presentation is historical context, not the current design authority.

<p align="center">
  <img src="assets/pcb/alu_8b_board.jpg" alt="Tomato 07_alu — KiCad board render" width="47%" />
  <img src="assets/pcb/alu_8b_pcb.jpg" alt="Tomato 07_alu — routed top copper" width="50%" />
</p>
<p align="center"><em>Left: Board render · Right: Routed top copper — The same plates featured in Fig. 1.</em></p>

---

## Design Constraints & Impact

Every choice on this site mirrors the architectural constraints of the CPU itself: cut the bloat, ensure it routes cleanly, and make it functional on the bench.

- **Static HTML over SPA:** The shipped `07_alu` GLB is **1.26 MB** Draco (**9** meshes). The raw KiCad export behind it is still ~**31 MB** / ~**41k** primitives — that file does not go in the tab. `web/` deploys as a raw folder. Vercel install command: `echo "no-install"`.
- **Relative Links Only:** Nested pages (`journal/…`, `boards/…`), local `python3 -m http.server`, and Vercel all break if assets are rooted at `/css/…`. Everything is strictly relative so the paper works on [tomato.tmarhguy.com](https://tomato.tmarhguy.com/), a local preview, or a subdirectory checkout.
- **Shared identity:** `css/landing.css` owns the homepage, `css/brand.css` carries its identity across the reference pages, and `css/viewer.css` keeps the 3D workspace full-screen. Reference pages use rebuilt reading layouts, a static header/footer, a responsive all-pages menu, and specialized tool styles.
- **KiCad’s Native Copper:** No artificial gold restyling. The export matches the physical board: **FR4 core black**, silk white, copper untouched. Fig. 1 and the interactive GLB use the exact same material palette.
- **Demand-Rendered 3D:** The optimized GLB is nine draws. A raw KiCad dump is still **~41k**. The loader skips client merge when mesh count is under 32, and the canvas only renders when the camera moves or the board is on-screen.
- **The Forge in the Paper:** [`source.html`](https://tomato.tmarhguy.com/source.html) pulls the live GitHub repo directly into the broadsheet layout so the design and its source can be explored together.

<p align="center">
  <img src="assets/engravings/eniac-penn.jpg" alt="ENIAC at the Moore School, 1946" width="47%" />
  <img src="assets/pcb/alu_8b_board.jpg" alt="07_alu board render" width="47%" />
</p>
<p align="center"><em>Then: ENIAC at the Moore School (U.S. Army). Now: The 07_alu slice.</em></p>

---

## Core Features

### 1. 3D Immersion: The Bench & The Viewer

We run two cameras on one model (`assets/pcb/alu.glb`), exported directly from **KiCad 10**.

- **[The Bench](https://tomato.tmarhguy.com/)** (`js/bench.js`): Embedded on the front page. Drag, iso/side toggle, spin. Dimmed slightly so the cream paper still reads.
- **[The Viewer](https://tomato.tmarhguy.com/viewer.html)** (`js/viewer.js`): A dedicated, full-screen studio tour. Press **I** for a cinematic, monotonic orbit that lands on the upright isometric view. Any manual input aborts the tour.

### 2. The Playground

The [`playground.html`](https://tomato.tmarhguy.com/playground.html) interface is `07_alu` on a wire. It’s a **bit-level Dual-LUT emulator** running in the browser. Toggle operands, flip both LUT opcodes, and assert carry. If the Dual-LUT architecture doesn't survive a bit-flip in the browser, it won't survive a logic probe on the physical bench.

<p align="center">
  <img src="assets/pcb/immersion_black.webp" alt="Tomato 07_alu — Dual-LUT slice in the round" />
</p>
<p align="center"><em>Lot 07 in the round · the slice the playground runs · <a href="https://tomato.tmarhguy.com/playground.html">open the playground</a></em></p>

### 3. The Journal & Boards

The journal takes [`docs/log/`](../docs/log/) and typesets it. It runs to **34 dispatches**, tracking the build from the first gate to the chips on the copper. The **[boards catalog](https://tomato.tmarhguy.com/boards.html)** tracks all **8 lots**. Lot **07** is **soldered** and on the bench. The remaining lots (Shift, Memory, Register File, PC) are currently being plumbed.

### 4. The Gallery

[`gallery.html`](https://tomato.tmarhguy.com/gallery.html) is the plate room — the renders, the copper, and the bench photographs, laid out as a bound pictorial rather than a grid of thumbnails.

---

## What the paper is now describing

[`architecture.html`](https://tomato.tmarhguy.com/architecture.html), [`isa.html`](https://tomato.tmarhguy.com/isa.html), and [`software.html`](https://tomato.tmarhguy.com/software.html) cover the datapath, the ROM plus assembler vocabulary, and Tomato OS on HDMI. Source: [hardware/fpga/core](../hardware/fpga/core/README.md) · [software/os/tomato_os.s](../software/os/tomato_os.s).

---

## Repository Map

```text
web/
├── index.html              # The Front Page
├── architecture.html       # Datapath & Overlay Word
├── isa.html                # 512-row ROM & Mnemonic logic
├── software.html           # Assembler, Tomato OS, stack
├── playground.html         # Dual-LUT Emulator
├── journal.html            # Log Index
├── journal/*.html          # Typeset design logs (30)
├── boards.html             # Lots 01–08 tracking
├── boards/*.html           # Individual board specs (8)
├── board.html              # Embedded 3D bench
├── viewer.html             # Full-screen immersion viewer
├── gallery.html            # The plate room, as a bound pictorial
├── source.html             # GitHub rendered in-paper
├── about.html              # The Correspondent
├── 404.html                # Missing page, still in the broadsheet
├── css/magazine.css        # The core broadsheet stylesheet
├── css/viewer.css          # Black studio lighting
├── js/                     # Engine: bench, viewer, alu emulator, forge
├── assets/pcb/alu.glb      # Draco 07_alu (1.26 MB, 9 meshes)
├── tests/                  # Custom sanity + emulator test suite
└── ATTRIBUTION.md
```

---

## Local Development & Testing

**Preview** (same as [Run locally](#run-locally) above):

```bash
cd web && python3 -m http.server 8080
# → http://localhost:8080/
```

**Sanity Tests:**
There is no bundler. A silent 404 is the primary failure mode. `tests/site-sanity.mjs` is a custom, zero-dependency Node script that walks every HTML file to catch dead links, missing assets, root-absolute paths, and JS syntax errors.

```bash
cd web && npm test
# Or from the repo root: make web-test
```

---

## Deployment

- **Live origin:** [tomato.tmarhguy.com](https://tomato.tmarhguy.com/)
- **Vercel:** The root `vercel.json` serves `web/` and runs `npm test` as the build. No framework, no install.
- **CI:** `.github/workflows/web.yml` runs the same sanity suite on PRs and pushes to `main`. There is no GitHub Pages workflow.

### Custom domain DNS (Namecheap)

Same pattern as `alu.tmarhguy.com`. In Namecheap → Domain List → `tmarhguy.com` → Advanced DNS:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME | `tomato` | `cname.vercel-dns.com.` | Automatic |

Add `tomato.tmarhguy.com` as a domain on the Vercel project. Clear any custom domain under the repo **Settings → Pages** so GitHub stops 301ing `github.io/tomato` at a dead hostname.

---

## Author

**Tyrone Marhguy** — Computer Engineering ’28, [University of Pennsylvania](https://www.upenn.edu/)

A look at the bottom left of the physical `07_alu` board reveals three silkscreened marks: **Penn Engineering, Achimota School, and the Ghana flag**. That silk is why the paper is printed in Ashtown Valley, even when the copper lands in Philadelphia.

| Links | |
| --- | --- |
| **Paper** | [tomato.tmarhguy.com](https://tomato.tmarhguy.com/) |
| **Repo** | [github.com/tmarhguy/tomato](https://github.com/tmarhguy/tomato) |
| **Email** | [tmarhguy@gmail.com](mailto:tmarhguy@gmail.com) |
| **Twitter** | [@marhguy_tyrone](https://twitter.com/marhguy_tyrone) |
