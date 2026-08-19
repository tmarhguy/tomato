#!/usr/bin/env node
/**
 * Encode assembly stills for the paper.
 *
 *   node scripts/optimize-assembly.mjs
 *
 * Source of truth: media/assembly/*.jpeg
 * Ships:           web/assets/assembly/*.webp
 *
 * The DigiKey still in media/ is already cropped to the branded face
 * (shipping label stripped). Do not re-extract.
 */
import { mkdirSync, statSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const root = resolve(web, "..");
const destDir = join(web, "assets/assembly");
const quality = 82;

const jobs = [
  {
    src: "media/assembly/digikey_order_box.jpeg",
    dest: "digikey-box.webp",
  },
  {
    src: "media/assembly/work_setup_solder.jpeg",
    dest: "work-setup.webp",
  },
  {
    src: "media/assembly/half_soldered_board_next_to_sim.jpeg",
    dest: "half-soldered.webp",
  },
  {
    src: "media/assembly/half_soldered_board_next_to_sim.jpeg",
    dest: "half-soldered-plate.webp",
    // Square plate for the front-page lot card / og:image (matches pcb-arrive.webp).
    cover: 1120,
    // Keep the held board and the Digital render; drop the keyboard.
    position: "centre",
  },
];

async function encode(job) {
  const input = resolve(root, job.src);
  if (!existsSync(input)) throw new Error(`missing ${job.src}`);
  const dest = join(destDir, job.dest);
  let img = sharp(input).rotate();
  if (job.extract) img = img.extract(job.extract);
  if (job.cover) {
    img = img.resize({
      width: job.cover,
      height: job.cover,
      fit: "cover",
      position: job.position || "centre",
      withoutEnlargement: true,
    });
  }
  await img.webp({ quality, effort: 6, smartSubsample: true }).toFile(dest);
  const meta = await sharp(dest).metadata();
  const bytes = statSync(dest).size;
  console.log(
    `${job.dest}  ${meta.width}×${meta.height}  ${(bytes / 1024).toFixed(1)} KiB`
  );
  return bytes;
}

mkdirSync(destDir, { recursive: true });
let total = 0;
for (const job of jobs) total += await encode(job);
console.log(`done — ${(total / 1024).toFixed(1)} KiB stills`);
