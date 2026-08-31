#!/usr/bin/env node
/**
 * Inject Vercel Analytics + Speed Insights on every HTML page.
 * Run: node scripts/apply-vercel.mjs
 */
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");

const MARK_START = "<!-- tomato-vercel -->";
const MARK_END = "<!-- /tomato-vercel -->";

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name.startsWith(".")) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith(".html")) out.push(p);
  }
  return out;
}

function jsPrefix(rel) {
  const depth = rel.split("/").length - 1;
  return depth ? "../".repeat(depth) : "";
}

function buildBlock(rel) {
  const prefix = jsPrefix(rel);
  return [
    MARK_START,
    `  <script src="${prefix}js/vercel-analytics.js" defer></script>`,
    `  <script src="${prefix}js/vercel-speed-insights.js" defer></script>`,
    MARK_END,
  ].join("\n");
}

function stripOld(html) {
  const block = new RegExp(`\\s*${MARK_START}[\\s\\S]*?${MARK_END}\\s*`, "g");
  return html.replace(block, "\n");
}

let count = 0;
for (const file of walk(web)) {
  const rel = relative(web, file).split("\\").join("/");
  if (rel === "broadsheet.html") continue;
  let html = readFileSync(file, "utf8");
  if (!html.includes("</body>")) continue;
  html = stripOld(html);
  const block = buildBlock(rel);
  html = html.replace("</body>", `${block}\n</body>`);
  writeFileSync(file, html);
  count++;
  console.log("vercel", rel);
}
console.log(`applied Vercel stats to ${count} pages`);
