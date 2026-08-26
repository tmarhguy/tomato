/**
 * Dual-LUT playground — datapath-first layout for inbound 07_alu.
 */
import {
  PROGRAMS,
  PRESET_GROUPS,
  CSEL,
  FLAG_BITS,
  LUT_CATALOG,
  aluEval,
  cinFromCsel,
  hex,
  liveLutBits,
  lutInfo,
  lutLabel,
  lutShort,
  mask,
  pairTitle,
  matchProgram,
  parseIntWord,
  resolveConstraints,
  resolveTruth,
  sensitivity,
  truthTable,
} from "./alu.js";

const main = document.getElementById("pg-main");
const elControls = document.getElementById("pg-controls");
const elHero = document.getElementById("pg-hero");
const elStatus = document.getElementById("pg-status");
const elBench = document.getElementById("pg-bench");
const elDetail = document.getElementById("pg-detail");
const elPipe = document.getElementById("pg-pipe");
const elMap = document.getElementById("pg-map");
if (!main || !elControls || !elHero || !elStatus || !elBench || !elDetail) {
  throw new Error("playground shell missing");
}

const TAB_IDS = ["trace", "touch", "truth", "compiler"];
const PAGE_IDS = ["overview", "bench", "map", "wire", "bom", ...TAB_IDS];

const OPERAND_NAMES = { A: "Operand A", B: "Operand B", C: "Select C" };
const PLANE_NAMES = { lutA: "X plane", lutB: "Y plane" };

function humanSource(src) {
  if (src === "cin") return "Carry in";
  const m = /^(A|B|C|lutA|lutB)\[(\d+)\]$/.exec(src);
  if (!m) return src;
  const field = m[1];
  const bit = m[2];
  if (field === "lutA" || field === "lutB") return `${PLANE_NAMES[field]}, row ${bit}`;
  return `${OPERAND_NAMES[field]}, bit ${bit}`;
}

function humanBits(bits) {
  if (!bits.length) return "—";
  if (bits.length === 1) return `bit ${bits[0]}`;
  return `bits ${bits.join(", ")}`;
}

function cselLabel(id) {
  const row = CSEL[id & 7];
  if (!row) return "Unknown";
  const hints = {
    0: "Tie low",
    1: "Tie high",
    2: "Sign flag",
    3: "Zero flag",
    4: "Carry flag",
    5: "Greater flag",
    6: "Less flag",
    7: "Overflow flag",
  };
  return hints[row.id] || row.hint;
}

function fieldLabel(field) {
  if (OPERAND_NAMES[field]) return OPERAND_NAMES[field];
  if (PLANE_NAMES[field]) return PLANE_NAMES[field];
  if (field === "out") return "Result";
  return field;
}

const state = {
  width: 8,
  A: 0x12,
  B: 0x34,
  C: 0,
  lutA: 0xaa,
  lutB: 0xcc,
  csel: 0,
  flags: 0,
  focusBit: 7,
  expandedNibble: null,
  presetGroup: "arith",
  activeTab: null,
  showAllBits: false,
  showIdle: false,
  lastFlip: null,
};

let resolveResult = null;
let resolveError = "";

function cinNow() {
  return cinFromCsel(state.csel, state.flags);
}

function evalNow() {
  return aluEval({
    width: state.width,
    lutA: state.lutA,
    lutB: state.lutB,
    A: state.A,
    B: state.B,
    C: state.C,
    cin: cinNow(),
  });
}

function clampWord() {
  const m = mask(state.width);
  state.A &= m;
  state.B &= m;
  state.C &= m;
  const max = state.width - 1;
  if (state.focusBit < 0 || state.focusBit > max) state.focusBit = max;
  if (state.width !== 32) state.expandedNibble = null;
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function syncFocusForWidth() {
  state.focusBit = state.width === 1 ? 0 : state.width - 1;
}

function readQuery() {
  const q = new URLSearchParams(location.search);
  const w = Number(q.get("w"));
  if (w === 1 || w === 8 || w === 32) state.width = w;
  if (q.has("A")) state.A = parseIntWord(q.get("A"), state.width);
  if (q.has("B")) state.B = parseIntWord(q.get("B"), state.width);
  if (q.has("C")) state.C = parseIntWord(q.get("C"), state.width);
  if (q.has("x")) state.lutA = parseIntWord(q.get("x"), 8);
  if (q.has("y")) state.lutB = parseIntWord(q.get("y"), 8);
  if (q.has("cin")) state.csel = Number(q.get("cin")) === 1 ? 1 : 0;
  if (q.has("csel")) state.csel = Number(q.get("csel")) & 7;
  if (q.has("fb")) state.focusBit = Number(q.get("fb")) | 0;
  if (q.has("op")) {
    const named = PROGRAMS.find((p) => p.id === q.get("op"));
    if (named) applyProgram(named, false);
  }
  const h = (location.hash || "").replace(/^#/, "").toLowerCase();
  if (h === "bench") state.activeTab = null;
  else if (TAB_IDS.includes(h)) state.activeTab = h;
  else if (h && !h.includes("=")) {
    const named = PROGRAMS.find((p) => p.id === h);
    if (named) applyProgram(named, false);
  }
  clampWord();
}

function writeQuery() {
  const q = new URLSearchParams();
  q.set("w", String(state.width));
  q.set("A", (state.A >>> 0).toString(16));
  q.set("B", (state.B >>> 0).toString(16));
  q.set("C", (state.C >>> 0).toString(16));
  q.set("x", (state.lutA & 255).toString(16));
  q.set("y", (state.lutB & 255).toString(16));
  q.set("csel", String(state.csel));
  q.set("fb", String(state.focusBit));
  const hit = matchProgram(state.lutA, state.lutB, cinNow());
  if (hit) {
    q.set("op", hit.id);
    state.presetGroup = hit.group;
  }
  const hash = state.activeTab ? `#${state.activeTab}` : location.hash === "#bench" ? "#bench" : "";
  history.replaceState(null, "", `${location.pathname}?${q.toString()}${hash}`);
}

function applyProgram(p, resetOps) {
  state.lutA = p.lutA;
  state.lutB = p.lutB;
  state.csel = p.csel;
  state.presetGroup = p.group;
  if (resetOps) {
    if (state.width === 1) {
      state.A = 1;
      state.B = 1;
      state.C = 0;
    } else {
      state.A = 0x12;
      state.B = 0x34;
      state.C = 0;
    }
    syncFocusForWidth();
  }
}

function computeContext() {
  clampWord();
  const r = evalNow();
  const live = new Set(liveLutBits(r));
  const prog = matchProgram(r.lutA, r.lutB, r.cin);
  const sens = sensitivity({
    width: state.width,
    lutA: state.lutA,
    lutB: state.lutB,
    A: state.A,
    B: state.B,
    C: state.C,
    cin: r.cin,
  });
  const hitOut = new Set();
  const hitFlags = new Set();
  if (state.lastFlip) {
    const row = sens.rows.find((row) => row.source === state.lastFlip);
    if (row) {
      for (const b of row.outBits) hitOut.add(b);
      for (const f of FLAG_BITS) if ((row.flagXor >>> f.bit) & 1) hitFlags.add(f.bit);
    }
  }
  const focusRow = r.bits[state.focusBit];
  let hitLutA = null;
  let hitLutB = null;
  if (state.lastFlip) {
    const ma = /^lutA\[(\d+)\]$/.exec(state.lastFlip);
    if (ma) hitLutA = new Set([Number(ma[1])]);
    const mb = /^lutB\[(\d+)\]$/.exec(state.lastFlip);
    if (mb) hitLutB = new Set([Number(mb[1])]);
  }
  return {
    r,
    live,
    prog,
    xa: lutInfo(r.lutA),
    yb: lutInfo(r.lutB),
    sens,
    hitOut,
    hitFlags,
    hitLutA,
    hitLutB,
    focusRow,
    moved: sens.rows.filter((row) => row.moved),
    tt: truthTable(r.lutA, r.lutB, r.cin),
  };
}

function hexField(field, word, width) {
  const digits = Math.max(1, Math.ceil(width / 4));
  const val = (word >>> 0).toString(16).toUpperCase().padStart(digits, "0");
  return `<input class="pg-hex" data-field="${esc(field)}" value="${val}" spellcheck="false" autocomplete="off" aria-label="${esc(fieldLabel(field))} hex" />`;
}

function lampBtn(field, i, on, { readonly, live, hit, focus }) {
  const cls = [
    "pg-lamp",
    on ? "is-on" : "",
    live ? "is-live" : "",
    hit ? "is-hit" : "",
    focus ? "is-focus" : "",
    readonly ? "is-out" : "",
  ]
    .filter(Boolean)
    .join(" ");
  const title = `${fieldLabel(field)}, bit ${i}`;
  const inner = `<span class="pg-lamp-i">${i}</span><span class="pg-lamp-v">${on}</span>`;
  if (readonly) return `<span class="${cls}" title="${esc(title)}">${inner}</span>`;
  return `<button type="button" class="${cls}" data-act="bit" data-field="${esc(field)}" data-bit="${i}" aria-pressed="${on ? "true" : "false"}" title="${esc(title)}">${inner}</button>`;
}

function lamps(word, width, field, opts = {}) {
  const { readonly = false, hitBits = null, focusOnly = false } = opts;
  if (width === 32 && field !== "lutA" && field !== "lutB") {
    let html = `<div class="pg-nibbles" role="group" aria-label="${esc(fieldLabel(field))} nibbles">`;
    for (let n = 7; n >= 0; n--) {
      const lo = n * 4;
      const nibble = (word >>> lo) & 0xf;
      const expanded = state.expandedNibble === n;
      html += `<div class="pg-nibble${expanded ? " is-open" : ""}">`;
      html += `<button type="button" class="pg-nibble-head" data-act="nibble" data-field="${esc(field)}" data-nibble="${n}" aria-expanded="${expanded}">`;
      html += `<span class="pg-nibble-n">${lo + 3}–${lo}</span><span class="pg-nibble-v">${nibble.toString(16).toUpperCase()}</span></button>`;
      if (expanded) {
        html += `<div class="pg-lamps">`;
        for (let i = lo + 3; i >= lo; i--) {
          const on = (word >>> i) & 1;
          html += lampBtn(field, i, on, {
            readonly,
            hit: hitBits && hitBits.has(i),
            focus: state.focusBit === i,
          });
        }
        html += `</div>`;
      }
      html += `</div>`;
    }
    html += `</div>`;
    return html;
  }

  let html = `<div class="pg-lamps" role="group" aria-label="${esc(fieldLabel(field))} bits">`;
  for (let i = width - 1; i >= 0; i--) {
    const on = (word >>> i) & 1;
    if (focusOnly && readonly) {
      html += `<button type="button" class="pg-lamp${on ? " is-on" : ""}${hitBits && hitBits.has(i) ? " is-hit" : ""}${state.focusBit === i ? " is-focus" : ""}" data-act="focus" data-bit="${i}" title="${esc(fieldLabel("out"))}, bit ${i}"><span class="pg-lamp-i">${i}</span><span class="pg-lamp-v">${on}</span></button>`;
      continue;
    }
    html += lampBtn(field, i, on, {
      readonly,
      hit: hitBits && hitBits.has(i),
      focus: state.focusBit === i,
    });
  }
  html += `</div>`;
  return html;
}

function operandRow(field, word, width) {
  return `<div class="pg-op-col">
    <div class="pg-op-head"><span class="pg-op-name">${esc(fieldLabel(field))}</span>${hexField(field, word, width)}</div>
    ${lamps(word, width, field)}
  </div>`;
}

function opcodeRow(field, lut, info, hitBits) {
  const title = field === "lutA" ? "X opcode" : "Y opcode";
  return `<div class="pg-op-col pg-op-col--opcode">
    <div class="pg-op-head"><span class="pg-op-name">${title}</span>${hexField(field, lut, 8)}</div>
    <p class="pg-opcode-label">${esc(info.label)}</p>
    ${lamps(lut, 8, field, { hitBits })}
  </div>`;
}

function plane151Grid(field, lut, live) {
  let html = `<div class="pg-151">`;
  for (let i = 0; i < 8; i++) {
    const on = (lut >>> i) & 1;
    const isLive = live.has(i);
    const a = i & 1;
    const b = (i >>> 1) & 1;
    const c = (i >>> 2) & 1;
    html += `<button type="button" class="pg-d${on ? " is-on" : ""}${isLive ? " is-live" : ""}" data-act="bit" data-field="${esc(field)}" data-bit="${i}" aria-pressed="${on ? "true" : "false"}" title="Row ${i} · C=${c} B=${b} A=${a}">
      <span class="pg-d-n">${i}</span><span class="pg-d-abc">${c}${b}${a}</span><span class="pg-d-v">${on}</span>
    </button>`;
  }
  return html + `</div>`;
}

function planeCell(title, field, lut, live, bitVal) {
  const info = lutInfo(lut);
  const row = state.focusBit;
  const idx = bitVal?.idx ?? 0;
  const planeOut = field === "lutA" ? "X" : "Y";
  return `<article class="pg-plane">
    <header class="pg-plane-head">
      <p class="kicker">${esc(title)}</p>
      <h3 class="pg-cell-title">${esc(info.label)}</h3>
      <p class="pg-expr">${esc(info.expr)} · opcode ${hex(lut, 8)}</p>
    </header>
    <div class="pg-live-spot${live.has(idx) ? " is-live" : ""}">
      <p class="pg-live-label">At bit ${row} · row ${idx} · inputs ${bitVal ? `${bitVal.c}${bitVal.b}${bitVal.a}` : "—"}</p>
      <p class="pg-live-val">${planeOut} reads <strong>${bitVal ? (field === "lutA" ? bitVal.f : bitVal.g) : "?"}</strong></p>
    </div>
    <details class="pg-details">
      <summary>All eight rows on the 151</summary>
      ${hexField(field, lut, 8)}
      <p class="pg-151-cap">Pick a row on the 151 · copper ring = live for this vector</p>
      ${plane151Grid(field, lut, live)}
    </details>
  </article>`;
}

function adderStrip(row, r) {
  if (!row) return `<p class="pg-hint">Click a result bit to walk the 283 adder.</p>`;
  return `<div class="pg-adder-strip">
    <p class="pg-adder-formula"><span class="pg-adder-term">X <b>${row.f}</b></span> + <span class="pg-adder-term">Y <b>${row.g}</b></span> + <span class="pg-adder-term">carry in <b>${row.cin}</b></span> → <span class="pg-adder-sum"><b>${row.sum}</b></span></p>
    <p class="pg-hint">Ripple carry at this bit: ${row.cout}. Word carry out: ${r.cout}.</p>
    <div class="pg-csel" aria-label="Carry select">
      ${CSEL.map(
        (c) =>
          `<button type="button" data-act="csel" data-id="${c.id}" class="${state.csel === c.id ? "is-on" : ""}" title="${esc(cselLabel(c.id))}">${esc(c.name)}</button>`
      ).join("")}
    </div>
    <p class="pg-hint">Carry in is ${r.cin} from ${esc(cselLabel(state.csel))} · latched flags ${hex(state.flags, 8)}</p>
  </div>`;
}

function flagPills(flags, hitFlags) {
  return FLAG_BITS.map((f) => {
    const on = (flags >>> f.bit) & 1;
    const hit = hitFlags && hitFlags.has(f.bit);
    return `<span class="pg-flag${on ? " is-on" : ""}${hit ? " is-hit" : ""}" title="${esc(f.title)}">${esc(f.name)} <b>${on}</b></span>`;
  }).join("");
}

function renderStatus(ctx) {
  elStatus.innerHTML = `<p class="pg-legend">
      <span class="pg-legend-i is-on">1</span> high
      <span class="pg-legend-i is-live">·</span> live row on the 151
      <span class="pg-legend-i is-hit">·</span> moved on last flip
      <span class="pg-legend-i is-focus">·</span> bit under the loupe
      ${state.lastFlip ? `· last change: <strong>${esc(humanSource(state.lastFlip))}</strong>` : ""}
    </p>`;
}

function renderPipe(ctx) {
  if (!elPipe) return;
  const { r, xa, yb } = ctx;
  elPipe.innerHTML = `<div class="pg-pipe-well">
    <div class="pg-pipe-head">
      <span>Combinational path · Dual-LUT into 283</span>
      <span>Single cycle</span>
    </div>
    <div class="pg-pipe-grid">
      <div class="pg-pipe-stage">
        <p class="pg-pipe-k">X plane · 74ACT151</p>
        <p class="pg-pipe-v">${hex(r.fa, state.width)}</p>
        <p class="pg-pipe-d">${esc(lutShort(xa))}</p>
      </div>
      <div class="pg-pipe-stage">
        <p class="pg-pipe-k">Y plane · 74ACT151</p>
        <p class="pg-pipe-v">${hex(r.fb, state.width)}</p>
        <p class="pg-pipe-d">${esc(lutShort(yb))}</p>
      </div>
      <div class="pg-pipe-stage pg-pipe-stage--out">
        <p class="pg-pipe-k">283 adder</p>
        <p class="pg-pipe-v">${hex(r.out, state.width)}</p>
        <p class="pg-pipe-d">f + g + cin=${r.cin} · cout=${r.cout}</p>
      </div>
    </div>
    <div class="pg-pipe-flags">
      <span>OUT ${hex(r.out, state.width)} · ${r.out >>> 0}</span>
      <span class="pg-pipe-pills">${flagPills(r.flags, ctx.hitFlags)}</span>
    </div>
  </div>`;
}

function renderMap() {
  if (!elMap) return;
  const hit = matchProgram(state.lutA, state.lutB, cinNow());
  elMap.innerHTML = `<section class="pg-map" id="map">
    <p class="kicker">Canonical maps</p>
    <h2 class="pg-h">Named Dual-LUT programs</h2>
    <p class="pg-lede">These are real opcodes on the two 151s. Click a row to load them. The retired mux ALU (mask B, then add) is not this machine.</p>
    <div class="table-wrap"><table class="pg-map-table">
      <thead><tr><th>Name</th><th>X</th><th>Y</th><th>Cin</th><th>What it does</th></tr></thead>
      <tbody>${PROGRAMS.map((p) => {
        const on = hit && hit.id === p.id;
        return `<tr class="${on ? "is-hit" : ""}" data-act="prog" data-id="${esc(p.id)}">
          <td><strong>${esc(p.name)}</strong></td>
          <td class="mono">${hex(p.lutA, 8)}</td>
          <td class="mono">${hex(p.lutB, 8)}</td>
          <td class="mono">${p.cin}</td>
          <td>${esc(p.blurb)}</td>
        </tr>`;
      }).join("")}</tbody>
    </table></div>
  </section>`;
}

function operandSliders() {
  if (state.width > 8) return "";
  const max = mask(state.width);
  const row = (field, val) => `<label class="pg-slide">
      <span>${esc(OPERAND_NAMES[field])}</span>
      <input type="range" data-act="slide" data-field="${field}" min="0" max="${max}" value="${val}" />
      <span class="mono">${hex(val, state.width)}</span>
    </label>`;
  return `<div class="pg-slides">${row("A", state.A)}${row("B", state.B)}${row("C", state.C)}</div>`;
}

function renderHero(ctx) {
  const { r, prog, xa, yb, hitOut, hitFlags, focusRow } = ctx;
  const title = pairTitle(r.lutA, r.lutB, r.cin, prog);
  const bitLine = focusRow
    ? `At bit ${state.focusBit}: X reads ${focusRow.f}, Y reads ${focusRow.g}, carry in ${focusRow.cin} — sum bit ${focusRow.sum}.`
    : "";
  const carryNote = r.cin ? " · carry in high" : "";
  elHero.innerHTML = `<div class="pg-hero-grid" id="bench">
    <div class="pg-hero-eq">
      <div class="callout pg-callout">
        <span class="callout-label">${esc(title)}</span>
        <code class="callout-formula">${esc(lutShort(xa))} + ${esc(lutShort(yb))}${carryNote}</code>
      </div>
      <dl class="pg-hero-pair">
        <div><dt>X plane</dt><dd><strong>${esc(xa.label)}</strong> <span class="pg-hero-hex">${hex(r.lutA, 8)}</span></dd></div>
        <div><dt>Y plane</dt><dd><strong>${esc(yb.label)}</strong> <span class="pg-hero-hex">${hex(r.lutB, 8)}</span></dd></div>
        <div><dt>Carry in</dt><dd>${r.cin}</dd></div>
      </dl>
      <p class="pg-hero-prose">A ${hex(state.A, state.width)} · B ${hex(state.B, state.width)} · C ${hex(state.C, state.width)}${prog ? ` — ${esc(prog.blurb)}` : ""}</p>
      ${bitLine ? `<p class="pg-hero-bit">${bitLine}</p>` : ""}
    </div>
    <div class="pg-hero-out">
      <p class="kicker">Result</p>
      <div class="pg-out-hex">${hex(r.out, state.width)}</div>
      ${lamps(r.out, state.width, "out", { readonly: true, hitBits: hitOut, focusOnly: true })}
      <div class="pg-flags" aria-label="Next flags">${flagPills(r.flags, hitFlags)}</div>
      <button type="button" class="btn" data-act="latch">Latch flags</button>
    </div>
  </div>`;
}

function renderBench(ctx) {
  const { r, live, focusRow, xa, yb, hitLutA, hitLutB } = ctx;
  elBench.innerHTML = `<div class="pg-schematic">
    <p class="exhibit-label">Lot 07 datapath</p>

    <section class="pg-stage pg-stage--in">
      <p class="kicker">Operands</p>
      <p class="pg-hint">C selects which row each 151 reads — not a third number in the add.</p>
      <div class="pg-op-row">${operandRow("A", state.A, state.width)}${operandRow("B", state.B, state.width)}${operandRow("C", state.C, state.width)}</div>
      <div class="pg-opcode-row">
        ${opcodeRow("lutA", state.lutA, xa, hitLutA)}
        ${opcodeRow("lutB", state.lutB, yb, hitLutB)}
      </div>
    </section>

    <div class="pg-stage-arrow" aria-hidden="true">↓ both planes see A, B, and C</div>

    <section class="pg-stage pg-stage--planes">
      <p class="kicker">Dual-LUT planes</p>
      <div class="pg-plane-row">
        ${planeCell("X plane", "lutA", state.lutA, live, focusRow)}
        ${planeCell("Y plane", "lutB", state.lutB, live, focusRow)}
      </div>
    </section>

    <div class="pg-stage-arrow" aria-hidden="true">↓ into the 283</div>

    <section class="pg-stage pg-stage--adder">
      <p class="kicker">283 adder · bit ${state.focusBit}</p>
      ${adderStrip(focusRow, r)}
    </section>
  </div>`;
}

function renderControls(ctx) {
  const { prog } = ctx;
  const groupOps = PROGRAMS.filter((p) => p.group === state.presetGroup);
  elControls.innerHTML = `
    <div class="pg-controls">
      <div class="pg-controls-lead">
        <p class="pg-label">Slice</p>
        <div class="pg-seg" role="group" aria-label="Slice width">
          ${[1, 8, 32]
            .map(
              (w) =>
                `<button type="button" data-act="width" data-w="${w}" class="${state.width === w ? "is-on" : ""}">${w === 8 ? "8-bit" : w === 1 ? "1-bit" : "32-bit"}</button>`
            )
            .join("")}
        </div>
      </div>
      <div class="pg-preset-row">
        <label class="pg-label" for="pg-group">Operation</label>
        <select id="pg-group" class="pg-select" data-act="group">
          ${PRESET_GROUPS.map((g) => `<option value="${g.id}"${state.presetGroup === g.id ? " selected" : ""}>${esc(g.label)}</option>`).join("")}
        </select>
        <div class="pg-presets" role="group" aria-label="Operations in category">
          ${groupOps
            .map(
              (p) =>
                `<button type="button" data-act="prog" data-id="${esc(p.id)}" class="${prog && prog.id === p.id ? "is-on" : ""}" title="${esc(p.blurb)}">${esc(p.name)}</button>`
            )
            .join("")}
        </div>
      </div>
      ${operandSliders()}
    </div>`;
}

function renderTracePanel(ctx) {
  const { r, hitOut, focusRow } = ctx;
  const allRows = r.bits
    .map(
      (b) =>
        `<tr class="${hitOut.has(b.i) || state.focusBit === b.i ? "is-hit" : ""}">
          <td>${b.i}</td><td>${b.a}</td><td>${b.b}</td><td>${b.c}</td>
          <td>${b.idx}</td><td>${b.f}</td><td>${b.g}</td>
          <td>${b.cin}</td><td><strong>${b.sum}</strong></td><td>${b.cout}</td>
        </tr>`
    )
    .join("");
  const bitTable = `<details class="pg-details"${state.showAllBits ? " open" : ""}>
      <summary>All ${state.width} bits</summary>
      <label class="pg-check"><input type="checkbox" data-act="allbits" ${state.showAllBits ? "checked" : ""} /> Keep expanded</label>
      <div class="table-wrap"><table>
        <thead><tr><th>Bit</th><th>A</th><th>B</th><th>C</th><th>Row</th><th>X</th><th>Y</th><th>Carry in</th><th>Sum</th><th>Carry out</th></tr></thead>
        <tbody>${allRows}</tbody>
      </table></div>
    </details>`;

  return `<div class="pg-tabpanel" id="trace" role="tabpanel">
    <h2 class="pg-h">Bit by bit · the 283</h2>
    ${
      focusRow
        ? `<dl class="pg-adder-dl pg-adder-dl--wide">
      <div><dt>Bit</dt><dd>${focusRow.i}</dd></div>
      <div><dt>A B C</dt><dd>${focusRow.a} ${focusRow.b} ${focusRow.c}</dd></div>
      <div><dt>151 row</dt><dd>${focusRow.idx}</dd></div>
      <div><dt>X Y</dt><dd>${focusRow.f} ${focusRow.g}</dd></div>
      <div><dt>Carry in · sum · carry out</dt><dd>${focusRow.cin} ${focusRow.sum} ${focusRow.cout}</dd></div>
    </dl>`
        : ""
    }
    <label class="pg-check"><input type="checkbox" data-act="allbits" ${state.showAllBits ? "checked" : ""} /> Keep the full bit table open</label>
    ${bitTable}
  </div>`;
}

function renderTouchPanel(ctx) {
  const { sens, moved, live } = ctx;
  const shown = state.showIdle ? sens.rows : moved;
  return `<div class="pg-tabpanel" id="touch" role="tabpanel">
    <h2 class="pg-h">What moves when you flip a bit</h2>
    <p class="pg-lede">${moved.length} of ${sens.rows.length} inputs change the result or flags. Live rows on the 151: ${[...live].join(", ") || "none"}.</p>
    <label class="pg-check"><input type="checkbox" data-act="idle" ${state.showIdle ? "checked" : ""} /> Show inputs that stay quiet</label>
    <div class="table-wrap"><table>
      <thead><tr><th>Flip this</th><th>Result bits</th><th>Flags</th></tr></thead>
      <tbody>${shown
        .map((row) => {
          const outTxt = humanBits(row.outBits);
          const flTxt = row.flagNames.length ? row.flagNames.join(", ") : "—";
          return `<tr class="${row.source === state.lastFlip ? "is-hit" : ""}">
            <td><button type="button" class="pg-src" data-act="flip" data-src="${esc(row.source)}">${esc(humanSource(row.source))}</button></td>
            <td class="mono">${outTxt}</td><td class="mono">${flTxt}</td>
          </tr>`;
        })
        .join("")}</tbody>
    </table></div>
  </div>`;
}

function renderTruthPanel(ctx) {
  const { r, live, tt } = ctx;
  return `<div class="pg-tabpanel" id="truth" role="tabpanel">
    <h2 class="pg-h">Eight rows for this opcode pair</h2>
    <p class="pg-lede">Row index follows C, B, A. Copper highlight = live on the current vector.</p>
    <div class="table-wrap"><table>
      <thead><tr><th>C B A</th><th>Row</th><th>X</th><th>Y</th><th>Carry in</th><th>Sum</th><th>Carry out</th></tr></thead>
      <tbody>${tt
        .map(
          (row) =>
            `<tr class="${live.has(row.idx) ? "is-hit" : ""}">
              <td class="mono">${row.c}${row.b}${row.a}</td><td>${row.idx}</td>
              <td>${row.f}</td><td>${row.g}</td><td>${r.cin}</td>
              <td><strong>${row.sum}</strong></td><td>${row.cout}</td>
            </tr>`
        )
        .join("")}</tbody>
    </table></div>
  </div>`;
}

function renderCompilerShell() {
  return `<div class="pg-tabpanel" id="compiler" role="tabpanel">
    <h2 class="pg-h">Find an opcode</h2>
    <p class="pg-lede">Sweep the opcode space until a program matches — the same job the bench compiler does in hardware.</p>
    <div class="two-up two-up--sweeps pg-sweeps">
      <figure class="figure">
        <video controls playsinline muted preload="metadata" poster="assets/compiler/opcode-sweep-sim.webp" width="1680" height="1080">
          <source src="assets/compiler/opcode-sweep-sim.mp4" type="video/mp4" />
        </video>
        <p class="caption"><span>Fig. — Simulation</span><span>Opcode space sweep</span></p>
      </figure>
      <figure class="figure">
        <video controls playsinline muted preload="metadata" poster="assets/compiler/opcode-sweep-fpga.webp" width="480" height="544">
          <source src="assets/compiler/opcode-sweep-fpga.mp4" type="video/mp4" />
        </video>
        <p class="caption"><span>Fig. — Artix‑7</span><span>AND3 · 0x80</span></p>
      </figure>
    </div>
    <aside class="compiler-hit" aria-label="FPGA sweep vector">
      <span class="compiler-hit-label">FPGA hit</span>
      <div class="compiler-hit-grid">
        <div class="compiler-hit-id">
          <p class="compiler-hit-op">0x80</p>
          <p class="compiler-hit-fn">AND3</p>
          <span class="compiler-hit-expected">Expected</span>
          <p class="compiler-hit-eq">out = f(a, b, c) + g(a, b, c) + h(c<sub>in</sub>)</p>
          <p class="compiler-hit-hold">Reset zeros the result. Hold, then change the inputs: they take the function that was found — <span class="mono">out = AND3 + AND3</span>.</p>
        </div>
        <dl class="compiler-hit-vec">
          <div><dt>A</dt><dd>0x2e653abb</dd></div>
          <div><dt>B</dt><dd>0x7d0145cd</dd></div>
          <div><dt>C</dt><dd>0x1455f659</dd></div>
          <div><dt>c<sub>in</sub></dt><dd>0</dd></div>
          <div class="is-out"><dt>out</dt><dd>0x08020012</dd></div>
        </dl>
      </div>
    </aside>
    <div class="pg-resolve-grid">
      <div>
        <p class="kicker">Vector sweep</p>
        <label class="pg-label" for="pg-want">Expected result</label>
        <input id="pg-want" class="pg-hex" value="46" spellcheck="false" autocomplete="off" />
        <div class="pg-resolve-actions">
          <button type="button" class="btn" data-act="resolve-fill">Use current result</button>
          <button type="button" class="btn" data-act="resolve-current">Sweep</button>
        </div>
      </div>
      <div>
        <p class="kicker">One-bit truth table</p>
        <label class="pg-label" for="pg-catalog">Catalog</label>
        <select id="pg-catalog" class="pg-select"><option value="">Curated 3-input ops</option></select>
        <label class="pg-label" for="pg-truth">Truth byte</label>
        <input id="pg-truth" class="pg-hex" value="80" spellcheck="false" autocomplete="off" />
        <div class="pg-resolve-actions">
          <button type="button" class="btn" data-act="resolve-truth">Resolve family</button>
        </div>
      </div>
    </div>
    <label class="pg-check"><input type="checkbox" id="pg-single" /> Y plane off (single plane only)</label>
    <div id="pg-compiler-results"></div>
  </div>`;
}

function renderCompilerResults() {
  const box = document.getElementById("pg-compiler-results");
  if (!box) return;
  if (resolveError) {
    box.innerHTML = `<p class="pg-lede">${esc(resolveError)}</p>`;
    return;
  }
  if (!resolveResult) {
    box.innerHTML = `<p class="pg-lede">No sweep yet.</p>`;
    return;
  }
  const r = resolveResult;
  const best = r.best
    ? `${hex(r.best.lutA, 8)} / ${hex(r.best.lutB, 8)}, carry ${r.best.cin} (${esc(lutInfo(r.best.lutA).label)} + ${esc(lutInfo(r.best.lutB).label)})`
    : "none";
  const named =
    r.named.length === 0
      ? ""
      : `<p class="pg-lede">Named hits: ${r.named.map((n) => esc(n.name)).join(", ")}</p>`;
  const sample = r.sample
    .slice(0, 8)
    .map(
      (p) =>
        `<li><button type="button" data-act="load-prog" data-x="${p.lutA}" data-y="${p.lutB}" data-cin="${p.cin}">${hex(p.lutA, 8)} / ${hex(p.lutB, 8)}, carry ${p.cin}</button></li>`
    )
    .join("");
  box.innerHTML = `
    <p class="pg-out-hex pg-out-hex--sm">${r.count.toLocaleString()} matches</p>
    <p class="pg-lede">Searched ${r.space.toLocaleString()} programs. Preferred: <strong>${best}</strong>.</p>
    ${named}
    <ul class="pg-hits">${sample}</ul>`;
}

function renderDetail(ctx) {
  const tabs = [
    { id: "trace", label: "Bit by bit" },
    { id: "touch", label: "What moves" },
    { id: "truth", label: "Eight rows" },
    { id: "compiler", label: "Find opcode" },
  ];
  const tabBar = tabs
    .map(
      (t) =>
        `<button type="button" role="tab" class="pg-tab${state.activeTab === t.id ? " is-on" : ""}" data-act="tab" data-tab="${t.id}" aria-selected="${state.activeTab === t.id}">${t.label}</button>`
    )
    .join("");

  let anchor = elDetail.querySelector(".pg-detail");
  if (!anchor) {
    elDetail.innerHTML = `<div class="pg-detail" id="pg-detail-anchor">
      <div class="pg-tabs" role="tablist"></div>
      <div class="pg-tabpanels"></div>
    </div>`;
    anchor = elDetail.querySelector(".pg-detail");
  }

  anchor.querySelector(".pg-tabs").innerHTML = tabBar;
  const panels = anchor.querySelector(".pg-tabpanels");
  const compilerForm = document.getElementById("pg-want");

  if (state.activeTab === "compiler" && compilerForm) {
    renderCompilerResults();
  } else if (state.activeTab === "compiler") {
    panels.innerHTML = renderCompilerShell();
    fillCatalog();
    renderCompilerResults();
  } else if (state.activeTab) {
    panels.innerHTML = renderPanel(ctx, state.activeTab);
  } else {
    panels.innerHTML = `<p class="pg-hint pg-detail-hint">Pick a tab — or use the sidebar — to walk bits one at a time, see what flips move the result, read the eight-row truth table, or hunt for an opcode.</p>`;
  }
  syncNav();
}

function fillCatalog() {
  const catalog = document.getElementById("pg-catalog");
  if (!catalog || catalog.options.length > 1) return;
  catalog.innerHTML =
    `<option value="">Curated 3-input ops</option>` +
    LUT_CATALOG.map(([n, name, expr]) => {
      const hx = n.toString(16).toUpperCase().padStart(2, "0");
      return `<option value="${n}">${esc(lutLabel(name))} · 0x${hx} · ${esc(expr)}</option>`;
    }).join("");
}

function renderPanel(ctx, tab) {
  switch (tab) {
    case "trace":
      return renderTracePanel(ctx);
    case "touch":
      return renderTouchPanel(ctx);
    case "truth":
      return renderTruthPanel(ctx);
    case "compiler":
      return renderCompilerShell();
    default:
      return "";
  }
}

function syncNav() {
  const hash = (location.hash || "").replace(/^#/, "").toLowerCase();
  const current = TAB_IDS.includes(hash)
    ? hash
    : PAGE_IDS.includes(hash)
      ? hash
      : state.activeTab || "overview";
  document.querySelectorAll(".pg-nav__link").forEach((a) => {
    const id = (a.getAttribute("href") || "").replace(/^#/, "");
    a.classList.toggle("pg-nav__link--current", id === current);
  });
}

function restoreFocus() {
  const active = document.activeElement;
  if (!active || !main.contains(active)) return;
  const field = active.dataset?.field;
  if (!field || !active.classList?.contains("pg-hex")) return;
  const pos = active.selectionStart;
  requestAnimationFrame(() => {
    const el = main.querySelector(`[data-field="${field}"]`);
    if (el && "focus" in el) {
      el.focus();
      if (pos != null && el.setSelectionRange) {
        try {
          el.setSelectionRange(pos, pos);
        } catch {
          /* ignore */
        }
      }
    }
  });
}

function render() {
  const ctx = computeContext();
  renderControls(ctx);
  renderHero(ctx);
  renderPipe(ctx);
  renderStatus(ctx);
  renderBench(ctx);
  renderMap();
  renderDetail(ctx);
  writeQuery();
  restoreFocus();
}

function parseSrc(src) {
  const m = /^(A|B|C|lutA|lutB)\[(\d+)\]$/.exec(src);
  if (m) return { field: m[1], bit: Number(m[2]) };
  if (src === "cin") return { field: "cin" };
  return null;
}

function toggleBit(field, bit) {
  if (field === "out") {
    state.focusBit = bit;
    return;
  }
  if (field === "lutA" || field === "lutB") {
    state[field] = (state[field] ^ (1 << bit)) & 255;
    state.lastFlip = `${field}[${bit}]`;
    return;
  }
  if (field === "A" || field === "B" || field === "C") {
    state[field] = (state[field] ^ (1 << bit)) & mask(state.width);
    state.focusBit = bit;
    state.lastFlip = `${field}[${bit}]`;
  }
}

main.addEventListener("click", (ev) => {
  const row = ev.target.closest("tr[data-act='prog']");
  if (row && main.contains(row) && !ev.target.closest("button")) {
    const p = PROGRAMS.find((x) => x.id === row.dataset.id);
    if (p) {
      applyProgram(p, false);
      state.lastFlip = null;
      render();
      return;
    }
  }
  const btn = ev.target.closest("[data-act]");
  if (!btn || !main.contains(btn)) return;
  const act = btn.dataset.act;
  if (act === "bit") {
    toggleBit(btn.dataset.field, Number(btn.dataset.bit));
  } else if (act === "focus") {
    state.focusBit = Number(btn.dataset.bit);
  } else if (act === "nibble") {
    const n = Number(btn.dataset.nibble);
    state.expandedNibble = state.expandedNibble === n ? null : n;
  } else if (act === "width") {
    state.width = Number(btn.dataset.w);
    clampWord();
    syncFocusForWidth();
    state.lastFlip = null;
  } else if (act === "prog") {
    const p = PROGRAMS.find((x) => x.id === btn.dataset.id);
    if (p) applyProgram(p, false);
    state.lastFlip = null;
  } else if (act === "csel") {
    state.csel = Number(btn.dataset.id) & 7;
    state.lastFlip = "cin";
  } else if (act === "latch") {
    state.flags = evalNow().flags;
  } else if (act === "tab") {
    state.activeTab = btn.dataset.tab;
    location.hash = state.activeTab;
  } else if (act === "flip") {
    const parsed = parseSrc(btn.dataset.src);
    if (parsed && parsed.field === "cin") {
      state.csel = cinNow() ? 0 : 1;
      state.lastFlip = "cin";
    } else if (parsed) toggleBit(parsed.field, parsed.bit);
  } else if (act === "resolve-current") {
    const wantEl = document.getElementById("pg-want");
    const singleEl = document.getElementById("pg-single");
    const want = parseIntWord(wantEl?.value || "0", state.width);
    resolveError = "";
    resolveResult = resolveConstraints(
      state.width,
      [{ A: state.A, B: state.B, C: state.C, out: want }],
      { singlePlane: singleEl?.checked }
    );
    if (resolveResult.best) {
      state.lutA = resolveResult.best.lutA;
      state.lutB = resolveResult.best.lutB;
      state.csel = resolveResult.best.cin;
    }
    render();
    return;
  } else if (act === "resolve-truth") {
    const truthEl = document.getElementById("pg-truth");
    const singleEl = document.getElementById("pg-single");
    const want = parseIntWord(truthEl?.value || "0", 8);
    resolveError = "";
    resolveResult = resolveTruth(want, { singlePlane: singleEl?.checked });
    if (resolveResult.best) {
      state.width = 1;
      state.lutA = resolveResult.best.lutA;
      state.lutB = resolveResult.best.lutB;
      state.csel = resolveResult.best.cin;
      syncFocusForWidth();
      clampWord();
    }
    render();
    return;
  } else if (act === "resolve-fill") {
    const wantEl = document.getElementById("pg-want");
    if (wantEl) wantEl.value = hex(evalNow().out, state.width).slice(2);
    render();
    return;
  } else if (act === "load-prog") {
    state.lutA = Number(btn.dataset.x) & 255;
    state.lutB = Number(btn.dataset.y) & 255;
    state.csel = Number(btn.dataset.cin) & 1;
    state.lastFlip = null;
  } else return;
  render();
});

main.addEventListener("input", (ev) => {
  const t = ev.target;
  if (!t || !main.contains(t)) return;
  if (t.dataset?.act === "slide" && t.dataset.field) {
    const field = t.dataset.field;
    const v = Number(t.value) & mask(state.width);
    if (field === "A" || field === "B" || field === "C") {
      state[field] = v;
      state.lastFlip = null;
      render();
    }
  }
});

main.addEventListener("change", (ev) => {
  const t = ev.target;
  if (!t || !main.contains(t)) return;
  if (t.dataset?.act === "idle") {
    state.showIdle = t.checked;
    render();
  } else if (t.dataset?.act === "allbits") {
    state.showAllBits = t.checked;
    render();
  } else if (t.dataset?.act === "group" || t.id === "pg-group") {
    state.presetGroup = t.value;
    render();
  } else if (t.id === "pg-catalog") {
    const v = Number(t.value);
    if (Number.isFinite(v)) {
      const truthEl = document.getElementById("pg-truth");
      if (truthEl) truthEl.value = v.toString(16).toUpperCase().padStart(2, "0");
    }
  }
});

main.addEventListener("focusout", (ev) => {
  const t = ev.target;
  if (t?.classList?.contains("pg-hex")) commitHex(t);
});

main.addEventListener("keydown", (ev) => {
  const t = ev.target;
  if (t?.classList?.contains("pg-hex") && ev.key === "Enter") {
    ev.preventDefault();
    commitHex(t);
    t.blur();
  }
});

function commitHex(input) {
  const field = input.dataset.field;
  const w = field === "lutA" || field === "lutB" ? 8 : state.width;
  const v = parseIntWord(input.value, w);
  if (field === "A" || field === "B" || field === "C") state[field] = v;
  else if (field === "lutA" || field === "lutB") state[field] = v & 255;
  state.lastFlip = null;
  render();
}

document.querySelectorAll(".pg-nav__link").forEach((a) => {
  a.addEventListener("click", (ev) => {
    const id = (a.getAttribute("href") || "").replace(/^#/, "");
    if (TAB_IDS.includes(id)) {
      ev.preventDefault();
      state.activeTab = id;
      location.hash = id;
      render();
      requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView({ behavior: "smooth" }));
      return;
    }
    if (PAGE_IDS.includes(id)) {
      ev.preventDefault();
      if (id === "bench" || id === "overview" || id === "map" || id === "wire" || id === "bom") {
        state.activeTab = null;
      }
      location.hash = id;
      syncNav();
      requestAnimationFrame(() => document.getElementById(id)?.scrollIntoView({ behavior: "smooth" }));
    }
  });
});

window.addEventListener("hashchange", () => {
  const h = (location.hash || "").replace(/^#/, "").toLowerCase();
  if (h === "bench" || h === "overview" || h === "map" || h === "wire" || h === "bom") state.activeTab = null;
  else if (TAB_IDS.includes(h)) state.activeTab = h;
  render();
});

const bomQ = document.getElementById("pg-bom-q");
const bomBody = document.getElementById("pg-bom-body");
if (bomQ && bomBody) {
  const rows = [...bomBody.querySelectorAll("tr")].map((tr) => ({
    tr,
    text: tr.textContent.toLowerCase(),
  }));
  bomQ.addEventListener("input", () => {
    const q = bomQ.value.trim().toLowerCase();
    for (const row of rows) row.tr.hidden = q ? !row.text.includes(q) : false;
  });
}

readQuery();
render();
const dest = (location.hash || "").replace(/^#/, "");
if (dest && dest !== "bench" && TAB_IDS.includes(dest.toLowerCase())) {
  requestAnimationFrame(() => document.getElementById(dest.toLowerCase())?.scrollIntoView());
}
