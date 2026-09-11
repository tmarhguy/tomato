/**
 * Static-site sanity for The Tomato paper.
 * Pure Node — no install. Catches what breaks on Vercel / local preview:
 * missing assets, dead relative links, root-absolute paths, broken JS syntax,
 * missing deploy markers, and a local HTTP smoke of every HTML page.
 */
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { dirname, join, normalize, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import http from "node:http";

const __dirname = dirname(fileURLToPath(import.meta.url));
const WEB = resolve(__dirname, "..");

const REQUIRED = [
  "index.html",
  "404.html",
  ".nojekyll",
  "css/magazine.css",
  "css/viewer.css",
  "js/mast.js",
  "js/bench.js",
  "js/landing.js",
  "js/vercel-analytics.js",
  "js/vercel-speed-insights.js",
  "js/viewer.js",
  "js/pcb-look.js",
  "viewer.html",
  "js/forge.js",
  "js/arch-map.js",
  "js/alu.js",
  "js/playground.js",
  "playground.html",
  "assets/favicon.svg",
  "assets/mark.svg",
  "assets/mark-dark.svg",
  "assets/dip-dark.svg",
  "assets/slice-dark.svg",
  "assets/pcb/alu.glb",
  "assets/pcb/immersion_black.mp4",
  "assets/pcb/immersion_black.webp",
  "assets/pcb/immersion_white.webp",
  "assets/pcb/immersion_white_poster.webp",
  "assets/pcb/hero.mp4",
  "assets/pcb/hero.webp",
  "assets/compiler/opcode-sweep-sim.mp4",
  "assets/compiler/opcode-sweep-fpga.mp4",
  "assets/compiler/opcode-sweep-sim.webp",
  "assets/compiler/opcode-sweep-fpga.webp",
  "assets/compiler/fpga-terminal-program.mp4",
  "assets/compiler/fpga-terminal-program.webp",
  "assets/assembly/digikey-box.webp",
  "assets/assembly/work-setup.webp",
  "assets/assembly/work-setup.mp4",
  "assets/assembly/board-test.webp",
  "assets/assembly/half-soldered.webp",
  "assets/assembly/half-soldered-plate.webp",
  "assets/og/tomato-board.webp",
  "assets/pcb/board-iso.webp",
  "assets/pcb/board-iso-light.webp",
  "assets/assembly/placing-and-soldering.mp4",
  "assets/assembly/placing-and-soldering.webp",
  "assets/assembly/soldering-led.mp4",
  "assets/assembly/soldering-led.webp",
  "boards.html",
  "architecture.html",
  "verification.html",
  "sitemap.xml",
  "robots.txt",
  "site.webmanifest",
  "humans.txt",
  ".well-known/security.txt",
  "data/seo.json",
  "isa.html",
  "os.html",
  "journal.html",
  "board.html",
  "gallery.html",
  "source.html",
  "about.html",
  "js/gallery.js",
  "js/compiler-reels.js",
  "js/media-lightbox.js",
];

const NAV = [
  "index.html",
  "architecture.html",
  "verification.html",
  "isa.html",
  "software.html",
  "os.html",
  "playground.html",
  "journal.html",
  "boards.html",
  "board.html",
  "gallery.html",
  "source.html",
  "about.html",
];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === ".git") continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

function htmlFiles() {
  return walk(WEB).filter((p) => p.endsWith(".html"));
}

function relWeb(abs) {
  return relative(WEB, abs).split(sep).join("/");
}

function resolveHref(fromFile, href) {
  const clean = String(href).split("#")[0].split("?")[0];
  if (!clean) return null;
  if (/^(https?:|mailto:|data:|javascript:)/i.test(clean)) return null;
  if (clean.startsWith("//")) return null;
  const base = dirname(fromFile);
  return normalize(resolve(base, clean));
}

function attrs(html, names) {
  const found = [];
  for (const name of names) {
    const re = new RegExp(`${name}\\s*=\\s*["']([^"']+)["']`, "gi");
    let m;
    while ((m = re.exec(html))) found.push({ name, value: m[1] });
  }
  return found;
}

function magic(path, start, label) {
  const buf = readFileSync(path);
  const got = buf.subarray(0, start.length).toString("latin1");
  assert.equal(got, start, `${label}: expected ${JSON.stringify(start)} got ${JSON.stringify(got)}`);
  return buf.length;
}

function hasFtyp(path, label) {
  const buf = readFileSync(join(WEB, path)).subarray(0, 12);
  const tag = buf.subarray(4, 8).toString("latin1");
  assert.equal(tag, "ftyp", `${label}: not an MP4 (missing ftyp)`);
  const size = statSync(join(WEB, path)).size;
  assert.ok(size > 80_000, `${label}: ${size} B is too small to be a clip`);
  assert.ok(size < 20_000_000, `${label}: ${size} B is too fat for the tab`);
  return size;
}

function isUnderWeb(abs) {
  const root = WEB.endsWith(sep) ? WEB : WEB + sep;
  return abs === WEB || abs.startsWith(root);
}

test("required deploy files exist", () => {
  for (const f of REQUIRED) {
    assert.ok(existsSync(join(WEB, f)), `missing ${f}`);
  }
});

test("HTML documents have basics", () => {
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    const label = relWeb(file);
    const viewer = label === "viewer.html";
    assert.match(html, /<!DOCTYPE html>/i, `${label}: doctype`);
    assert.match(html, /<html\b[^>]*\blang=/i, `${label}: lang`);
    assert.match(html, /charset=["']utf-8["']/i, `${label}: charset`);
    assert.match(html, /name=["']viewport["']/i, `${label}: viewport`);
    assert.match(html, /<title>[^<]+<\/title>/i, `${label}: title`);
    assert.match(
      html,
      viewer
        ? /viewer\.css/
        : label === "index.html"
          ? /landing\.css/
          : /magazine\.css/,
      `${label}: stylesheet`
    );
    assert.match(html, /favicon\.svg/, `${label}: favicon`);
  }
});

test("no root-absolute asset or page paths (breaks nested pages and local preview)", () => {
  const bad = [];
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    for (const { name, value } of attrs(html, ["href", "src", "poster"])) {
      if (value.startsWith("/") && !value.startsWith("//")) {
        bad.push(`${relWeb(file)} ${name}="${value}"`);
      }
    }
  }
  const css = readFileSync(join(WEB, "css/magazine.css"), "utf8");
  for (const m of css.matchAll(/url\(\s*["']?(\/[^)'"\s]+)/g)) {
    bad.push(`css/magazine.css url(${m[1]})`);
  }
  assert.deepEqual(bad, [], bad.join("\n"));
});

test("relative href/src resolve on disk", () => {
  const missing = [];
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    for (const { value } of attrs(html, ["href", "src", "poster"])) {
      const target = resolveHref(file, value);
      if (!target) continue;
      if (!isUnderWeb(target)) {
        missing.push(`${relWeb(file)} escapes web/: ${value}`);
        continue;
      }
      if (!existsSync(target)) {
        missing.push(`${relWeb(file)} → ${value}`);
      }
    }
  }
  assert.deepEqual(missing, [], missing.join("\n"));
});

test("primary nav present on every page", () => {
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    const label = relWeb(file);
    if (label === "viewer.html") {
      assert.match(html, /class=["']back["']/, `${label}: back link`);
      assert.match(html, /index\.html/, `${label}: home`);
      continue;
    }
    if (label === "index.html") {
      assert.match(html, /aria-label="Site"/);
      assert.match(html, /aria-label="All project pages"/);
      assert.match(html, /js\/landing\.js/);
      assert.doesNotMatch(html, /class="front-paths"/);
    } else {
      assert.match(html, /project-primary/, `${label}: static primary navigation`);
      assert.match(html, /js\/mast\.js/, `${label}: shared interactions`);
    }
    for (const page of [...NAV, "viewer.html"]) {
      const leaf = page.replace(/\.html$/, "");
      assert.ok(
        html.includes(page) || html.includes(`../${page}`),
        `${label}: missing nav link to ${page}`
      );
      void leaf;
    }
  }
});

test("journal index lists every journal/*.html article", () => {
  const articles = readdirSync(join(WEB, "journal"))
    .filter((n) => n.endsWith(".html"))
    .sort();
  const index = readFileSync(join(WEB, "journal.html"), "utf8");
  const missing = articles.filter((a) => !index.includes(`journal/${a}`));
  assert.deepEqual(missing, [], `journal.html missing: ${missing.join(", ")}`);
});

test("board playground wires Three.js import map + bench module", () => {
  const index = readFileSync(join(WEB, "index.html"), "utf8");
  const board = readFileSync(join(WEB, "board.html"), "utf8");
  assert.match(index, /type=["']importmap["']/, "index.html: importmap");
  assert.match(index, /js\/bench\.js/, "index.html: bench module");
  assert.match(index, /id=["']front-bench["']/, "index.html: interactive board canvas");
  assert.match(board, /type=["']importmap["']/, "board.html: importmap");
  assert.match(board, /three@0\.169\.0/, "board.html: three CDN pin");
  assert.match(board, /js\/bench\.js/, "board.html: bench module");
  assert.match(board, /id=["']bench["']/, "board.html: #bench canvas");
});

test("source page loads forge.js", () => {
  const html = readFileSync(join(WEB, "source.html"), "utf8");
  assert.match(html, /js\/forge\.js/);
  assert.match(html, /id=["']forge["']/);
});

test("playground wires Dual-LUT emulator modules", () => {
  const html = readFileSync(join(WEB, "playground.html"), "utf8");
  assert.match(html, /<script(?=[^>]*type=["']module["'])(?=[^>]*src=["']js\/playground\.js)[^>]*>/);
  assert.match(html, /id=["']pg-main["']/);
  assert.match(html, /id=["']pg-hero["']/);
  assert.match(html, /id=["']pg-bench["']/);
  assert.match(html, /id=["']pg-detail["']/);
});

test("3D viewer page is the light 07_alu tour", () => {
  const html = readFileSync(join(WEB, "viewer.html"), "utf8");
  assert.match(html, /type=["']importmap["']/);
  assert.match(html, /three@0\.169\.0/);
  assert.doesNotMatch(html, /camera-controls/);
  assert.match(html, /type=["']module["'][^>]+js\/viewer\.js/);
  assert.match(html, /<main[^>]*id=["']full-screen-viewer["']/);
  assert.match(html, /<h1/);
  assert.match(html, /id=["']viewer-canvas["']/);
  assert.match(html, /id=["']immerse["']/);
  assert.match(html, /id=["']tour-line["']/);
  assert.match(html, /id=["']tour-caption["']/);
  assert.match(html, /cdn\.jsdelivr\.net/);
  const css = readFileSync(join(WEB, "css/viewer.css"), "utf8");
  assert.match(css, /#050505/);
  assert.match(css, /#ff583f/);
  assert.match(css, /\.tour-caption/);
  const js = readFileSync(join(WEB, "js/viewer.js"), "utf8");
  const look = readFileSync(join(WEB, "js/pcb-look.js"), "utf8");
  assert.match(js, /assets\/pcb\/alu\.glb/);
  assert.match(js, /OrbitControls/);
  assert.match(look, /RoomEnvironment/);
  assert.match(js, /buildTourCurve/);
  assert.match(js, /sampleTour/);
  assert.match(js, /PATH_S/);
  assert.match(js, /applyMaskPeel/);
  const index = readFileSync(join(WEB, "index.html"), "utf8");
  const board = readFileSync(join(WEB, "board.html"), "utf8");
  assert.match(index, /viewer\.html/, "index.html: Tour opens viewer");
  assert.match(index, /site-menu[\s\S]*viewer\.html/, "index.html: Tour in all-pages menu");
  assert.match(index, /front-links[\s\S]*architecture\.html/, "index.html: Architecture in site links");
  assert.match(index, /href="#what-is-tomato"/, "index.html: introduction is reachable");
  assert.match(board, /viewer\.html/, "board.html: Tour opens viewer");
  assert.match(board, /class=["']bench-tour["']/, "board.html: Tour CTA on the board");
});

test("JS modules parse (syntax)", async () => {
  const files = walk(WEB)
    .map(relWeb)
    .filter((r) => (r.startsWith("js/") && r.endsWith(".js")) || (r.startsWith("scripts/") && r.endsWith(".mjs")));
  assert.ok(files.includes("js/mast.js"));
  assert.ok(files.includes("scripts/optimize-pcb.mjs"));
  assert.ok(files.includes("scripts/optimize-gallery.mjs"));
  assert.ok(files.includes("scripts/optimize-assembly.mjs"));
  for (const file of files) {
    const abs = join(WEB, file);
    await new Promise((resolveP, reject) => {
      const child = spawn(process.execPath, ["--check", abs], { stdio: ["ignore", "pipe", "pipe"] });
      let err = "";
      child.stderr.on("data", (d) => (err += d));
      child.on("close", (code) => {
        if (code === 0) resolveP();
        else reject(new Error(`${file}: ${err || `exit ${code}`}`));
      });
    });
  }
});

test("GLB is a glTF binary with materials", () => {
  const buf = readFileSync(join(WEB, "assets/pcb/alu.glb"));
  assert.equal(buf.subarray(0, 4).toString("ascii"), "glTF");
  assert.ok(buf.length > 1_000_000, "GLB unexpectedly tiny");
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.subarray(20, 20 + jsonLen).toString("utf8"));
  assert.ok(Array.isArray(json.materials) && json.materials.length > 0);
  assert.ok(json.extensionsUsed?.includes("KHR_draco_mesh_compression"));
  const names = (json.meshes || []).map((m) => m.name || "");
  assert.ok(names.some((n) => /copper/i.test(n)), "copper mesh missing — palette() may have flattened traces");
  assert.ok(names.some((n) => /soldermask/i.test(n)), "soldermask mesh missing");
  assert.ok((json.meshes || []).length <= 16, `too many meshes (${json.meshes.length}) — ship the Draco join, not the KiCad dump`);
  assert.ok(buf.length < 8_000_000, `GLB ${buf.length} B is too fat — 31 MB KiCad export leaked into the tab`);
  assert.ok(json.asset?.extras?.generator?.includes?.("KiCad") || json.asset?.generator);
});

test("CSS has brand tokens", () => {
  const css = readFileSync(join(WEB, "css/magazine.css"), "utf8");
  assert.match(css, /--bg:/);
  assert.match(css, /--ink:/);
  assert.match(css, /--rule:/);
  assert.match(css, /data-theme=dark/);
  assert.match(css, /prefers-color-scheme:\s*dark/);
  assert.match(css, /\.theme-switch/);
  assert.match(css, /\.pg-schematic/);
  assert.match(css, /\.pg-hero/);
  assert.match(css, /\.mast-nav/);
  assert.match(css, /\.plate--square/);
  assert.match(css, /\.figure--inset/);
  assert.match(css, /\.story \.figure \+ \.caption/);
});

test("gallery ships responsive WebP variants and LCP preload", () => {
  const html = readFileSync(join(WEB, "gallery.html"), "utf8");
  assert.match(html, /fetchpriority="high"/);
  assert.match(html, /assets\/gallery\/os\/desktop-home-1280w\.webp/);
  assert.match(html, /hdmi-demo-games-ui\.mp4/);
  assert.ok(existsSync(join(WEB, "assets/os/hdmi-demo-games-ui.mp4")));
  assert.ok(existsSync(join(WEB, "assets/os/hdmi-demo-poster.jpg")));
  assert.ok(existsSync(join(WEB, "assets/gallery/os/desktop-home-1280w.webp")));
  assert.ok(existsSync(join(WEB, "assets/gallery/os/desktop-home-640w.webp")));
  assert.ok(existsSync(join(WEB, "assets/gallery/assembly/placing-and-soldering-640w.webp")));
  assert.ok(existsSync(join(WEB, "assets/gallery/assembly/half-soldered-plate-640w.webp")));
  assert.ok(existsSync(join(WEB, "assets/gallery/pcb/pcb-arrive-640w.webp")));
  // First slide is Desktop v1.2 with wallpaper — Sep 11 lead
  const slides = html.slice(html.indexOf('class="gallery-slides"'));
  const firstSrc = slides.match(/data-src="([^"]+)"/);
  assert.equal(firstSrc && firstSrc[1], "assets/gallery/os/desktop-home-1280w.webp");
  const js = readFileSync(join(WEB, "js/gallery.js"), "utf8");
  assert.match(js, /galleryVariant/);
  assert.match(js, /fetchPriority/);
  assert.match(js, /deferSrc/);
});

test("homepage explains register capacity with bounded comparisons", () => {
  const html = readFileSync(join(WEB, "index.html"), "utf8");
  for (const phrase of ["32,768", "65,536", "storage capacity only", "NVIDIA Blackwell SM", "15 address bits", "RV32I", "x0"]) {
    assert.ok(html.includes(phrase), `homepage missing register context: ${phrase}`);
  }
  assert.match(html, /journal\/register-upgrade\.html/);
  assert.match(html, /https:\/\/docs\.nvidia\.com\/cuda\/blackwell-tuning-guide/);
  const journal = readFileSync(join(WEB, "journal.html"), "utf8");
  assert.match(journal, /journal\/register-upgrade\.html/);
  assert.match(journal, /js\/journal-index\.js/);
  assert.match(journal, /32,768/);
  assert.match(journal, /journal\/tomato-works\.html/);
  const upgrade = readFileSync(join(WEB, "journal/register-upgrade.html"), "utf8");
  assert.match(upgrade, /SETBANK2/);
  assert.match(upgrade, /AS6C62256/);
  assert.match(upgrade, /General Purpose Register File/);
  assert.match(upgrade, /why-32768/);
  assert.match(upgrade, /Blackwell SM/);
  assert.match(upgrade, /15-bit address space/);
  assert.match(upgrade, /waste|disconnected/i);
  const works = readFileSync(join(WEB, "journal/tomato-works.html"), "utf8");
  assert.match(works, /register-upgrade\.html/);
});

test("homepage routes compiler evidence to the complete playground", () => {
  const html = readFileSync(join(WEB, "index.html"), "utf8");
  assert.match(html, /playground\.html#compiler/);
  const js = readFileSync(join(WEB, "js/playground.js"), "utf8");
  assert.match(js, /opcode-sweep-fpga\.mp4/);
  assert.match(js, /opcode-sweep-sim\.mp4/);
});

test("ditching-vivado ships open-source stack terminal clip", () => {
  const html = readFileSync(join(WEB, "journal/ditching-vivado.html"), "utf8");
  assert.match(html, /fpga-terminal-program\.mp4/);
  assert.match(html, /Yosys · nextpnr · bitstream/);
});

test("homepage loads the interactive board progressively with a fallback", () => {
  const html = readFileSync(join(WEB, "index.html"), "utf8");
  const js = readFileSync(join(WEB, "js/landing.js"), "utf8");
  assert.match(html, /board-iso\.webp/);
  assert.match(html, /board-iso-light\.webp/);
  assert.match(html, /__TOMATO_BOARD_ISO__/);
  assert.match(html, /fetchpriority="high"/);
  assert.match(js, /mountBench/);
  assert.match(js, /syncBoardPoster/);
  assert.match(js, /idleResetMs: reducedMotion \? 0 : 15000/);
  assert.match(js, /Retry 3D view/);
  assert.ok(html.indexOf('class="hero-board bench"') < html.indexOf('class="hero-copy"'));
});

test("HTTP smoke: every HTML page returns 200 from static server", async () => {
  const port = 8765 + Math.floor(Math.random() * 200);
  const server = spawn(process.execPath, ["-e", `
    const http = require("http");
    const fs = require("fs");
    const path = require("path");
    const root = ${JSON.stringify(WEB)};
    const mime = {
      ".html": "text/html", ".css": "text/css", ".js": "text/javascript",
      ".svg": "image/svg+xml", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
      ".png": "image/png", ".gif": "image/gif", ".glb": "model/gltf-binary", ".webp": "image/webp", ".mp4": "video/mp4"
    };
    http.createServer((req, res) => {
      let url = decodeURIComponent((req.url || "/").split("?")[0]);
      if (url.endsWith("/")) url += "index.html";
      const file = path.normalize(path.join(root, url));
      if (!file.startsWith(root)) { res.writeHead(403); return res.end(); }
      fs.readFile(file, (err, data) => {
        if (err) { res.writeHead(404); return res.end("missing"); }
        res.writeHead(200, { "Content-Type": mime[path.extname(file)] || "application/octet-stream" });
        res.end(data);
      });
    }).listen(${port}, "127.0.0.1");
  `], { stdio: ["ignore", "ignore", "pipe"] });

  const waitUp = async () => {
    for (let i = 0; i < 40; i++) {
      try {
        await get(`http://127.0.0.1:${port}/index.html`);
        return;
      } catch {
        await new Promise((r) => setTimeout(r, 50));
      }
    }
    throw new Error("server did not start");
  };

  try {
    await waitUp();
    const pages = htmlFiles().map((f) => "/" + relWeb(f));
    const assets = [
      "/css/magazine.css",
      "/css/viewer.css",
      "/js/bench.js",
      "/js/forge.js",
      "/js/mast.js",
      "/js/viewer.js",
      "/js/playground.js",
      "/assets/favicon.svg",
      "/assets/mark.svg",
      "/assets/mark-dark.svg",
      "/assets/pcb/alu.glb",
      "/assets/pcb/hero.mp4",
      "/assets/pcb/hero.webp",
      "/assets/pcb/immersion_black.mp4",
      "/assets/compiler/opcode-sweep-sim.mp4",
      "/assets/compiler/opcode-sweep-fpga.mp4",
    ];
    for (const path of [...pages, ...assets]) {
      const { status, body } = await get(`http://127.0.0.1:${port}${path}`);
      assert.equal(status, 200, `${path} → ${status}`);
      assert.ok(body.length > 0, `${path} empty`);
    }
  } finally {
    server.kill("SIGTERM");
  }
});

test("shipped clips are real MP4s with posters, not leftover GIFs", () => {
  const gone = [
    "assets/pcb/alu-optimized.glb",
    "assets/pcb/immersion_black.gif",
  ];
  for (const f of gone) {
    assert.equal(existsSync(join(WEB, f)), false, `stale ${f} still in web/`);
  }
  hasFtyp("assets/pcb/hero.mp4", "hero.mp4");
  hasFtyp("assets/pcb/immersion_black.mp4", "immersion_black.mp4");
  hasFtyp("assets/compiler/opcode-sweep-sim.mp4", "opcode-sweep-sim.mp4");
  hasFtyp("assets/compiler/opcode-sweep-fpga.mp4", "opcode-sweep-fpga.mp4");
  hasFtyp("assets/compiler/fpga-terminal-program.mp4", "fpga-terminal-program.mp4");
  hasFtyp("assets/assembly/placing-and-soldering.mp4", "placing-and-soldering.mp4");
  hasFtyp("assets/assembly/soldering-led.mp4", "soldering-led.mp4");
  hasFtyp("assets/assembly/work-setup.mp4", "work-setup.mp4");
  const posters = [
    ["assets/pcb/hero.webp", "RIFF"],
    ["assets/pcb/immersion_black.webp", "RIFF"],
    ["assets/pcb/immersion_white_poster.webp", "RIFF"],
    ["assets/compiler/opcode-sweep-sim.webp", "RIFF"],
    ["assets/compiler/opcode-sweep-fpga.webp", "RIFF"],
    ["assets/compiler/fpga-terminal-program.webp", "RIFF"],
    ["assets/assembly/digikey-box.webp", "RIFF"],
    ["assets/assembly/half-soldered-plate.webp", "RIFF"],
    ["assets/og/tomato-board.webp", "RIFF"],
    ["assets/pcb/board-iso.webp", "RIFF"],
    ["assets/pcb/board-iso-light.webp", "RIFF"],
    ["assets/assembly/placing-and-soldering.webp", "RIFF"],
    ["assets/assembly/soldering-led.webp", "RIFF"],
    ["assets/assembly/work-setup.webp", "RIFF"],
    ["assets/assembly/board-test.webp", "RIFF"],
  ];
  for (const [f, head] of posters) {
    const n = magic(join(WEB, f), head, f);
    const buf = readFileSync(join(WEB, f));
    assert.equal(buf.subarray(8, 12).toString("latin1"), "WEBP", `${f}: not a WebP`);
    assert.ok(n > 1_000, `${f}: empty poster`);
    assert.ok(n < 2_000_000, `${f}: poster too fat`);
  }
  magic(join(WEB, "assets/mark.svg"), "<svg", "mark.svg");
  magic(join(WEB, "assets/mark-dark.svg"), "<svg", "mark-dark.svg");
  magic(join(WEB, "assets/dip-dark.svg"), "<svg", "dip-dark.svg");
  magic(join(WEB, "assets/slice-dark.svg"), "<svg", "slice-dark.svg");
});

test("every magazine page bootstraps Paper/Black before paint", () => {
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    const label = relWeb(file);
    if (label === "viewer.html") continue;
    assert.match(html, /tomato\.theme/, `${label}: FOUC theme script`);
    assert.match(html, /name=["']theme-color["']/, `${label}: theme-color`);
    assert.match(html, /property=["']og:image["']/, `${label}: og:image`);
    assert.match(html, /<span>tomato<\/span>/, `${label}: Tomato wordmark`);
    assert.doesNotMatch(html, /1 min(?:ute)?(?: and)? 14/, `${label}: stale sweep timing`);
  }
  const mast = readFileSync(join(WEB, "js/mast.js"), "utf8");
  assert.match(mast, /mark-dark\.svg/);
  assert.match(mast, /dip-dark\.svg/);
  assert.match(mast, /slice-dark\.svg/);
  assert.match(mast, /lead-spin/);
  assert.match(mast, /lead-night/);
  assert.match(mast, /setAttribute\("data-theme"/);
  assert.match(mast, /media-lightbox\.js/);
  assert.match(mast, /tomatoMediaLightbox/);
  const mediaLb = readFileSync(join(WEB, "js/media-lightbox.js"), "utf8");
  assert.match(mediaLb, /document\.addEventListener\("click"/);
  assert.match(mediaLb, /window\.tomatoMediaLightbox/);
  assert.match(mast, /wireExternalLinks/);
  assert.match(mast, /target = "_blank"/);
});

test("AND3 FPGA hit is boxed on the paper, playground, and demo log", () => {
  const needles = [
    "compiler-hit",
    "0x80",
    "AND3",
    "0x2e653abb",
    "0x7d0145cd",
    "0x1455f659",
    "0x08020012",
    "opcode-sweep-sim.mp4",
    "opcode-sweep-fpga.mp4",
  ];
  const pages = {
    "js/playground.js": readFileSync(join(WEB, "js/playground.js"), "utf8"),
    "journal/demo-ideas.html": readFileSync(join(WEB, "journal/demo-ideas.html"), "utf8"),
  };
  for (const [label, src] of Object.entries(pages)) {
    for (const n of needles) {
      assert.ok(src.includes(n), `${label} missing ${n}`);
    }
  }
  const css = readFileSync(join(WEB, "css/magazine.css"), "utf8");
  assert.match(css, /\.compiler-hit\s*\{/);
  assert.match(css, /\.two-up--sweeps\s*\{/);
  assert.match(css, /#opcode-compiler\s*\{/);
  assert.match(css, /html\[data-theme=dark\]/);
  assert.match(css, /prefers-color-scheme:\s*dark/);
  const opt = readFileSync(join(WEB, "scripts/optimize-pcb.mjs"), "utf8");
  assert.match(opt, /document\.transform\(/);
  assert.doesNotMatch(opt, /document\.transform\([\s\S]*\bpalette\s*\(/);
});

test("Vercel build is the web test suite on the web/ folder", () => {
  const vercel = JSON.parse(readFileSync(join(WEB, "../vercel.json"), "utf8"));
  assert.equal(vercel.outputDirectory, "web");
  assert.match(String(vercel.buildCommand), /npm test/);
  assert.ok(Array.isArray(vercel.headers) && vercel.headers.length >= 1);
  const boards = readdirSync(join(WEB, "boards")).filter((n) => n.endsWith(".html")).sort();
  assert.deepEqual(boards, [
    "01-alu.html",
    "02-shift.html",
    "03-memory.html",
    "04-register.html",
    "05-pc.html",
    "06-bus.html",
    "07-alu.html",
    "08-display.html",
  ]);
});

test("sitemap, robots, and canonical tags ship", () => {
  const sitemap = readFileSync(join(WEB, "sitemap.xml"), "utf8");
  assert.match(sitemap, /<loc>https:\/\/tomato\.tmarhguy\.com\/verification\.html<\/loc>/);
  assert.match(sitemap, /<loc>https:\/\/tomato\.tmarhguy\.com\/index\.html<\/loc>/);
  const robots = readFileSync(join(WEB, "robots.txt"), "utf8");
  assert.match(robots, /Sitemap:\s*https:\/\/tomato\.tmarhguy\.com\/sitemap\.xml/);
  const manifest = JSON.parse(readFileSync(join(WEB, "site.webmanifest"), "utf8"));
  assert.equal(manifest.short_name, "Tomato");
  assert.match(readFileSync(join(WEB, "humans.txt"), "utf8"), /Tyrone Marhguy/);
  assert.match(readFileSync(join(WEB, ".well-known/security.txt"), "utf8"), /github\.com\/tmarhguy\/tomato/);
  const verify = readFileSync(join(WEB, "verification.html"), "utf8");
  assert.match(verify, /<link(?=[^>]*rel="canonical")(?=[^>]*href="https:\/\/tomato\.tmarhguy\.com\/verification\.html")[^>]*>/);
  assert.match(verify, /PROPERTY_INVENTORY\.md/);
  assert.match(verify, /compiler-reels/);
});

test("pages ship rich SEO metadata block", () => {
  const index = readFileSync(join(WEB, "index.html"), "utf8");
  const verify = readFileSync(join(WEB, "verification.html"), "utf8");
  for (const html of [index, verify]) {
    assert.match(html, /<!-- tomato-seo -->/);
    assert.match(html, /<meta[^>]*name="keywords"/);
    assert.match(html, /<meta(?=[^>]*name="robots")(?=[^>]*content="index, follow)[^>]*>/);
    assert.match(html, /<link(?=[^>]*rel="manifest")(?=[^>]*href="[^"]*site\.webmanifest")[^>]*>/);
    assert.match(html, /application\/ld\+json/);
    assert.match(html, /og:locale/);
  }
  assert.match(index, /SymbiYosys/);
  assert.match(verify, /Verilator gauntlet/);
  assert.match(index, /"@type": "WebSite"/);
  assert.match(verify, /"@type": "TechArticle"/);
  const seo = JSON.parse(readFileSync(join(WEB, "data/seo.json"), "utf8"));
  assert.ok(Array.isArray(seo.globalKeywords) && seo.globalKeywords.length >= 10);
});

test("pages ship Vercel analytics + speed insights loaders", () => {
  const index = readFileSync(join(WEB, "index.html"), "utf8");
  const journal = readFileSync(join(WEB, "journal/welcome.html"), "utf8");
  const viewer = readFileSync(join(WEB, "viewer.html"), "utf8");
  for (const html of [index, journal, viewer]) {
    assert.match(html, /<!-- tomato-vercel -->/);
    assert.match(html, /vercel-analytics\.js/);
    assert.match(html, /vercel-speed-insights\.js/);
  }
  assert.match(index, /src="js\/vercel-analytics\.js"/);
  assert.match(journal, /src="\.\.\/js\/vercel-analytics\.js"/);
  const analytics = readFileSync(join(WEB, "js/vercel-analytics.js"), "utf8");
  const speed = readFileSync(join(WEB, "js/vercel-speed-insights.js"), "utf8");
  assert.match(analytics, /\/_vercel\/insights\/script\.js/);
  assert.match(speed, /\/_vercel\/speed-insights\/script\.js/);
});

test("subdir deploy simulation: journal page assets resolve via ../", () => {
  const sample = join(WEB, "journal/welcome.html");
  const html = readFileSync(sample, "utf8");
  assert.match(html, /\.\.\/css\/magazine\.css/);
  assert.match(html, /\.\.\/assets\/favicon\.svg/);
  assert.match(html, /\.\.\/index\.html/);
  for (const { value } of attrs(html, ["href", "src", "poster"])) {
    const target = resolveHref(sample, value);
    if (!target) continue;
    assert.ok(existsSync(target), `journal relative miss: ${value}`);
  }
});

function get(url) {
  return new Promise((resolveP, reject) => {
    http
      .get(url, (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () =>
          resolveP({ status: res.statusCode, body: Buffer.concat(chunks) })
        );
      })
      .on("error", reject);
  });
}

 test("shared static navigation includes Gallery and an accessible mobile menu", () => {
 for (const file of htmlFiles()) {
 const html = readFileSync(file,"utf8"); if (relWeb(file)==="viewer.html") continue;
 assert.match(html, /class="site-menu"/);
 assert.match(html, /aria-label="All pages"/);
 assert.match(html, /css\/navigation\.css/);
 assert.equal((html.match(/class="site-menu"/g)||[]).length,1);
 assert.match(html, /gallery\.html/);
 assert.match(html, />FAQ</);
 }
 const home = readFileSync(join(WEB, "index.html"), "utf8");
 assert.match(home, /class="front-links"[\s\S]*?href="faq\.html">FAQ</);
 assert.match(home, /id="questions"/);
 assert.match(home, /class="faq-home"/);
 assert.equal((home.match(/<div class="faq-home">[\s\S]*?<\/div>/)[0].match(/<details>/g) || []).length, 6);
 });
 test("homepage has six comparison diagrams and both compiler recordings", () => {
 const html=readFileSync(join(WEB,"index.html"),"utf8");
 assert.equal((html.match(/class="evolution-chart"/g)||[]).length,6);
 assert.match(html,/7.3× smaller/);
 assert.match(html,/opcode-sweep-sim\.mp4/);
 assert.match(html,/opcode-sweep-fpga\.mp4/);
 assert.doesNotMatch(html,/2× PREVIEW/);
 });
