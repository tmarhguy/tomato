#!/usr/bin/env node
/**
 * Build responsive WebP variants for the gallery carousel.
 *
 *   node scripts/optimize-gallery.mjs
 *
 * Reads unique image paths from gallery.html slide data attributes and writes:
 *   assets/gallery/{path-without-ext}-{width}w.webp
 *
 * Widths: 128 (filmstrip), 640 (carousel), 1280 (lightbox / retina).
 */
import { readFileSync, mkdirSync, existsSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const galleryHtml = join(web, "gallery.html");
const widths = [128, 640, 1280];

/** Already-built responsive gallery variants — do not re-encode into gallery/gallery/. */
const GALLERY_VARIANT = /^assets\/gallery\/.+\-\d+w\.(webp|jpe?g|jpg|png)$/i;

function collectSources(html) {
  const paths = new Set();
  const re = /data-(?:src|thumb|poster)="(assets\/[^"]+\.(?:webp|jpe?g|jpg|png))"/gi;
  let m;
  while ((m = re.exec(html))) {
    const p = m[1];
    if (p.endsWith(".mp4")) continue;
    if (GALLERY_VARIANT.test(p)) continue;
    paths.add(p);
  }
  return [...paths].sort();
}

function outPath(src, width) {
  const rel = src.replace(/^assets\//, "").replace(/\.(webp|jpe?g|jpg|png)$/i, "");
  return join(web, "assets/gallery", `${rel}-${width}w.webp`);
}

async function encode(src, width, dest) {
  mkdirSync(dirname(dest), { recursive: true });
  const input = join(web, src);
  if (!existsSync(input)) {
    console.warn(`skip missing ${src}`);
    return null;
  }
  const quality = width <= 128 ? 78 : width <= 640 ? 82 : 86;
  await sharp(input)
    .rotate()
    .resize({ width, withoutEnlargement: true })
    .webp({ quality, effort: 6, smartSubsample: true })
    .toFile(dest);
  return statSync(dest).size;
}

const html = readFileSync(galleryHtml, "utf8");
const sources = collectSources(html);
if (!sources.length) {
  console.error("no gallery image sources found");
  process.exit(1);
}

let total = 0;
for (const src of sources) {
  for (const w of widths) {
    const dest = outPath(src, w);
    const bytes = await encode(src, w, dest);
    if (bytes != null) {
      total += bytes;
      console.log(`${src} → ${dest.replace(web + "/", "")} (${(bytes / 1024).toFixed(1)} KiB)`);
    }
  }
}
console.log(`done — ${sources.length} sources, ${(total / 1024).toFixed(1)} KiB total variants`);
