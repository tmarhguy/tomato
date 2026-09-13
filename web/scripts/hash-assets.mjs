#!/usr/bin/env node
/**
 * Content-hash every local CSS/JS reference (`?v=<sha256-8>`) across the
 * static site, so browsers and CDNs can cache assets immutably while HTML
 * (served must-revalidate) always points at the current bytes.
 *
 * Why this instead of hand-bumped `?v=304` numbers:
 *   - the URL changes IFF the bytes change -> `immutable` is always safe
 *   - repeat visits revalidate only tiny HTML (304, no body) -> minimal data
 *   - nobody has to remember to bump anything -> stale-asset bugs can't recur
 *   - unchanged files keep byte-identical output -> clean diffs, shared cache
 *
 * Usage:  npm run hash:assets     (also runs in the Vercel build, pre-test)
 * Idempotent: run it twice, the second run changes nothing.
 */
import { readdirSync, readFileSync, writeFileSync, statSync } from "node:fs";
import { join, dirname, resolve, relative, sep } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

export const WEB = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const SKIP_DIRS = new Set(["node_modules", ".git"]);
const HASH_LEN = 8;

export function walk(dir, exts, out = []) {
  for (const name of readdirSync(dir)) {
    if (SKIP_DIRS.has(name)) continue;
    const abs = join(dir, name);
    const st = statSync(abs);
    if (st.isDirectory()) walk(abs, exts, out);
    else if (exts.some((e) => name.endsWith(e))) out.push(abs);
  }
  return out;
}

export function contentHash(abs) {
  return createHash("sha256").update(readFileSync(abs)).digest("hex").slice(0, HASH_LEN);
}

export function isSkippableUrl(url) {
  return /^(https?:)?\/\/|^data:|^mailto:|^tel:|^#/i.test(url);
}

function splitUrl(url) {
  let hash = "";
  let rest = url;
  const hi = rest.indexOf("#");
  if (hi >= 0) {
    hash = rest.slice(hi);
    rest = rest.slice(0, hi);
  }
  let query = "";
  let path = rest;
  const qi = rest.indexOf("?");
  if (qi >= 0) {
    path = rest.slice(0, qi);
    query = rest.slice(qi + 1);
  }
  return { path, query, hash };
}

function withVersion(query, v) {
  const parts = query ? query.split("&") : [];
  let seen = false;
  const next = parts.map((p) => {
    if (p === "v" || p.startsWith("v=")) {
      seen = true;
      return `v=${v}`;
    }
    return p;
  });
  if (!seen) next.push(`v=${v}`);
  return next.join("&");
}

/** Resolve a page-relative asset reference to an absolute file, or null. */
export function resolveAsset(ref, fromDir) {
  if (!ref || isSkippableUrl(ref)) return null;
  const { path } = splitUrl(ref);
  if (!/\.(css|js)$/i.test(path)) return null;
  let abs;
  try {
    abs = ref.startsWith("/")
      ? join(WEB, decodeURIComponent(path))
      : resolve(fromDir, decodeURIComponent(path));
  } catch {
    return null;
  }
  const norm = resolve(abs);
  if (norm !== WEB && !norm.startsWith(WEB + sep)) return null;
  if (norm.split(sep).includes("node_modules")) return null;
  try {
    if (!statSync(norm).isFile()) return null;
  } catch {
    return null;
  }
  return norm;
}

function stampUrl(url, version) {
  const { path, query, hash } = splitUrl(url);
  return `${path}?${withVersion(query, version)}${hash}`;
}

/** Rewrite href=/src= CSS/JS references in an HTML document. Pure. */
export function rewriteHtmlRefs(html, dir) {
  return html.replace(/((?:href|src)=")([^"]+)(")/g, (m, pre, url, post) => {
    const target = resolveAsset(url, dir);
    if (!target) return m;
    return `${pre}${stampUrl(url, contentHash(target))}${post}`;
  });
}

/** Rewrite relative `./x.js` / `../x.js` imports in a served page module. Pure. */
export function rewriteJsRefs(src, dir) {
  return src.replace(/(['"])(\.\.?\/[^'"]+?\.m?js)(\?[^'"]*)?\1/g, (m, q, path, query) => {
    const target = resolveAsset(path + (query || ""), dir);
    if (!target) return m;
    return `${q}${stampUrl(path + (query || ""), contentHash(target))}${q}`;
  });
}

/**
 * Bring every reference up to date. Repeats to a fixpoint (capped) because
 * hashing one file (e.g. landing.js, which embeds bench's hash) changes the
 * bytes other files hash. With write:true, persists; otherwise dry-run.
 * Returns the web-relative paths that changed (or would change).
 */
export function scanAll({ write = false } = {}) {
  const files = [...walk(WEB, [".html"]), ...walk(join(WEB, "js"), [".js"])];
  const changed = [];
  for (let pass = 0; pass < 5; pass++) {
    let dirty = false;
    for (const abs of files) {
      const before = readFileSync(abs, "utf8");
      const after = abs.endsWith(".html")
        ? rewriteHtmlRefs(before, dirname(abs))
        : rewriteJsRefs(before, dirname(abs));
      if (after !== before) {
        dirty = true;
        if (write) writeFileSync(abs, after);
        if (!changed.includes(abs)) changed.push(abs);
      }
    }
    if (!dirty) break;
  }
  return changed.map((abs) => relative(WEB, abs)).sort();
}

const isMain = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const changed = scanAll({ write: true });
  for (const f of changed) console.log(`hash-assets: updated ${f}`);
  console.log(`hash-assets: ${changed.length} file(s) updated, the rest already current.`);
}
