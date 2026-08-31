#!/usr/bin/env node
/**
 * Encode the KiCad 07_alu isometric for Open Graph + site plates.
 *
 *   node scripts/optimize-og.mjs
 *
 * Source: media/pcb/board_iso.png
 * Ships:  web/assets/og/tomato-board.webp      (1200×630 social card)
 *         web/assets/pcb/board-iso.webp         (1280w full aspect)
 *         web/assets/gallery/pcb/board-iso-{640,1280}w.webp
 */
import { mkdirSync, statSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const root = resolve(web, "..");
const src = resolve(root, "media/pcb/board_iso.png");
const quality = 82;

if (!existsSync(src)) {
  console.error(`missing ${src}`);
  process.exit(1);
}

async function writeWebp(img, dest, label) {
  mkdirSync(dirname(dest), { recursive: true });
  await img.clone().webp({ quality, effort: 6, smartSubsample: true }).toFile(dest);
  const meta = await sharp(dest).metadata();
  const bytes = statSync(dest).size;
  console.log(`${label}  ${meta.width}×${meta.height}  ${(bytes / 1024).toFixed(1)} KiB`);
  return bytes;
}

const base = sharp(src).rotate();
let total = 0;

total += await writeWebp(
  base.clone().resize({ width: 1200, height: 630, fit: "cover", position: "centre" }),
  join(web, "assets/og/tomato-board.webp"),
  "og/tomato-board.webp"
);

total += await writeWebp(
  base.clone().resize({ width: 1280, withoutEnlargement: true }),
  join(web, "assets/pcb/board-iso.webp"),
  "pcb/board-iso.webp"
);

for (const w of [640, 1280]) {
  total += await writeWebp(
    base.clone().resize({ width: w, withoutEnlargement: true }),
    join(web, "assets/gallery/pcb/board-iso-" + w + "w.webp"),
    `gallery/pcb/board-iso-${w}w.webp`
  );
}

console.log(`done — ${(total / 1024).toFixed(1)} KiB OG stills`);
