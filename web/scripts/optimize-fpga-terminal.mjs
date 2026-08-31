#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { mkdirSync, statSync, unlinkSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const require = createRequire(import.meta.url);
const ffmpeg = require("ffmpeg-static");
const ffprobe = require("ffprobe-static").path;

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const root = resolve(web, "..");
const src = join(root, "fpga_terminal_program.mp4");
const out = join(web, "assets/compiler/fpga-terminal-program.mp4");
const posterWebp = join(web, "assets/compiler/fpga-terminal-program.webp");
const posterPng = join(web, "assets/compiler/fpga-terminal-program.png");

function run(bin, args, label) {
  const r = spawnSync(bin, args, { encoding: "utf8", maxBuffer: 30e6 });
  if (r.status !== 0) throw new Error(`${label} failed\n${(r.stderr || r.stdout).slice(-2500)}`);
}

run(
  ffmpeg,
  [
    "-y",
    "-i",
    src,
    "-an",
    "-vf",
    "scale='min(1280,iw)':-2:flags=lanczos",
    "-c:v",
    "libx264",
    "-preset",
    "slow",
    "-crf",
    "21",
    "-pix_fmt",
    "yuv420p",
    "-movflags",
    "+faststart",
    out,
  ],
  "encode"
);

const before = statSync(src).size;
const after = statSync(out).size;
console.log(`mp4 ${(before / 1e6).toFixed(2)} MB → ${(after / 1e6).toFixed(2)} MB`);

run(ffmpeg, ["-y", "-ss", "17.5", "-i", out, "-vframes", "1", posterPng], "poster");
await sharp(posterPng).webp({ quality: 86, effort: 6 }).toFile(posterWebp);
unlinkSync(posterPng);

for (const w of [128, 640, 1280]) {
  const dest = join(web, "assets/gallery/compiler", `fpga-terminal-program-${w}w.webp`);
  mkdirSync(dirname(dest), { recursive: true });
  await sharp(posterWebp)
    .resize({ width: w, withoutEnlargement: true })
    .webp({ quality: w <= 128 ? 78 : w <= 640 ? 82 : 86, effort: 6 })
    .toFile(dest);
  console.log(`poster ${w}w ${(statSync(dest).size / 1024).toFixed(1)} KiB`);
}

const dur = spawnSync(
  ffprobe,
  ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", out],
  { encoding: "utf8" }
);
console.log(`duration ${Number(dur.stdout).toFixed(1)}s`);
