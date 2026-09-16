# Tomato documentation assets

Tomato images are evidence, not decoration. Use an image only when it clarifies
what was built, where code ran, or how a subsystem fits together.

The current reusable documentation collection lives under
[`web/assets/`](../web/assets/). This guide describes how repository
documentation should select and label those files; it does not make the asset
directory an architectural authority.

## Recommended evidence set

| Subject | Reusable asset | What it supports |
|---|---|---|
| Assembled ALU slice | `web/assets/assembly/half-soldered-plate.webp` | Physical assembly of the Dual-LUT ALU slice |
| FPGA setup | `web/assets/assembly/fpga-board-pmod.webp` | Nexys A7 hardware used by FPGA Tomato |
| Tomato OS | `web/assets/os/desktop-home.webp` | OS desktop shown on the FPGA display path |
| ALU board render | `web/assets/pcb/alu_8b_board.webp` | Lot 07 PCB design |
| ALU routed board | `web/assets/pcb/alu_8b_pcb.jpg` | Board layout, not assembled hardware |
| Digital schematic | `web/assets/story/digital/main-tomato-v1-burn.webp` | Editable architecture schematic view |
| Envelop in current OS image | `web/assets/documentation/desktop/tomato-virtual-os-envelop-desktop.webp` | Browser-emulated OS UI with simulated peripherals; not FPGA or online bridge evidence |
| Compiler in current OS image | `web/assets/documentation/desktop/tomato-virtual-os-compiler-desktop.webp` | Browser-emulated current compiler screen |
| Real-phone responsive pages | `web/assets/documentation/infinix/*.webp` | Current local site rendered on the documented Infinix; UI-only evidence |

Prefer these established images over adding near-duplicates. Dimensions,
capture method, privacy review, and per-file captions for the 2026-09-16
website set are recorded in the
[`web/assets/documentation` catalog](../web/assets/documentation/README.md).
Those captures prove the interface state shown, not deployment or physical
availability.

## Caption and alt-text rules

Every image should answer three questions where relevant:

1. **What is shown?** Name the board, screen, schematic, or result.
2. **Where did it run?** Distinguish discrete hardware, FPGA Tomato, Virtual
   Tomato, and RTL simulation.
3. **What does it prove?** Do not infer a complete system from a component.

Good alt text is concrete: “Physically assembled Tomato Dual-LUT ALU slice.”
Avoid claims such as “the discrete Tomato computer” because only the ALU slice
has been physically assembled. For emulator and simulation output, include that
provenance in the alt text or adjacent caption.

## Status boundaries

- A PCB render proves a design exists, not that it was fabricated or assembled.
- An assembly photograph can prove the pictured component exists, not that a
  complete computer ran.
- An FPGA photograph identifies hardware, but a result requires an associated
  run record or visibly grounded capture.
- A screenshot proves the captured interface state, not current deployment.
- Virtual and simulation results must remain labeled when copied or cropped.
- Generated images and memory artifacts must name their source or generator.

## Privacy and sanitization

Before publishing a capture, remove or avoid:

- personal notifications and account identifiers;
- credentials, tokens, private endpoints, and administrative controls;
- device identifiers and nearby-device details;
- keyboard suggestions or unrelated app content;
- real names and messages when synthetic fixtures can demonstrate the state.

Strip unnecessary metadata from published derivatives. Keep any original
capture notes outside public narrative surfaces when they contain operational
detail.

## File practices

- Prefer WebP for photographic and UI documentation images; preserve a source
  format only when it materially improves reuse.
- Use stable, descriptive lowercase names.
- Keep dimensions large enough for readable text but avoid shipping an
  oversized source when a smaller derivative is sufficient.
- Do not edit generated diagrams or screenshots to imply a different execution
  target.
- Record third-party or generated-image attribution in the repository's
  designated attribution/legal files rather than duplicating uncertain claims.

Current terminology and execution-label rules come from
[`status.md`](status.md) and [`compute.md`](compute.md).
