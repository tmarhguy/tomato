#!/usr/bin/env node
/**
 * Re-encode assembly stills already under assets/assembly/.
 *
 * Canonical stills are the webp files in assets/assembly/ — there is no
 * separate media/ originals tree. Drop a new camera dump next to the script
 * args if you need a fresh encode; otherwise this only rebuilds the square
 * plate from half-soldered.webp.
 *
 *   node scripts/optimize-assembly.mjs
 */
import { mkdirSync, statSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const destDir = join(web, "assets/assembly");
const quality = 82;

const jobs = [
  {
    src: "assets/assembly/half-soldered.webp",
    dest: "half-soldered-plate.webp",
    // Square plate for the front-page lot card / og:image (matches pcb-arrive.webp).
    cover: 1120,
    position: "centre",
  },
];

async function encode(job) {
  const input = resolve(web, job.src);
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
