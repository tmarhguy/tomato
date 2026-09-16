/* Homepage embed: automatically boot Tomato OS.
 *
 * Same engine as the full board (js/tomato-cpu.js, same firmware image),
 * smaller chrome: no demo phone, no pause — keyboard works only while focus is
 * inside the figure so page scroll is never hijacked.
 */
import { Tomato, loadImage } from "./tomato-cpu.js?v=47cc72f7";
import { paintDirty, paintFull } from "./tomato-screen.js?v=a9760af7";

const BOOT_INSTR = 200000;
const UI_SETTLE_INSTR = 52500;
const COMPILER_SETTLE_INSTR = 220000;
const FRAME_BUDGET_MS = 8;
const FRAME_INSTR_CAP = 60000;

const figure = document.querySelector("#vt-embed");
if (figure) {
  const canvas = figure.querySelector("#vt-embed-screen");
  const ctx = canvas.getContext("2d", { alpha: false });
  const imgData = ctx.createImageData(640, 480);
  ctx.fillStyle = "#f2f1ec";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#30342f";
  ctx.font = "20px system-ui, sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("Loading Tomato OS…", canvas.width / 2, canvas.height / 2);
  const play = figure.querySelector("#vt-embed-play");
  const statusEl = figure.querySelector("#vt-embed-status");

  let image = null;
  let cpu = null;
  let steps = 0;
  let running = false;
  let visible = false;
  let compilerDemo = false;
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }, {threshold: 0}).observe(figure);
  const keyQueue = [];

  const KEYMAP = { ArrowUp: 30, ArrowDown: 31, ArrowLeft: 17, ArrowRight: 16, Enter: 13 };

  function status() {
    if (!cpu) return;
    if (cpu.halted) statusEl.textContent = `CPU halted · ${steps} steps`;
    else if (compilerDemo) statusEl.textContent = "Compiler demo · Virtual Tomato · CPU running";
    else statusEl.textContent = `CPU running · ${steps} steps`;
  }

  function pressAndSettle(code, instructions = UI_SETTLE_INSTR) {
    cpu.key(code);
    cpu.step(instructions);
    steps += instructions;
  }

  function openCompilerDemo() {
    // The launcher starts on System info. Up wraps to Envelop; up once more
    // selects the shipped Compiler app immediately before it.
    pressAndSettle(30);
    pressAndSettle(30);
    pressAndSettle(13);
    // Run the app's real sweep with its defaults (A=0x89, B=0x33, C=0x22,
    // expected=0xBC). The emulator models the same 0x780080 MMIO counter as
    // compiler_fsm.v, so the screen is OS output rather than an HTML overlay.
    pressAndSettle(13, COMPILER_SETTLE_INSTR);
    compilerDemo = true;
  }

  function frame() {
    if (!running) return;
    requestAnimationFrame(frame);
    if (document.hidden || !visible) return;
    while (keyQueue.length > 0 && !cpu.kbReady) cpu.key(keyQueue.shift());
    if (keyQueue.length > 32) keyQueue.splice(0, keyQueue.length - 32);
    const start = performance.now();
    let n = 0;
    while (!cpu.halted && n < FRAME_INSTR_CAP && performance.now() - start < FRAME_BUDGET_MS) {
      const chunk = Math.min(4096, FRAME_INSTR_CAP - n);
      cpu.step(chunk);
      n += chunk;
    }
    steps += n;
    paintDirty(cpu, image, imgData, ctx);
    status();
  }

  document.addEventListener("keydown", (e) => {
    if (!running || !figure.contains(document.activeElement)) return;
    if (KEYMAP[e.key] !== undefined) {
      e.preventDefault();
      if (!e.repeat) keyQueue.push(KEYMAP[e.key]);
    }
  });

  figure.querySelectorAll("[data-key]").forEach((b) => {
    b.addEventListener("click", () => {
      keyQueue.push(Number(b.dataset.key));
      canvas.focus();
    });
  });

  async function start() {
    play.disabled = true;
    play.hidden = true;
    statusEl.textContent = "Loading firmware image…";
    try {
      const res = await fetch("data/tomato-os.bin");
      if (!res.ok) throw new Error(`firmware image missing (${res.status})`);
      image = loadImage(await res.arrayBuffer());
      cpu = new Tomato(image);
      statusEl.textContent = "Booting Tomato OS…";
      await new Promise((r) => setTimeout(r, 30));
      cpu.step(BOOT_INSTR);
      steps += BOOT_INSTR;
      openCompilerDemo();
      paintFull(cpu, image, imgData, ctx);
      play.hidden = true;
      running = true;
      status();
      requestAnimationFrame(frame);
    } catch (err) {
      statusEl.textContent = `Could not start: ${err.message}`;
      play.disabled = false;
      play.hidden = false;
    }
  }

  play.addEventListener("click", start);
  start();
}
