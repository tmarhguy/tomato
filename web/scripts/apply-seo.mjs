#!/usr/bin/env node
/**
 * Inject rich SEO metadata (keywords, robots, og extras, JSON-LD) into every HTML page.
 * Run: node scripts/apply-seo.mjs
 */
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, "..");
const cfg = JSON.parse(readFileSync(join(web, "data/seo.json"), "utf8"));
const SITE = cfg.site.replace(/\/$/, "");

const MARK_START = "<!-- tomato-seo -->";
const MARK_END = "<!-- /tomato-seo -->";

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name.startsWith(".")) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith(".html")) out.push(p);
  }
  return out;
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;");
}

function pick(re, html, group = 1) {
  const m = html.match(re);
  return m ? m[group].trim() : "";
}

function uniq(arr) {
  const seen = new Set();
  return arr.filter((x) => {
    const k = x.toLowerCase();
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

function assetPrefix(rel) {
  const depth = rel.split("/").length - 1;
  return depth ? "../".repeat(depth) : "";
}

function keywordsFor(rel, title, description, override) {
  const stop = new Set([
    "the", "and", "for", "with", "from", "that", "this", "into", "onto", "each",
    "whose", "your", "you", "are", "was", "were", "have", "has", "had", "been",
    "also", "more", "than", "then", "here", "there", "when", "what", "where",
    "which", "while", "about", "after", "before", "under", "over", "their",
    "them", "they", "custom", "computer", "changes", "instruction", "building",
    "same", "machine", "runs", "rewires", "logic",
  ]);
  const base = [...cfg.globalKeywords];
  if (override?.keywords) base.push(...override.keywords);
  const cleanTitle = title.replace(/\s*—\s*(The Tomato|Tomato).*$/i, "").trim();
  const fromTitle = cleanTitle
    .split(/[\s·|,/–—]+/)
    .map((w) => w.replace(/^[^\w]+|[^\w+]+$/g, ""))
    .filter((w) => w.length > 2 && !stop.has(w.toLowerCase()));
  const fromDesc = description
    .toLowerCase()
    .replace(/[^\w\s+-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 4 && !stop.has(w))
    .slice(0, 8);
  if (rel.includes("journal/")) {
    base.push("Tomato journal", "design log", "engineering notebook");
  }
  if (rel.includes("boards/")) {
    base.push("Tomato PCB", "KiCad lot", "discrete ALU board");
  }
  return uniq([...base, ...fromTitle, ...fromDesc])
    .filter((w) => w.length > 2 && !/^[+—-]$/.test(w))
    .slice(0, 42)
    .join(", ");
}

function jsonLdFor(rel, url, title, description, override, html) {
  const graph = [];
  const page = {
    "@type": "WebPage",
    "@id": `${url}#webpage`,
    url,
    name: title,
    description,
    isPartOf: { "@id": `${SITE}/#website` },
    inLanguage: "en-US",
  };

  if (rel === "index.html" && override?.jsonLd) {
    graph.push({
      "@type": "WebSite",
      "@id": `${SITE}/#website`,
      url: `${SITE}/`,
      name: override.jsonLd.name || cfg.siteName,
      alternateName: override.jsonLd.alternateName,
      description: override.jsonLd.description || description,
      publisher: {
        "@type": "Person",
        name: cfg.author,
        url: "https://github.com/tmarhguy",
      },
    });
    page.about = {
      "@type": "Thing",
      name: "Tomato homebrew 32-bit CPU",
      description:
        override.jsonLd.description ||
        "A computer whose logic changes with each instruction — Dual-LUT ALU on FPGA and 74xx copper, Tomato OS, formal verification, and hardware opcode compiler.",
    };
  }

  if (rel === "verification.html" && override?.jsonLd) {
    page["@type"] = "TechArticle";
    page.headline = title.replace(/\s*—\s*The Tomato\s*$/i, "");
    page.author = { "@type": "Person", name: cfg.author };
    page.about = (override.jsonLd.about || []).map((name) => ({ "@type": "Thing", name }));
  }

  if (rel.startsWith("journal/") && rel !== "journal.html") {
    page["@type"] = "Article";
    page.headline = title.replace(/\s*—\s*The Tomato\s*$/i, "");
    page.author = { "@type": "Person", name: cfg.author };
    const date = pick(/<p class="byline">([^<]+)</, html);
    if (date) page.datePublished = date.replace(/\s*·\s*from the log\s*$/i, "").trim();
  }

  graph.push(page);
  const payload =
    graph.length === 1 && rel !== "index.html"
      ? { "@context": "https://schema.org", ...graph[0] }
      : { "@context": "https://schema.org", "@graph": graph };
  return JSON.stringify(payload, null, 2).replace(/</g, "\\u003c");
}

function buildBlock(rel, html) {
  const override = cfg.pages[rel] || {};
  const title =
    override.title ||
    pick(/<title>([^<]+)<\/title>/i, html) ||
    cfg.siteName;
  let description = override.description || pick(/<meta name="description"\s+content="([^"]+)"/i, html);
  if (!description) description = cfg.siteName;
  const url = `${SITE}/${rel === "index.html" ? "" : rel}`.replace(/\/$/, "") || SITE + "/";
  const image =
    override.image ||
    pick(/<meta property="og:image"\s+content="([^"]+)"/i, html) ||
    cfg.defaultImage;
  const keywords = keywordsFor(rel, title, description, override);
  const type = rel.startsWith("journal/") && rel !== "journal.html" ? "article" : "website";
  const imageAlt =
    override.imageAlt ||
    "The Tomato 32-bit CPU";

  const lines = [
    MARK_START,
    `  <meta name="description" content="${esc(description)}" />`,
    `  <meta name="keywords" content="${esc(keywords)}" />`,
    `  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1" />`,
    `  <meta name="author" content="${esc(cfg.author)}" />`,
    `  <meta name="application-name" content="${esc(cfg.siteName)}" />`,
    `  <link rel="manifest" href="${assetPrefix(rel)}site.webmanifest" />`,
    `  <link rel="author" type="text/plain" href="${assetPrefix(rel)}humans.txt" />`,
    `  <meta property="og:title" content="${esc(title)}" />`,
    `  <meta property="og:description" content="${esc(description)}" />`,
    `  <meta property="og:type" content="${type}" />`,
    `  <meta property="og:url" content="${esc(url)}" />`,
    `  <link rel="canonical" href="${esc(url)}" />`,
    `  <meta property="og:image" content="${esc(image)}" />`,
    `  <meta property="og:image:width" content="1200" />`,
    `  <meta property="og:image:height" content="630" />`,
    `  <meta property="og:image:alt" content="${esc(imageAlt)}" />`,
    `  <meta property="og:site_name" content="${esc(cfg.siteName)}" />`,
    `  <meta property="og:locale" content="en_US" />`,
    `  <meta name="twitter:card" content="summary_large_image" />`,
    `  <meta name="twitter:site" content="${esc(cfg.twitter)}" />`,
    `  <meta name="twitter:creator" content="${esc(cfg.twitter)}" />`,
    `  <meta name="twitter:title" content="${esc(title)}" />`,
    `  <meta name="twitter:description" content="${esc(description)}" />`,
    `  <meta name="twitter:image" content="${esc(image)}" />`,
    `  <meta name="twitter:image:alt" content="${esc(imageAlt)}" />`,
    `  <script type="application/ld+json">${jsonLdFor(rel, url, title, description, override, html)}</script>`,
    `  ${MARK_END}`,
  ];
  return lines.join("\n");
}

function stripOldSeo(html) {
  let out = html;
  const block = new RegExp(`\\s*${MARK_START}[\\s\\S]*?${MARK_END}\\s*`, "g");
  out = out.replace(block, "\n");
  const tags = [
    /<meta name="description"[^>]*>\s*/gi,
    /<meta name="keywords"[^>]*>\s*/gi,
    /<meta name="robots"[^>]*>\s*/gi,
    /<meta name="application-name"[^>]*>\s*/gi,
    /<meta property="og:[^"]+"[^>]*>\s*/gi,
    /<meta name="twitter:[^"]+"[^>]*>\s*/gi,
    /<link rel="canonical"[^>]*>\s*/gi,
    /<link rel="manifest"[^>]*>\s*/gi,
    /<link rel="author"[^>]*>\s*/gi,
    /<meta name="author"[^>]*>\s*/gi,
    /<script type="application\/ld\+json">[\s\S]*?<\/script>\s*/gi,
  ];
  for (const re of tags) out = out.replace(re, "");
  return out;
}

let count = 0;
for (const file of walk(web)) {
  const rel = relative(web, file).split("\\").join("/");
  if (rel === "broadsheet.html") continue;
  let html = readFileSync(file, "utf8");
  html = stripOldSeo(html);
  const override = cfg.pages[rel] || {};
  if (override.title) {
    if (/<title>[^<]*<\/title>/i.test(html)) {
      html = html.replace(/<title>[^<]*<\/title>/i, `<title>${esc(override.title)}</title>`);
    } else {
      html = html.replace(/<\/head>/i, `<title>${esc(override.title)}</title>\n</head>`);
    }
  }
  const block = buildBlock(rel, html);
  if (!html.includes("</head>")) continue;
  html = html.replace("</head>", `${block}\n</head>`);
  writeFileSync(file, html);
  count++;
  console.log("seo", rel);
}
console.log(`applied SEO to ${count} pages`);
