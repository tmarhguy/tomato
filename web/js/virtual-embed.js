/* Homepage embed: automatically boot Tomato OS.
 *
 * Same engine as the full board (js/tomato-cpu.js, same firmware image),
 * smaller chrome: no demo phone, no pause — keyboard works only while focus is
 * inside the figure so page scroll is never hijacked.
 */
import { Tomato, loadImage } from "./tomato-cpu.js?v=47cc72f7";
import { paintDirty, paintFull } from "./tomato-screen.js?v=a9760af7";

const BOOT_INSTR = 200000;
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
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; }, {threshold: 0}).observe(figure);
  const keyQueue = [];

  const KEYMAP = { ArrowUp: 30, ArrowDown: 31, ArrowLeft: 17, ArrowRight: 16, Enter: 13 };

  function status() {
    if (!cpu) return;
    if (cpu.halted) statusEl.textContent = `CPU halted · ${steps} steps`;
    else statusEl.textContent = `Tomato OS Home · Virtual Tomato · ${steps} steps`;
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
    b.addEventListener("pointerdown", (e) => {
      if (e.pointerType === "mouse" && e.button !== 0) return;
      e.preventDefault();
      keyQueue.push(Number(b.dataset.key));
      canvas.focus();
    });
  });
  figure.querySelector(".vt-embed-keys")?.addEventListener("dblclick", (e) => e.preventDefault());

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
