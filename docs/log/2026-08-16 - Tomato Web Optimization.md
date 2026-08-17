I decided to keep the web stack strictly Vanilla: static HTML, CSS, JavaScript, and raw Three.js (0.169.0 via import map) without React or a bundler. This avoids framework bloat and keeps the footprint light. I used `OrbitControls` and demand-render (only drawing when dirty or on screen) with a pixel ratio capped at 1.5. However, rendering a complex KiCad PCB in a browser is inherently heavy, so I needed a major optimization pass.

### Before & After Metrics

|                | Before (raw KiCad in the tab)    | After (what ships)                           |
| -------------- | -------------------------------- | -------------------------------------------- |
| **GLB**        | ~31.0 MB                         | 1.26 MB (Draco)                              |
| **Draw**       | ~41k meshes (pad/trace)          | 9 meshes / 13 primitives                     |
| **Copper**     | Palette welded it under mask     | Separate copper/mask/silk/FR4/pad            |
| **Merge**      | Ran on every mesh on main thread | Still in `pcb-look.js`; skips if < 32 meshes |

### The GLB Export Pivot

Originally, the 3D model of the ALU was a monolithic ~31MB `.glb` file straight out of KiCad 10.0.4, carrying roughly 41k pad/trace meshes. To shrink this, I pushed it through glTF-Transform v4.4.2.

The shipped file (`web/assets/pcb/alu.glb`) is now 1.26 MB on disk, consisting of exactly 9 meshes, 13 primitives, 13 materials, and 9 nodes. The only extension used is `KHR_draco_mesh_compression`. 

Crucially, KiCad's "Texture Atlas / Palette" option was **turned off**. This is true and load-bearing. If we ran a `palette()` then `join()`, it welded the copper under an opaque mask—traces stayed in the buffer and didn't show. The pipeline that actually ran in `optimize-pcb.mjs` does not `palette()` or `simplify()`. Instead, it was:
`dedup → join(keepMeshes) → flatten → join → weld → prune → sparse → draco`.

This keeps the layers separate (`*_copper`, `*_pad`, `*_silkscreen`, `*_soldermask`, `*_PCB`, plus a few footprint meshes like SOIC-16, LED 0805, C 0603, R-array SIP9). Keeping these distinct allows our `pcb-look.js` script to dynamically apply shiny clearcoat to the mask and high metalness to the pads.

### The ~3.5-Second Main Thread Freeze

Before this optimization, the ~31MB model had thousands of un-instanced meshes, which choked Three.js draw calls. To compensate, we were running a custom `mergeByMaterial` script on the client side that iterated through every mesh and merged their geometries before rendering. 

Running this on the browser caused a massive main-thread freeze. A checked-in Lighthouse run (13.4.0, Chrome extensions on) recorded a Total Blocking Time (TBT) of **3,130 ms**, a Max Potential FID of **3,530 ms**, and an overall Performance score of **43** (though Accessibility and SEO both hit 100, and Best Practices 96).

Because the new export is already joined by material in glTF-Transform, the client-side merge now skips entirely since the mesh count is under 32. We didn't actually rip out `mergeByMaterial` / `bakeGeo` / `mergeGeometries`—they still live in `pcb-look.js`—but both `viewer.js` and `bench.js` just call a single load path, and the merge bails out early. Draco still decodes and materials still get dressed, so it isn't a zero-overhead load, but the ~3.5s freeze is completely gone.

### Lighting & Material Contrast

For the materials:
- Dropped ambient `hemiIntensity` to `0.6` to introduce deep, realistic shadows.
- Set the soldermask clearcoat to `1` and opacity to `0.86`, with a deep green color (`#1a9a48`). 
- Copper is `#c4a020` and FR4 is `#0c3320`, allowing the bright, metallic copper traces underneath to physically shine through the deep green gloss.

### Media & Assets

- **Front Page Hero**: Replaced with `assets/pcb/hero.gif` (clicks through to `viewer.html`). The source was `hero.mp4` (23.2 MB, 1080x1080, 30 fps, 17.90s, H.264). The GIF on disk is 16.6 MB, 480x480, 10 fps with a full 256-color palette (a 720@15 palette pass was 51 MB, hence why the 480/10 version exists).
- **Then/Now Plate**: The lot 07 plate is `pcb-arrive.webp` (1120x1120, 280 KB), shot by hand.
- **KiCad Orbit Spin**: The old `immersion_white.gif` was 9.6 MB, 480², 223 frames. Front no longer uses that spin as the lead. The README was left as KiCad spin + physical photo side by side.
- **Viewer Details**: The 3D viewer now features a story rail (closed Catmull-Rom), a mask peel effect, and captions. Any drag or scroll aborts the tour to hand you a 1:1 orbit. No extra camera library needed. (We tried a film-style pass with letterbox and fog, but removed it).