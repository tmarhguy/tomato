# Documentation screenshot catalog

These WebP files document the current local Tomato website working tree. The
strongest current-OS and provenance frames are used by the root README and the
homepage, Envelop, OS, compute, Virtual Tomato, gallery, and status pages.
Page captions remain explicit about browser emulation versus FPGA hardware.

Mobile files under `infinix/` were rendered by Chrome 150 on the connected
Infinix X6831 at 1080 × 2460, using only explicit ADB serial
`099244034R004149`. The status strip and Android navigation strip were removed
to exclude notification, carrier, and network context; the Chrome address bar
remains as real-device browser evidence. Desktop files under `desktop/` were
captured in an isolated 1440 × 1000 headless Chrome profile.

Every file was decoded and re-encoded as RGB WebP at quality 82, method 6. The
result contains no EXIF, XMP, ICC, comment, or application metadata.

## Infinix captures

- `infinix/tomato-home-infinix.webp` — Alt: “Tomato homepage in Chrome on an
  Infinix phone, showing the circuit board, project statement, and Play Tomato
  and Envelop actions.” Caption: “Current responsive Tomato homepage · real
  Infinix browser.” Provenance: UI-only; the board is the site's existing KiCad
  render.
- `infinix/tomato-navigation-infinix.webp` — Alt: “Tomato mobile navigation open
  in Chrome on an Infinix phone.” Caption: “Current mobile site navigation.”
  Provenance: UI-only.
- `infinix/tomato-envelop-entry-infinix.webp` — Alt: “Tomato’s mobile Envelop
  explainer showing the path from a person to a labeled reply.” Caption:
  “Tomato-to-Envelop entry point on the current local site.” Provenance:
  UI-only; no message was sent.
- `infinix/tomato-virtual-page-infinix.webp` — Alt: “Virtual Tomato page in
  Chrome on an Infinix phone, with the browser emulator and five-button
  controls.” Caption: “Virtual Tomato · browser CPU emulator · simulated
  peripherals.” Provenance: browser emulation, not FPGA hardware.
- `infinix/tomato-virtual-os-envelop-infinix.webp` — Alt: “Envelop open inside
  Tomato OS in the Virtual Tomato browser emulator on an Infinix phone.”
  Caption: “Envelop inside virtual Tomato OS · bridge offline · simulated
  peripherals.” Provenance: current OS image in the browser CPU emulator.
- `infinix/tomato-os-page-infinix.webp` — Alt: “Tomato OS documentation page in
  Chrome on an Infinix phone.” Caption: “Current Tomato OS documentation at a
  real phone viewport.” Provenance: UI-only page capture; any embedded hardware
  media retains its own caption.
- `infinix/tomato-compute-page-infinix.webp` — Alt: “Envelop and Tomato compute
  preview documentation in Chrome on an Infinix phone.” Caption: “Compute
  request, target choice, and provenance boundaries on mobile.” Provenance:
  UI-only documentation example.

## Desktop captures

- `desktop/tomato-home-desktop.webp` — Alt: “Desktop Tomato homepage with the
  interactive board hero and primary project journeys.” Caption: “Current
  Tomato homepage at 1440 × 1000.” Provenance: UI-only.
- `desktop/tomato-architecture-desktop.webp` — Alt: “Tomato architecture
  documentation at a desktop viewport.” Caption: “Architecture overview in the
  current local website.” Provenance: UI-only.
- `desktop/tomato-board-viewer-desktop.webp` — Alt: “Desktop Tomato board viewer
  showing the current circuit board model.” Caption: “Interactive board model
  at a desktop viewport.” Provenance: site model/render, not a physical photo.
- `desktop/tomato-verification-desktop.webp` — Alt: “Tomato verification page
  distinguishing simulation, formal checks, FPGA evidence, and physical
  hardware.” Caption: “Verification scope and evidence boundaries.” Provenance:
  UI-only documentation capture.
- `desktop/tomato-compute-provenance-desktop.webp` — Alt: “Desktop compute
  preview showing Ask, Choose the target, and See the result, with Virtual
  Tomato provenance.” Caption: “Hardware and virtual execution are separate,
  visibly labeled paths.” Provenance: UI-only documentation example.
- `desktop/tomato-virtual-os-envelop-desktop.webp` — Alt: “Envelop open inside
  Tomato OS in the desktop Virtual Tomato emulator, with simulated phone
  controls.” Caption: “Current OS image · browser CPU emulator · bridge
  offline.” Provenance: browser emulation with synthetic control labels.
- `desktop/tomato-virtual-os-compiler-desktop.webp` — Alt: “Compiler screen
  running inside Tomato OS in the desktop Virtual Tomato emulator.” Caption:
  “Compiler screen · current OS image · browser CPU emulator.” Provenance:
  browser emulation. The emulator was paused and a flat background patch
  removed the personal attribution string from the OS title bar; no result
  pixels or compiler state were altered.

## Existing assets selected for reuse

No duplicate captures were made for claims already supported by these existing
assets:

- `../gallery/assembly/board-test-1280w.webp` — physical assembled ALU board;
- `../gallery/assembly/placing-and-soldering-1280w.webp` — physical assembly;
- `../gallery/plates/kicad-sch-1280w.webp` — ALU schematic;
- `../plates/digital-main.jpg` — complete simulated machine;
- `../gallery/os/desktop-home-1280w.webp` — Tomato OS on the FPGA display path;
- `../gallery/os/main-menu-screen-1280w.webp` — Tomato OS menu evidence;
- `../compiler/opcode-sweep-fpga.webp` and its MP4 — compiler search on FPGA;
- `../os/tomato-demo-os-poster.jpg` and its MP4 — recorded FPGA OS output.

Existing asset captions remain authoritative for dated hardware evidence. None
of these files proves current bridge availability or a currently deployed
hardware service.

## Privacy review

Every new frame was visually inspected. The set contains no personal
notifications, real participant records, tokens, UUIDs, backend or BLE
identifiers, Wi-Fi or carrier names, admin controls, browser history, unrelated
tabs, or durable public data. Visible `Demo contact` labels are capture-only
synthetic replacements. No live backend or Supabase mutation was used.
