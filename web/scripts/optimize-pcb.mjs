#!/usr/bin/env node
/**
 * Compress a KiCad GLB without flattening copper into the soldermask.
 *
 * palette() was the previous pipeline's bug: it bakes every solid color into
 * one atlas, then join() welds copper, pads, zones, and mask into a single
 * opaque mesh. Traces exist in the buffer and never show.
 *
 * This keeps each KiCad layer on its own material (copper / mask / silk /
 * FR4 / pads), joins footprints by material, and Draco-compresses.
 * No palette() — that atlas is what hid traces under an opaque mask.
 * No simplify() — thin traces and pin rows stay intact.
 *
 *   node scripts/optimize-pcb.mjs path/to/kicad-export.glb [out.glb]
 *
 * Default output is assets/pcb/alu.glb. Pass the raw KiCad export as input;
 * do not re-run this on an already-Draco file.
 */
import { mkdirSync, existsSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS } from "@gltf-transform/extensions";
import {
  dedup,
  draco,
  flatten,
  join,
  prune,
  sparse,
  weld,
} from "@gltf-transform/functions";
import draco3d from "draco3dgltf";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const input = resolve(process.argv[2] || "");
const output = resolve(process.argv[3] || `${web}/assets/pcb/alu.glb`);

if (!process.argv[2]) {
  console.error("usage: node scripts/optimize-pcb.mjs <kicad-export.glb> [out.glb]");
  process.exit(1);
}

if (!existsSync(input)) {
  console.error(`missing input: ${input}`);
  process.exit(1);
}

const io = new NodeIO()
  .registerExtensions(ALL_EXTENSIONS)
  .registerDependencies({
    "draco3d.decoder": await draco3d.createDecoderModule(),
    "draco3d.encoder": await draco3d.createEncoderModule(),
  });

const document = await io.read(input);

await document.transform(
  dedup(),
  // Collapse KiCad's per-pad primitives inside each footprint (267 → ~3).
  // Do this before flatten/join, and skip instance(): join() clones shared
  // meshes, which would break GPU instancing, and instanced nodes cannot
  // be joined. Baking footprints by material is fewer draw calls anyway.
  join({ keepMeshes: true }),
  flatten(),
  join({ keepNamed: false }),
  weld(),
  prune(),
  sparse({ ratio: 0.2 }),
  draco({ method: "edgebreaker", quantizePosition: 14 })
);

mkdirSync(dirname(output), { recursive: true });
await io.write(output, document);

const root = document.getRoot();
console.log(`wrote ${output} (${(statSync(output).size / 1e6).toFixed(2)} MB)`);
console.log(
  `meshes=${root.listMeshes().length} materials=${root.listMaterials().length} nodes=${root.listNodes().length}`
);
for (const mesh of root.listMeshes()) {
  const prims = mesh.listPrimitives();
  const mat = prims[0]?.getMaterial()?.getName() || "";
  const verts = prims.reduce((n, p) => n + (p.getAttribute("POSITION")?.getCount() || 0), 0);
  console.log(`  ${mesh.getName() || "(unnamed)"} prims=${prims.length} verts=${verts} mat=${mat}`);
}
for (const mat of root.listMaterials()) {
  const c = mat.getBaseColorFactor();
  console.log(
    `  mat ${mat.getName()} alpha=${mat.getAlphaMode()} rgba=${c.map((x) => x.toFixed(3)).join(",")} metal=${mat.getMetallicFactor()} rough=${mat.getRoughnessFactor()}`
  );
}
