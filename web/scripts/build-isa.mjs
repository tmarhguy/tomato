#!/usr/bin/env node
/**
 * Build Tomato ISA web data from docs/isa/tomato.v1.csv (single authority).
 * Usage: node scripts/build-isa.mjs
 */
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const web = join(root, "web");
const csvPath = join(root, "docs/isa/tomato.v1.csv");
const outDir = join(web, "data/isa");
const jsonPath = join(outDir, "tomato.v1.json");
const htmlPath = join(web, "isa.html");

function parseCsv(text) {
  const lines = text.split(/\r?\n/).filter((ln) => ln.trim() && !ln.trim().startsWith("#"));
  if (!lines.length) throw new Error("empty CSV");
  const headers = splitCsvLine(lines[0]);
  return lines.slice(1).map((line) => {
    const cells = splitCsvLine(line);
    const row = {};
    headers.forEach((h, i) => {
      row[h] = cells[i] ?? "";
    });
    return row;
  });
}

function splitCsvLine(line) {
  const out = [];
  let cur = "";
  let q = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (q) {
      if (ch === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (ch === '"') q = false;
      else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ",") {
      out.push(cur);
      cur = "";
    } else cur += ch;
  }
  out.push(cur);
  return out;
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const rows = parseCsv(readFileSync(csvPath, "utf8"));
if (rows.length !== 512) {
  console.warn(`expected 512 ROM rows, got ${rows.length}`);
}

const burns = rows.filter((r) => r.status === "burn");
const nops = rows.filter((r) => r.status === "nop");

const payload = {
  source: "docs/isa/tomato.v1.csv",
  generated: new Date().toISOString().slice(0, 10),
  romSlots: rows.length,
  burned: burns.length,
  open: nops.length,
  rows: rows.map((r) => ({
    addr: r.rom_addr,
    index: parseInt(r.rom_addr, 16),
    mnemonic: r.mnemonic,
    group: r.group,
    region: r.region,
    status: r.status,
    operation: r.operation,
    encoding: r.encoding,
    semantic: r.semantic_op,
    why: r.why,
    notes: r.notes,
  })),
};

mkdirSync(outDir, { recursive: true });
writeFileSync(jsonPath, `${JSON.stringify(payload, null, 2)}\n`);
copyFileSync(csvPath, join(outDir, "tomato.v1.csv"));

const groupOrder = [];
const byGroup = new Map();
for (const r of burns) {
  const g = r.group || r.region || "other";
  if (!byGroup.has(g)) {
    byGroup.set(g, []);
    groupOrder.push(g);
  }
  byGroup.get(g).push(r);
}

const groupLabels = {
  system: "System",
  "alu-reg": "ALU · register",
  muldiv: "Multiply / divide",
  "alu-imm": "ALU · immediate",
  shift: "Shift / rotate",
  mem: "Memory",
  branch: "Branch",
  jump: "Jump",
  stack: "Stack / I/O",
};

let catalog = `<header class="isa-sheet-head" id="catalog"><div><p class="kicker">02 / BURNED</p><h2 id="catalog-title">The ${burns.length} opcodes in use.</h2></div><p>Every burn below is a real ROM row from <span class="mono">tomato.v1.csv</span>. Spacing stays even so new burns can land without redesigning the sheet.</p></header>`;
for (const g of groupOrder) {
  const list = byGroup.get(g);
  catalog += `<section class="isa-group" id="group-${esc(g)}" aria-labelledby="g-${esc(g)}">`;
  catalog += `<header class="isa-group-head"><h3 id="g-${esc(g)}">${esc(groupLabels[g] || g)}</h3><span>${list.length}</span></header>`;
  catalog += `<ol class="isa-ops">`;
  for (const r of list) {
    const id = `op-${r.rom_addr.replace(/^0x/i, "").toLowerCase()}`;
    catalog += `<li class="isa-op" id="${esc(id)}">`;
    catalog += `<code class="isa-op-addr">${esc(r.rom_addr)}</code>`;
    catalog += `<strong class="isa-op-name">${esc(r.mnemonic)}</strong>`;
    catalog += `<span class="isa-op-enc">${esc(r.encoding || "—")}</span>`;
    catalog += `<p class="isa-op-body">${esc(r.operation || r.semantic_op || "")}</p>`;
    if (r.why) catalog += `<p class="isa-op-why">${esc(r.why)}</p>`;
    catalog += `</li>`;
  }
  catalog += `</ol></section>`;
}

let mapCells = "";
for (const r of rows) {
  const burned = r.status === "burn";
  const rawOp = burned ? r.operation || r.semantic_op || "burn" : "open slot · nop";
  const why = burned && r.why ? String(r.why).trim() : "";
  // Prefer a readable op line: use CSV operation; if it's just the mnemonic, fold in why.
  let op = rawOp;
  if (burned && why && String(rawOp).toUpperCase() === String(r.mnemonic).toUpperCase()) {
    op = `${rawOp} · ${why}`;
  } else if (burned && why && !String(rawOp).toLowerCase().includes(why.toLowerCase())) {
    op = `${rawOp} · ${why}`;
  }
  const name = burned ? r.mnemonic : "—";
  const cls = burned ? "is-burn" : "is-open";
  const href = burned ? `#op-${r.rom_addr.replace(/^0x/i, "").toLowerCase()}` : "";
  const label = burned ? esc(r.mnemonic) : "";
  const attrs = `class="isa-cell ${cls}" type="button" data-addr="${esc(r.rom_addr)}" data-name="${esc(name)}" data-op="${esc(op)}"${href ? ` data-href="${esc(href)}"` : ""} aria-label="${esc(`${r.rom_addr} · ${name} — ${op}`)}"`;
  mapCells += `<button ${attrs}><span>${label}</span></button>`;
}

const block = `<!-- isa-generated:start -->
<p class="isa-count" id="isa-count"><strong>${burns.length}</strong> burned · <strong>${nops.length}</strong> open · <strong>${rows.length}</strong> ROM rows</p>
<div class="isa-rom" id="isa-rom" role="group" aria-label="${rows.length}-row instruction ROM map. Filled cells are burned opcodes; empty cells are open nop slots.">${mapCells}</div>
<div class="isa-peek" id="isa-peek" aria-live="polite">
<code class="isa-peek-addr">—</code>
<strong class="isa-peek-name">Hover or tap a cell</strong>
<span class="isa-peek-op">Hex address and operation appear here</span>
<a class="isa-peek-link" hidden href="#">Open in catalog</a>
</div>
<p class="isa-rom-legend"><span class="isa-leg-burn">Burned</span><span class="isa-leg-open">Open · grows toward ${rows.length}</span></p>
<div class="isa-catalog" id="catalog-list">${catalog}</div>
<!-- isa-generated:end -->`;

let html = readFileSync(htmlPath, "utf8");
if (!html.includes("<!-- isa-generated:start -->")) {
  throw new Error("isa.html missing <!-- isa-generated:start --> marker");
}
html = html.replace(/<!-- isa-generated:start -->[\s\S]*?<!-- isa-generated:end -->/, block);

// Keep the static hero/stats counts in sync with the CSV.
html = html.replace(
  /(<p class="deck">Nine opcode bits index a 512-row control ROM\. <strong>)(\d+)(<\/strong>)/,
  `$1${burns.length}$3`
);
writeFileSync(htmlPath, html);

console.log(`ISA build: ${burns.length} burned / ${rows.length} slots → ${jsonPath}`);
