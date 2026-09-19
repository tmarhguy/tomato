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
    .slice(0, 64)
    .join(", ");
}

function stripTags(s) {
  return String(s)
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#?\w+;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

const MONTHS = {
  jan: "01",
  january: "01",
  feb: "02",
  february: "02",
  mar: "03",
  march: "03",
  apr: "04",
  april: "04",
  may: "05",
  jun: "06",
  june: "06",
  jul: "07",
  july: "07",
  aug: "08",
  august: "08",
  sep: "09",
  sept: "09",
  september: "09",
  oct: "10",
  october: "10",
  nov: "11",
  november: "11",
  dec: "12",
  december: "12",
};

function isoDate(raw) {
  if (!raw) return "";
  const t = String(raw).replace(/\s*·\s*.*$/, "").trim();
  let m = t.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = t.match(/^(\d{1,2})\s+([A-Za-z]+)\.?\s+(\d{4})$/);
  if (m && MONTHS[m[2].toLowerCase()]) {
    return `${m[3]}-${MONTHS[m[2].toLowerCase()]}-${m[1].padStart(2, "0")}`;
  }
  m = t.match(/^([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})$/);
  if (m && MONTHS[m[1].toLowerCase()]) {
    return `${m[3]}-${MONTHS[m[1].toLowerCase()]}-${m[2].padStart(2, "0")}`;
  }
  return "";
}

function dateFor(rel, html) {
  const fromTime = pick(/<time[^>]*datetime="(\d{4}-\d{2}-\d{2})/i, html);
  if (fromTime) return fromTime;
  const byline = pick(/<p class="byline">([^<]+)</, html);
  const fromByline = isoDate(byline);
  if (fromByline) return fromByline;
  if (rel === "index.html") return "2026-09-23";
  return "";
}

const KNOWS_ABOUT = [
  "chip design",
  "computer architecture",
  "ASIC",
  "RTL",
  "FPGA",
  "discrete 74xx logic",
  "formal verification",
  "custom ISA",
  "open-source EDA",
];

function personNode() {
  return {
    "@type": "Person",
    "@id": `${SITE}/about.html#person`,
    name: cfg.author,
    url: `${SITE}/about.html`,
    description:
      "Ghanaian computer engineering student at the University of Pennsylvania (Penn / UPenn), Class of 2028, Penn Engineering. Designer of Tomato, a 32-bit CPU: FPGA and discrete 74xx today, with a long-term ASIC goal.",
    jobTitle: "Computer Engineering student, Class of 2028",
    nationality: { "@type": "Country", name: "Ghana" },
    homeLocation: [
      {
        "@type": "Place",
        name: "Ghana",
        address: { "@type": "PostalAddress", addressCountry: "GH" },
      },
      {
        "@type": "Place",
        name: "Philadelphia",
        address: {
          "@type": "PostalAddress",
          addressLocality: "Philadelphia",
          addressRegion: "PA",
          addressCountry: "US",
        },
      },
    ],
    alumniOf: [
      {
        "@type": "CollegeOrUniversity",
        "@id": "https://www.upenn.edu/#org",
        name: "University of Pennsylvania",
        alternateName: ["Penn", "UPenn", "Penn Engineering"],
        url: "https://www.upenn.edu",
        department: "School of Engineering and Applied Science",
      },
      { "@type": "EducationalOrganization", name: "Achimota School" },
    ],
    affiliation: {
      "@type": "CollegeOrUniversity",
      "@id": "https://www.upenn.edu/#org",
      name: "University of Pennsylvania",
      alternateName: ["Penn", "UPenn", "Penn Engineering"],
      url: "https://www.upenn.edu",
      department: "School of Engineering and Applied Science",
    },
    memberOf: {
      "@type": "Organization",
      name: "University of Pennsylvania Class of 2028",
      url: "https://www.upenn.edu",
    },
    additionalProperty: [
      { "@type": "PropertyValue", name: "classYear", value: "2028" },
      { "@type": "PropertyValue", name: "school", value: "University of Pennsylvania" },
      { "@type": "PropertyValue", name: "college", value: "Penn Engineering" },
    ],
    knowsAbout: KNOWS_ABOUT.map((name) => ({ "@type": "Thing", name })),
    sameAs: [
      "https://github.com/tmarhguy",
      "https://github.com/tmarhguy/tomato",
      "https://tmarhguy.com",
      "https://www.linkedin.com/in/tmarhguy",
      "https://twitter.com/marhguy_tyrone",
      "https://www.instagram.com/tmarhguy",
      "https://en.wikipedia.org/wiki/Tyrone_Marhguy",
    ],
  };
}

function orgNode() {
  return {
    "@type": "Organization",
    "@id": `${SITE}/#organization`,
    name: "Tomato",
    url: `${SITE}/`,
    logo: `${SITE}/assets/favicon.svg`,
    description:
      "Independent 32-bit computer project by Tyrone Marhguy: Dual-LUT CPU, Tomato OS, FPGA, and discrete 74xx. ASIC is a long-term goal, not a current tapeout.",
    founder: { "@id": `${SITE}/about.html#person` },
    keywords: (cfg.projectKeywords || []).join(", "),
    sameAs: ["https://github.com/tmarhguy/tomato"],
  };
}

function projectNode() {
  return {
    "@type": "ResearchProject",
    "@id": `${SITE}/#project`,
    name: "Tomato",
    url: `${SITE}/`,
    description:
      "A functional 32-bit computer designed in a dorm: Dual-LUT ALU, custom ISA, Tomato OS on FPGA, discrete 74xx ALU in copper. The long-term goal is an ASIC implementation. Built by Tyrone Marhguy, a Ghanaian engineer at the University of Pennsylvania, Penn Engineering Class of 2028, for chip designers, RTL engineers, and students who want an inspectable machine.",
    founder: { "@id": `${SITE}/about.html#person` },
    keywords: (cfg.projectKeywords || []).join(", "),
    about: KNOWS_ABOUT.map((name) => ({ "@type": "Thing", name })),
    audience: {
      "@type": "Audience",
      audienceType:
        "chip designers, computer engineers, RTL and verification engineers, University of Pennsylvania students, students in Ghana and elsewhere",
    },
  };
}

function sourceCodeNode() {
  return {
    "@type": "SoftwareSourceCode",
    "@id": "https://github.com/tmarhguy/tomato#code",
    name: "Tomato RTL and software",
    codeRepository: "https://github.com/tmarhguy/tomato",
    url: `${SITE}/source.html`,
    programmingLanguage: ["SystemVerilog", "Verilog", "Assembly", "JavaScript"],
    runtimePlatform: "Xilinx Artix-7 Nexys A7 FPGA",
    author: { "@id": `${SITE}/about.html#person` },
    keywords: "RTL, FPGA, ASIC flow, LibreLane, Dual-LUT, Tomato ISA",
  };
}

function breadcrumbFor(rel, url, title) {
  if (rel === "index.html") return null;
  const short = title.replace(/\s*—\s*(The Tomato|Tomato)\s*$/i, "").trim();
  const items = [{ "@type": "ListItem", position: 1, name: "Home", item: `${SITE}/` }];
  if (rel.startsWith("journal/") && rel !== "journal.html") {
    items.push({
      "@type": "ListItem",
      position: 2,
      name: "Journal",
      item: `${SITE}/journal.html`,
    });
    items.push({ "@type": "ListItem", position: 3, name: short, item: url });
  } else if (rel.startsWith("boards/") && rel !== "boards.html") {
    items.push({
      "@type": "ListItem",
      position: 2,
      name: "Boards",
      item: `${SITE}/boards.html`,
    });
    items.push({ "@type": "ListItem", position: 3, name: short, item: url });
  } else {
    items.push({ "@type": "ListItem", position: 2, name: short, item: url });
  }
  return { "@type": "BreadcrumbList", itemListElement: items };
}

function faqItems(html) {
  const items = [];
  const re =
    /<details[^>]*>\s*<summary>([\s\S]*?)<\/summary>\s*<div class="faq-answer">([\s\S]*?)<\/div>\s*<\/details>/gi;
  let m;
  while ((m = re.exec(html))) {
    const name = stripTags(m[1]);
    const text = stripTags(m[2]);
    if (name && text) {
      items.push({
        "@type": "Question",
        name,
        acceptedAnswer: { "@type": "Answer", text },
      });
    }
  }
  return items;
}

function jsonLdFor(rel, url, title, description, override, html, keywords) {
  const graph = [];
  const page = {
    "@type": "WebPage",
    "@id": `${url}#webpage`,
    url,
    name: title,
    description,
    isPartOf: { "@id": `${SITE}/#website` },
    inLanguage: "en-US",
    keywords,
    creator: { "@id": `${SITE}/about.html#person` },
    audience: {
      "@type": "Audience",
      audienceType:
        "chip designers, computer engineers, RTL and verification engineers, University of Pennsylvania students, students in Ghana and elsewhere",
    },
  };
  const published = dateFor(rel, html);
  if (published) {
    page.dateModified = published;
    if (rel.startsWith("journal/")) page.datePublished = published;
  }

  if (rel === "index.html") {
    graph.push({
      "@type": "WebSite",
      "@id": `${SITE}/#website`,
      url: `${SITE}/`,
      name: override?.jsonLd?.name || cfg.siteName,
      alternateName: override?.jsonLd?.alternateName,
      description: override?.jsonLd?.description || description,
      publisher: { "@id": `${SITE}/about.html#person` },
    });
    graph.push(orgNode());
    graph.push(personNode());
    graph.push(projectNode());
    graph.push(sourceCodeNode());
    graph.push({
      "@type": "SoftwareApplication",
      "@id": `${SITE}/os.html#software`,
      name: "Tomato OS",
      applicationCategory: "OperatingSystem",
      operatingSystem: "Tomato",
      url: `${SITE}/os.html`,
      description:
        "Assembly-written operating system for the Tomato 32-bit computer. Runs on FPGA and in the browser emulator.",
      author: { "@id": `${SITE}/about.html#person` },
    });
    if (/tomato-demo-os\.mp4/.test(html)) {
      graph.push({
        "@type": "VideoObject",
        name: "Tomato OS on FPGA",
        description:
          "Hardware recording of Tomato OS on a Nexys A7 Artix-7 FPGA, HDMI output.",
        thumbnailUrl: `${SITE}/assets/os/tomato-demo-os-poster.jpg`,
        contentUrl: `${SITE}/assets/os/tomato-demo-os.mp4`,
        uploadDate: "2026-08-01",
      });
    }
    page.about = {
      "@type": "Thing",
      name: "Tomato homebrew 32-bit CPU",
      description:
        override?.jsonLd?.description ||
        "A functional 32-bit computer built from scratch in a dorm — Dual-LUT ALU on FPGA and 74xx copper, Tomato OS, formal verification, and hardware opcode compiler.",
    };
  }

  if (rel === "about.html" || rel === "contact.html") {
    graph.push(personNode());
    graph.push(projectNode());
  }

  if (rel === "verification.html" && override?.jsonLd) {
    page["@type"] = "TechArticle";
    page.headline = title.replace(/\s*—\s*(The Tomato|Tomato)\s*$/i, "");
    page.author = { "@id": `${SITE}/about.html#person` };
    page.about = (override.jsonLd.about || []).map((name) => ({ "@type": "Thing", name }));
  }

  if (rel.startsWith("journal/") && rel !== "journal.html") {
    page["@type"] = "Article";
    page.headline = title.replace(/\s*—\s*(The Tomato|Tomato)\s*$/i, "");
    page.author = { "@id": `${SITE}/about.html#person` };
  }

  if (rel === "faq.html") {
    const items = faqItems(html);
    if (items.length) {
      graph.push({
        "@type": "FAQPage",
        "@id": `${url}#faq`,
        url,
        name: title,
        mainEntity: items,
      });
    }
  }

  const crumbs = breadcrumbFor(rel, url, title);
  if (crumbs) graph.push(crumbs);
  graph.push(page);
  return JSON.stringify({ "@context": "https://schema.org", "@graph": graph }, null, 2).replace(
    /</g,
    "\\u003c",
  );
}

function buildBlock(rel, html) {
  const override = cfg.pages[rel] || {};
  const title =
    override.title ||
    pick(/<title>([^<]+)<\/title>/i, html) ||
    cfg.siteName;
  let description = override.description || pick(/<meta name="description"\s+content="([^"]+)"/i, html);
  if (!description) description = cfg.siteName;
  const url = rel === "index.html" ? `${SITE}/` : `${SITE}/${rel}`;
  const image =
    override.image ||
    pick(/<meta property="og:image"\s+content="([^"]+)"/i, html) ||
    cfg.defaultImage;
  const keywords = keywordsFor(rel, title, description, override);
  const type = rel.startsWith("journal/") && rel !== "journal.html" ? "article" : "website";
  const imageAlt = override.imageAlt || "The Tomato 32-bit CPU";
  const published = dateFor(rel, html);

  const lines = [
    MARK_START,
    `  <meta name="description" content="${esc(description)}" />`,
    `  <meta name="keywords" content="${esc(keywords)}" />`,
    `  <meta name="dcterms.subject" content="chip design, 32-bit CPU, ASIC, RTL, FPGA, Ghana, University of Pennsylvania, Penn Engineering, Class of 2028, computer architecture" />`,
    `  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1" />`,
    `  <meta name="author" content="${esc(cfg.author)}" />`,
    `  <meta name="application-name" content="${esc(cfg.siteName)}" />`,
    `  <link rel="manifest" href="${assetPrefix(rel)}site.webmanifest" />`,
    `  <link rel="author" type="text/plain" href="${assetPrefix(rel)}humans.txt" />`,
    `  <link rel="alternate" type="text/plain" title="LLM index" href="${assetPrefix(rel)}llms.txt" />`,
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
  ];
  if (published) {
    lines.push(`  <meta property="og:updated_time" content="${esc(published)}" />`);
    if (type === "article") {
      lines.push(`  <meta property="article:published_time" content="${esc(published)}" />`);
      lines.push(`  <meta property="article:modified_time" content="${esc(published)}" />`);
    }
  }
  lines.push(
    `  <meta name="twitter:card" content="summary_large_image" />`,
    `  <meta name="twitter:site" content="${esc(cfg.twitter)}" />`,
    `  <meta name="twitter:creator" content="${esc(cfg.twitter)}" />`,
    `  <meta name="twitter:title" content="${esc(title)}" />`,
    `  <meta name="twitter:description" content="${esc(description)}" />`,
    `  <meta name="twitter:image" content="${esc(image)}" />`,
    `  <meta name="twitter:image:alt" content="${esc(imageAlt)}" />`,
    `  <script type="application/ld+json">${jsonLdFor(rel, url, title, description, override, html, keywords)}</script>`,
    `  ${MARK_END}`,
  );
  return lines.join("\n");
}

function stripOldSeo(html) {
  let out = html;
  const block = new RegExp(`\\s*${MARK_START}[\\s\\S]*?${MARK_END}\\s*`, "g");
  out = out.replace(block, "\n");
  const tags = [
    /<meta name="description"[^>]*>\s*/gi,
    /<meta name="keywords"[^>]*>\s*/gi,
    /<meta name="dcterms.subject"[^>]*>\s*/gi,
    /<meta name="robots"[^>]*>\s*/gi,
    /<meta name="application-name"[^>]*>\s*/gi,
    /<meta property="og:[^"]+"[^>]*>\s*/gi,
    /<meta name="twitter:[^"]+"[^>]*>\s*/gi,
    /<link rel="canonical"[^>]*>\s*/gi,
    /<link rel="manifest"[^>]*>\s*/gi,
    /<link rel="author"[^>]*>\s*/gi,
    /<link rel="alternate"[^>]*>\s*/gi,
    /<meta name="author"[^>]*>\s*/gi,
    /<meta property="article:[^"]+"[^>]*>\s*/gi,
    /<script type="application\/ld\+json">[\s\S]*?<\/script>\s*/gi,
  ];
  for (const re of tags) out = out.replace(re, "");
  return out;
}

let count = 0;
for (const file of walk(web)) {
  const rel = relative(web, file).split("\\").join("/");
  if (rel === "broadsheet.html" || rel === "404.html") continue;
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
