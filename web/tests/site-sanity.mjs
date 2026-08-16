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
  "assets/pcb/alu-optimized.glb",
  "assets/pcb/immersion_black.gif",
  "assets/pcb/immersion_white.gif",
  "boards.html",
  "architecture.html",
  "isa.html",
  "journal.html",
  "board.html",
  "source.html",
  "about.html",
];

const NAV = [
  "index.html",
  "architecture.html",
  "isa.html",
  "playground.html",
  "journal.html",
  "boards.html",
  "board.html",
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
    assert.match(html, viewer ? /viewer\.css/ : /magazine\.css/, `${label}: stylesheet`);
    assert.match(html, /favicon\.svg/, `${label}: favicon`);
  }
});

test("no root-absolute asset or page paths (breaks nested pages and local preview)", () => {
  const bad = [];
  for (const file of htmlFiles()) {
    const html = readFileSync(file, "utf8");
    for (const { name, value } of attrs(html, ["href", "src"])) {
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
    for (const { value } of attrs(html, ["href", "src"])) {
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
    assert.match(html, /mast-nav/, `${label}: mast-nav`);
    assert.match(html, /js\/mast\.js/, `${label}: hamburger script`);
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
  for (const page of ["index.html", "board.html"]) {
    const html = readFileSync(join(WEB, page), "utf8");
    assert.match(html, /type=["']importmap["']/, `${page}: importmap`);
    assert.match(html, /three@0\.169\.0/, `${page}: three CDN pin`);
    assert.match(html, /type=["']module["'][^>]+js\/bench\.js/, `${page}: bench module`);
    assert.match(html, /id=["']bench["']/, `${page}: #bench canvas`);
  }
});

test("source page loads forge.js", () => {
  const html = readFileSync(join(WEB, "source.html"), "utf8");
  assert.match(html, /js\/forge\.js/);
  assert.match(html, /id=["']forge["']/);
});

test("playground wires Dual-LUT emulator modules", () => {
  const html = readFileSync(join(WEB, "playground.html"), "utf8");
  assert.match(html, /type=["']module["'][^>]+js\/playground\.js/);
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
  assert.match(html, /id=["']viewer-canvas["']/);
  assert.match(html, /id=["']immerse["']/);
  const css = readFileSync(join(WEB, "css/viewer.css"), "utf8");
  assert.match(css, /#050505/);
  assert.match(css, /#8b1e1e|#c23a3a/);
  const js = readFileSync(join(WEB, "js/viewer.js"), "utf8");
  assert.match(js, /assets\/pcb\/alu\.glb/);
  assert.match(js, /mergeByMaterial/);
  assert.match(js, /OrbitControls/);
  assert.match(js, /RoomEnvironment/);
  for (const page of ["index.html", "board.html"]) {
    const src = readFileSync(join(WEB, page), "utf8");
    assert.match(src, /viewer\.html/, `${page}: Tour opens viewer`);
    assert.match(src, /class=["']bench-tour["']/, `${page}: Tour CTA on the board`);
  }
});

test("JS modules parse (syntax)", async () => {
  for (const file of ["js/mast.js", "js/bench.js", "js/forge.js", "js/arch-map.js", "js/alu.js", "js/playground.js", "js/viewer.js", "js/pcb-look.js"]) {
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
  const buf = readFileSync(join(WEB, "assets/pcb/alu-optimized.glb"));
  assert.equal(buf.subarray(0, 4).toString("ascii"), "glTF");
  assert.ok(buf.length > 1_000_000, "GLB unexpectedly tiny");
  const jsonLen = buf.readUInt32LE(12);
  const json = JSON.parse(buf.subarray(20, 20 + jsonLen).toString("utf8"));
  assert.ok(Array.isArray(json.materials) && json.materials.length > 0);
  assert.ok(json.asset?.extras?.generator?.includes?.("KiCad") || json.asset?.generator);
});

test("CSS has brand tokens", () => {
  const css = readFileSync(join(WEB, "css/magazine.css"), "utf8");
  assert.match(css, /--bg:/);
  assert.match(css, /--ink:/);
  assert.match(css, /\.pg-schematic/);
  assert.match(css, /\.pg-hero/);
  assert.match(css, /\.mast-nav/);
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
      ".png": "image/png", ".gif": "image/gif", ".glb": "model/gltf-binary", ".webp": "image/webp"
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
      "/js/bench.js",
      "/js/forge.js",
      "/assets/favicon.svg",
      "/assets/pcb/alu-optimized.glb",
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

test("subdir deploy simulation: journal page assets resolve via ../", () => {
  const sample = join(WEB, "journal/welcome.html");
  const html = readFileSync(sample, "utf8");
  assert.match(html, /\.\.\/css\/magazine\.css/);
  assert.match(html, /\.\.\/assets\/favicon\.svg/);
  assert.match(html, /\.\.\/index\.html/);
  for (const { value } of attrs(html, ["href", "src"])) {
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
