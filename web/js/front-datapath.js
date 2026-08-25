/**
 * Front-page Dual-LUT strip — same alu.js as the playground, 8-bit only.
 */
import {
  PROGRAMS,
  aluEval,
  cinFromCsel,
  hex,
  lutInfo,
  lutShort,
  matchProgram,
} from "./alu.js";

const root = document.getElementById("pg-front");
if (!root) {
  /* Front page only. */
} else {
  const elControls = document.getElementById("pg-front-controls");
  const elPipe = document.getElementById("pg-front-pipe");
  const PRESETS = PROGRAMS.filter((p) =>
    ["add", "sub", "neg", "and", "xor", "maj", "and3"].includes(p.id)
  );

  const state = {
    A: 12,
    B: 5,
    C: 0,
    lutA: 0xaa,
    lutB: 0xcc,
    csel: 0,
  };

  function esc(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function evalNow() {
    return aluEval({
      width: 8,
      lutA: state.lutA,
      lutB: state.lutB,
      A: state.A,
      B: state.B,
      C: state.C,
      cin: cinFromCsel(state.csel, 0),
    });
  }

  function render() {
    const r = evalNow();
    const prog = matchProgram(r.lutA, r.lutB, r.cin);
    const xa = lutInfo(r.lutA);
    const yb = lutInfo(r.lutB);
    const z = r.flags & 1;
    const n = (r.flags >>> 2) & 1;
    const c = (r.flags >>> 3) & 1;

    elControls.innerHTML = `
      <div class="pg-front-presets" role="group" aria-label="Instruction presets">
        ${PRESETS.map(
          (p) =>
            `<button type="button" data-id="${esc(p.id)}" class="${prog && prog.id === p.id ? "is-on" : ""}">${esc(p.name)}</button>`
        ).join("")}
      </div>
      <div class="pg-front-slides">
        ${["A", "B", "C"]
          .map(
            (field) => `<label class="pg-slide">
          <span>Operand ${field}</span>
          <input type="range" data-field="${field}" min="0" max="255" value="${state[field]}" />
          <span class="mono">${hex(state[field], 8)}</span>
        </label>`
          )
          .join("")}
      </div>`;

    elPipe.innerHTML = `<div class="pg-pipe-well">
      <div class="pg-pipe-head">
        <span>X LUT + Y LUT → 283 · ${esc(prog ? prog.name : "custom")}</span>
        <span>Single cycle</span>
      </div>
      <div class="pg-pipe-grid">
        <div class="pg-pipe-stage">
          <p class="pg-pipe-k">X plane · 74ACT151</p>
          <p class="pg-pipe-v">${hex(r.fa, 8)}</p>
          <p class="pg-pipe-d">${esc(lutShort(xa))}</p>
        </div>
        <div class="pg-pipe-stage">
          <p class="pg-pipe-k">Y plane · 74ACT151</p>
          <p class="pg-pipe-v">${hex(r.fb, 8)}</p>
          <p class="pg-pipe-d">${esc(lutShort(yb))}</p>
        </div>
        <div class="pg-pipe-stage pg-pipe-stage--out">
          <p class="pg-pipe-k">283 adder</p>
          <p class="pg-pipe-v">${hex(r.out, 8)}</p>
          <p class="pg-pipe-d">f + g + cin=${r.cin} · ${r.out >>> 0} decimal</p>
        </div>
      </div>
      <div class="pg-pipe-flags">
        <span>BIN ${r.out.toString(2).padStart(8, "0")}</span>
        <span class="pg-front-pills">
          <span class="${z ? "is-on" : ""}">Z=${z}</span>
          <span class="${c ? "is-on" : ""}">C=${c}</span>
          <span class="${n ? "is-on" : ""}">N=${n}</span>
        </span>
      </div>
    </div>`;
  }

  root.addEventListener("click", (ev) => {
    const btn = ev.target.closest("button[data-id]");
    if (!btn || !root.contains(btn)) return;
    const p = PROGRAMS.find((x) => x.id === btn.dataset.id);
    if (!p) return;
    state.lutA = p.lutA;
    state.lutB = p.lutB;
    state.csel = p.csel;
    render();
  });

  root.addEventListener("input", (ev) => {
    const t = ev.target;
    if (t?.dataset?.field && (t.dataset.field === "A" || t.dataset.field === "B" || t.dataset.field === "C")) {
      state[t.dataset.field] = Number(t.value) & 255;
      render();
    }
  });

  render();
}
