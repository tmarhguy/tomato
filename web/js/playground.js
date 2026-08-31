/**
 * Dual-LUT playground — one clear loop: operation → inputs → result.
 */
import {
  ALU_OPCODE_SPACE,
  PRESET_GROUPS,
  PROGRAMS,
  aluEval,
  cinFromCsel,
  hex,
  lutInfo,
  lutShort,
  matchProgram,
  parseIntWord,
} from "./alu.js";

const WIDTH = 8;
const MASK = 0xff;

const FEATURED = ["add", "sub", "choose", "maskadd", "and", "or", "xor", "maj", "mux", "xor3"];

const main = document.getElementById("pg-main");
const elHero = document.getElementById("pg-hero");
const elBench = document.getElementById("pg-bench");
const elDetail = document.getElementById("pg-detail");
if (!main || !elHero || !elBench || !elDetail) {
  throw new Error("playground shell missing");
}

const state = {
  A: 0x12,
  B: 0x34,
  C: 0,
  progId: "add",
  focusBit: 7,
  traceOpen: false,
  compilerOpen: false,
};

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function program() {
  return PROGRAMS.find((p) => p.id === state.progId) || PROGRAMS[0];
}

function evalState() {
  const p = program();
  const cin = cinFromCsel(p.csel, 0);
  return aluEval({
    width: WIDTH,
    lutA: p.lutA,
    lutB: p.lutB,
    A: state.A & MASK,
    B: state.B & MASK,
    C: state.C & MASK,
    cin,
  });
}

function readQuery() {
  const q = new URLSearchParams(location.search);
  if (q.has("A")) state.A = parseIntWord(q.get("A"), WIDTH);
  if (q.has("B")) state.B = parseIntWord(q.get("B"), WIDTH);
  if (q.has("C")) state.C = parseIntWord(q.get("C"), WIDTH);
  if (q.has("op")) {
    const hit = PROGRAMS.find((p) => p.id === q.get("op"));
    if (hit) state.progId = hit.id;
  }
  const h = (location.hash || "").replace(/^#/, "").toLowerCase();
  if (h === "trace") state.traceOpen = true;
  if (h === "compiler") state.compilerOpen = true;
  if (h === "bench") state.compilerOpen = false;
  if (PROGRAMS.some((p) => p.id === h)) state.progId = h;
}

function writeQuery() {
  const q = new URLSearchParams();
  q.set("op", state.progId);
  q.set("A", state.A.toString(16));
  q.set("B", state.B.toString(16));
  q.set("C", state.C.toString(16));
  const hash = state.compilerOpen ? "#compiler" : state.traceOpen ? "#trace" : "";
  history.replaceState(null, "", `${location.pathname}?${q.toString()}${hash}`);
}

function bitRow(field, word) {
  let html = `<div class="slice-bits" role="group" aria-label="${esc(field)} bits">`;
  for (let i = WIDTH - 1; i >= 0; i--) {
    const on = (word >>> i) & 1;
    html += `<button type="button" class="slice-bit${on ? " is-on" : ""}${state.focusBit === i && field === "out" ? " is-focus" : ""}" data-act="bit" data-field="${field}" data-bit="${i}" aria-pressed="${on ? "true" : "false"}"><span>${i}</span></button>`;
  }
  return html + "</div>";
}

function renderHero(r, p) {
  const xa = lutInfo(r.lutA);
  const yb = lutInfo(r.lutB);
  const named = matchProgram(r.lutA, r.lutB, r.cin);
  const title = named ? named.name : p.name;
  elHero.innerHTML = `
    <div class="slice-hero__grid">
      <div class="slice-hero__eq">
        <p class="slice-hero__op">${esc(title)}</p>
        <p class="slice-hero__formula"><span class="slice-term">X <b>${hex(r.fa, WIDTH)}</b></span>
          <span class="slice-plus">+</span>
          <span class="slice-term">Y <b>${hex(r.fb, WIDTH)}</b></span>
          <span class="slice-plus">+</span>
          <span class="slice-term">cin <b>${r.cin}</b></span></p>
        <p class="slice-hero__plain">${esc(lutShort(xa))} + ${esc(lutShort(yb))}${r.cin ? " + carry in" : ""}</p>
        <p class="slice-hero__hint">${esc(p.blurb)}</p>
      </div>
      <div class="slice-hero__out">
        <p class="kicker">Result</p>
        <p class="slice-out-hex" id="bench">${hex(r.out, WIDTH)}</p>
        <p class="slice-out-dec">${r.out >>> 0} decimal</p>
        ${bitRow("out", r.out)}
      </div>
    </div>`;
}

function opButton(op) {
  return `<button type="button" class="slice-op${state.progId === op.id ? " is-on" : ""}" data-act="prog" data-id="${esc(op.id)}" title="${esc(op.blurb)}">${esc(op.name)}</button>`;
}

function renderOpGroups() {
  const featured = PROGRAMS.filter((op) => FEATURED.includes(op.id));
  const featuredIds = new Set(featured.map((op) => op.id));
  const groups = PRESET_GROUPS.map((group) => {
    const ops = PROGRAMS.filter((op) => op.group === group.id && !featuredIds.has(op.id));
    if (!ops.length) return "";
    return `<div class="slice-op-group">
      <p class="slice-op-group__label">${esc(group.label)}</p>
      <div class="slice-ops" role="group" aria-label="${esc(group.label)}">
        ${ops.map(opButton).join("")}
      </div>
    </div>`;
  }).join("");

  return `<div class="slice-op-group slice-op-group--featured">
      <p class="slice-op-group__label">Common burns</p>
      <div class="slice-ops" role="group" aria-label="Common burns">
        ${featured.map(opButton).join("")}
      </div>
    </div>${groups}`;
}

function renderBench(r, p) {
  elBench.innerHTML = `
    <section class="slice-panel" aria-labelledby="slice-ops-label">
      <header class="slice-panel__head">
        <p class="kicker" id="slice-ops-label">Step 1</p>
        <h2 class="slice-h">Choose what the LUTs compute</h2>
        <p class="slice-lede"><strong>${ALU_OPCODE_SPACE.toLocaleString("en-US")}</strong> programs on the word (256×256×8). Each button loads a real opcode pair onto the two 151s — named burns from that space, same programs lot&nbsp;07 runs.</p>
      </header>
      <div class="slice-op-groups">
        ${renderOpGroups()}
      </div>
    </section>

    <section class="slice-panel" aria-labelledby="slice-in-label">
      <header class="slice-panel__head">
        <p class="kicker" id="slice-in-label">Step 2</p>
        <h2 class="slice-h">Set the operands</h2>
        <p class="slice-lede">Click a bit to toggle it, or type hex. <strong>C</strong> picks which row each 151 reads — not a third addend.</p>
      </header>
      <div class="slice-io">
        ${["A", "B", "C"]
          .map((field) => {
            const word = state[field];
            return `<div class="slice-field">
              <label class="slice-label" for="slice-${field.toLowerCase()}">Operand ${field}</label>
              <input id="slice-${field.toLowerCase()}" class="slice-hex" data-field="${field}" value="${hex(word, WIDTH).slice(2)}" spellcheck="false" autocomplete="off" inputmode="text" />
              ${bitRow(field, word)}
            </div>`;
          })
          .join("")}
      </div>
    </section>

    <section class="slice-panel slice-panel--path" aria-labelledby="slice-path-label">
      <header class="slice-panel__head">
        <p class="kicker" id="slice-path-label">Step 3</p>
        <h2 class="slice-h">Watch it combine</h2>
      </header>
      <div class="slice-path">
        <div class="slice-path__stage">
          <p class="slice-path__chip">A · B · C</p>
          <p class="slice-path__val">${hex(state.A, WIDTH)} · ${hex(state.B, WIDTH)} · ${hex(state.C, WIDTH)}</p>
        </div>
        <p class="slice-path__arrow" aria-hidden="true">→</p>
        <div class="slice-path__stage">
          <p class="slice-path__chip">X plane · 151</p>
          <p class="slice-path__val">${hex(r.fa, WIDTH)}</p>
          <p class="slice-path__note">${esc(lutShort(lutInfo(r.lutA)))}</p>
        </div>
        <p class="slice-path__arrow" aria-hidden="true">+</p>
        <div class="slice-path__stage">
          <p class="slice-path__chip">Y plane · 151</p>
          <p class="slice-path__val">${hex(r.fb, WIDTH)}</p>
          <p class="slice-path__note">${esc(lutShort(lutInfo(r.lutB)))}</p>
        </div>
        <p class="slice-path__arrow" aria-hidden="true">+</p>
        <div class="slice-path__stage slice-path__stage--out">
          <p class="slice-path__chip">283 · OUT</p>
          <p class="slice-path__val">${hex(r.out, WIDTH)}</p>
          <p class="slice-path__note">cin ${r.cin} · cout ${r.cout}</p>
        </div>
      </div>
    </section>`;
}

function renderTrace(r) {
  const row = r.bits[state.focusBit];
  if (!row) return "";
  return `
    <details class="slice-fold" id="trace"${state.traceOpen ? " open" : ""}>
      <summary>One bit at a time — how the 283 sees bit ${state.focusBit}</summary>
      <div class="slice-fold__body">
        <p class="slice-lede">Pick a result bit above to change focus. At this bit the 151s read row <strong>${row.idx}</strong> (inputs C=${row.c} B=${row.b} A=${row.a}).</p>
        <dl class="slice-bit-dl">
          <div><dt>X reads</dt><dd>${row.f}</dd></div>
          <div><dt>Y reads</dt><dd>${row.g}</dd></div>
          <div><dt>Carry in</dt><dd>${row.cin}</dd></div>
          <div><dt>Sum bit</dt><dd><strong>${row.sum}</strong></dd></div>
          <div><dt>Carry out</dt><dd>${row.cout}</dd></div>
        </dl>
        <div class="table-wrap">
          <table class="slice-bit-table">
            <thead><tr><th>Bit</th><th>A</th><th>B</th><th>C</th><th>Row</th><th>X</th><th>Y</th><th>Cin</th><th>Sum</th></tr></thead>
            <tbody>${r.bits
              .map(
                (b) =>
                  `<tr class="${state.focusBit === b.i ? "is-focus" : ""}"><td>${b.i}</td><td>${b.a}</td><td>${b.b}</td><td>${b.c}</td><td>${b.idx}</td><td>${b.f}</td><td>${b.g}</td><td>${b.cin}</td><td><strong>${b.sum}</strong></td></tr>`
              )
              .join("")}</tbody>
          </table>
        </div>
      </div>
    </details>`;
}

function renderCompiler() {
  return `
    <details class="slice-fold" id="compiler"${state.compilerOpen ? " open" : ""}>
      <summary>Opcode compiler — how hardware finds a program</summary>
      <div class="slice-fold__body">
        <p class="slice-lede">The bench FSM sweeps opcode space until a Dual-LUT program matches the vector you asked for — same job as the clips below.</p>
        <div class="two-up two-up--sweeps pg-sweeps">
          <figure class="figure">
            <div class="sweep-media">
              <video controls playsinline muted preload="metadata" poster="assets/compiler/opcode-sweep-sim.webp" width="1680" height="1080">
                <source src="assets/compiler/opcode-sweep-sim.mp4" type="video/mp4" />
              </video>
            </div>
            <p class="caption"><span>Fig. — Simulation</span><span>Opcode space sweep</span></p>
          </figure>
          <figure class="figure">
            <div class="sweep-media sweep-media--fpga">
              <video controls playsinline muted preload="metadata" poster="assets/compiler/opcode-sweep-fpga.webp" width="480" height="544">
                <source src="assets/compiler/opcode-sweep-fpga.mp4" type="video/mp4" />
              </video>
            </div>
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
        <p class="slice-lede">Try <button type="button" class="slice-linkish" data-act="prog" data-id="and3">AND3</button> or <button type="button" class="slice-linkish" data-act="prog" data-id="choose">SHA Choose</button> in step 1 — opcode <span class="mono">0x80</span> / <span class="mono">0xD8</span> on the X plane.</p>
      </div>
    </details>`;
}

function renderDetail(r) {
  elDetail.innerHTML = renderTrace(r) + renderCompiler();
}

function render() {
  const p = program();
  const r = evalState();
  renderHero(r, p);
  renderBench(r, p);
  renderDetail(r);
  writeQuery();
}

function toggleBit(field, bit) {
  if (field === "out") {
    state.focusBit = bit;
    return;
  }
  if (field === "A" || field === "B" || field === "C") {
    state[field] = (state[field] ^ (1 << bit)) & MASK;
    state.focusBit = bit;
  }
}

function commitHex(input) {
  const field = input.dataset.field;
  if (field !== "A" && field !== "B" && field !== "C") return;
  state[field] = parseIntWord(input.value, WIDTH);
  render();
}

main.addEventListener("click", (ev) => {
  const btn = ev.target.closest("[data-act]");
  if (!btn || !main.contains(btn)) return;
  const act = btn.dataset.act;
  if (act === "bit") {
    toggleBit(btn.dataset.field, Number(btn.dataset.bit));
    render();
  } else if (act === "prog") {
    state.progId = btn.dataset.id;
    render();
  }
});

main.addEventListener("toggle", (ev) => {
  const t = ev.target;
  if (t?.id === "trace") state.traceOpen = t.open;
  if (t?.id === "compiler") state.compilerOpen = t.open;
  writeQuery();
});

main.addEventListener("focusout", (ev) => {
  const t = ev.target;
  if (t?.classList?.contains("slice-hex")) commitHex(t);
});

main.addEventListener("keydown", (ev) => {
  const t = ev.target;
  if (t?.classList?.contains("slice-hex") && ev.key === "Enter") {
    ev.preventDefault();
    commitHex(t);
    t.blur();
  }
});

window.addEventListener("hashchange", () => {
  const h = (location.hash || "").replace(/^#/, "").toLowerCase();
  state.traceOpen = h === "trace";
  state.compilerOpen = h === "compiler";
  render();
  const target = document.getElementById(h);
  if (target) target.scrollIntoView({ behavior: "smooth", block: "start" });
});

readQuery();
render();

const dest = (location.hash || "").replace(/^#/, "").toLowerCase();
if (dest === "compiler" || dest === "trace" || dest === "bench") {
  requestAnimationFrame(() => document.getElementById(dest)?.scrollIntoView({ behavior: "smooth", block: "start" }));
}
