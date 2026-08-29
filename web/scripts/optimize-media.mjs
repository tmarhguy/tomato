#!/usr/bin/env node
/**
 * In-place visually-lossless optimize for media/ and web/assets sources.
 * Videos longer than 90s become an iPhone-style timelapse (silent, ~20–40s).
 */
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { copyFileSync, mkdirSync, readdirSync, renameSync, statSync, unlinkSync } from "node:fs";
import { dirname, extname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import sharp from "sharp";

const require = createRequire(import.meta.url);
const ffmpeg = require("ffmpeg-static");
const ffprobe = require("ffprobe-static").path;

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const root = resolve(web, "..");
const SKIP_DIR = new Set(["node_modules", "gallery", ".git"]);
const IMG = new Set([".png", ".jpg", ".jpeg", ".webp"]);
const VID = new Set([".mp4", ".mov", ".webm"]);

function walk(dir, out = []) {
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    if (name.name.startsWith(".")) continue;
    if (SKIP_DIR.has(name.name)) continue;
    const p = join(dir, name.name);
    if (name.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

function run(bin, args, label) {
  const r = spawnSync(bin, args, { encoding: "utf8", maxBuffer: 20e6 });
  if (r.status !== 0) {
    throw new Error(`${label} failed\n${r.stderr || r.stdout}`);
  }
  return r;
}

function probe(file) {
  const r = run(
    ffprobe,
    ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", file],
    "ffprobe"
  );
  return JSON.parse(r.stdout);
}

function iphoneSpeed(duration) {
  // iPhone timelapse: capture interval grows with length; playback ~30 fps.
  // Map 90s+ onto a 20–40s cut, never slower than 8×, never faster than 60×.
  const target = Math.min(40, Math.max(20, duration / 12));
  return Math.min(60, Math.max(8, duration / target));
}

async function optimizeImage(file) {
  const ext = extname(file).toLowerCase();
  const before = statSync(file).size;
  if (ext === ".webp") return { before, after: before, skipped: true };

  const tmp = join(tmpdir(), `tomato-img-${process.pid}-${Date.now()}${ext}`);
  let img = sharp(file, { failOn: "none", animated: false }).rotate();
  const meta = await img.metadata();
  const w = meta.width || 0;
  if (w > 2560) img = img.resize({ width: 2560, withoutEnlargement: true });

  if (ext === ".png") {
    await img.png({ compressionLevel: 9, quality: 90, effort: 8 }).toFile(tmp);
  } else {
    await img.jpeg({ quality: 88, mozjpeg: true, progressive: true }).toFile(tmp);
  }

  const after = statSync(tmp).size;
  if (after < before * 0.98 && after > 1024) {
    renameSync(tmp, file);
    return { before, after };
  }
  unlinkSync(tmp);
  return { before, after: before, skipped: true };
}

function optimizeVideo(file) {
  const ext = extname(file).toLowerCase();
  if (ext === ".webm") {
    return { skipped: true, before: statSync(file).size, after: statSync(file).size, duration: 0, speed: 1 };
  }
  const before = statSync(file).size;
  const info = probe(file);
  const duration = Number(info.format?.duration || 0);
  const v = (info.streams || []).find((s) => s.codec_type === "video") || {};
  const w = Number(v.width || 0);
  const tmp = file + ".opt-tmp.mp4";
  const long = duration > 90;
  const speed = long ? iphoneSpeed(duration) : 1;
  const scale = "scale='min(1920,iw)':-2:flags=lanczos";
  const vf = long
    ? `${scale},setpts=PTS/${speed.toFixed(3)},fps=30`
    : `${scale}`;
  const preset = before > 80e6 ? "faster" : "medium";
  const args = [
    "-y",
    "-i",
    file,
    "-an",
    "-vf",
    vf,
    "-c:v",
    "libx264",
    "-preset",
    preset,
    "-crf",
    long ? "19" : "20",
    "-pix_fmt",
    "yuv420p",
    "-movflags",
    "+faststart",
    tmp,
  ];
  run(ffmpeg, args, "ffmpeg " + relative(root, file));
  const after = statSync(tmp).size;
  if (after >= before * 0.97) {
    unlinkSync(tmp);
    return { before, after: before, duration, speed: long ? speed : 1, long, kept: true };
  }
  const dest = file;
  // overwrite original path; keep .mov name even if mp4 bitstream
  renameSync(tmp, dest);
  return { before, after, duration, speed: long ? speed : 1, long };
}

const files = [...walk(join(root, "media")), ...walk(join(web, "assets"))].filter((p) => {
  const e = extname(p).toLowerCase();
  if (p.includes("/assets/gallery/")) return false;
  return IMG.has(e) || VID.has(e);
});

const images = files.filter((p) => IMG.has(extname(p).toLowerCase()));
const videos = files.filter((p) => VID.has(extname(p).toLowerCase()));

console.log(`optimize-media · ${images.length} images · ${videos.length} videos`);

let saved = 0;
for (const file of images) {
  try {
    const r = await optimizeImage(file);
    const delta = r.before - r.after;
    saved += Math.max(0, delta);
    const tag = r.skipped ? "keep" : `${(r.after / 1024).toFixed(0)} KiB (−${((delta / r.before) * 100).toFixed(0)}%)`;
    console.log(`img  ${relative(root, file)}  ${tag}`);
  } catch (err) {
    console.warn("img skip", relative(root, file), err.message.split("\n")[0]);
  }
}

for (const file of videos) {
  try {
    const r = optimizeVideo(file);
    if (r.skipped) {
      console.log(`vid  ${relative(root, file)}  skip webm`);
      continue;
    }
    saved += Math.max(0, r.before - r.after);
    console.log(
      `vid  ${relative(root, file)}  ${(r.duration).toFixed(1)}s ×${r.speed.toFixed(1)} → ${(r.after / 1e6).toFixed(2)} MB`
    );
  } catch (err) {
    console.warn("vid skip", relative(root, file), err.message.split("\n").slice(0, 4).join(" "));
  }
}

console.log(`saved ${(saved / 1e6).toFixed(1)} MB`);
