/* Virtual board UI: runs the shipped firmware in this tab.
 *
 * No backend. The engine is js/tomato-cpu.js (a functional Tomato CPU that
 * boots web/data/tomato-os.bin, the repacked OS image). This file owns the
 * DOM only: canvas renderer (same algorithm as tools/virtual_tomato.html),
 * D-pad + keyboard, demo-phone panel, and the run loop.
 *
 * Honesty label lives in virtual.html: behavior, not timing. The RTL sims
 * and the FPGA remain ground truth; web/tests/tomato-emu.mjs replays
 * scripted sessions through the same core file this page loads.
 */
import { Tomato, loadImage } from "./tomato-cpu.js?v=47cc72f7";
import { paintDirty, paintFull } from "./tomato-screen.js?v=a9760af7";

const BOOT_INSTR = 200000;
const FRAME_BUDGET_MS = 8;
const FRAME_INSTR_CAP = 60000;

const canvas = document.querySelector("#vt-screen");
const ctx = canvas.getContext("2d", { alpha: false });
const imgData = ctx.createImageData(640, 480);
const statsEl = document.querySelector("#vt-stats");
const noticeEl = document.querySelector("#vt-notice");
const fwEl = document.querySelector("#vt-firmware");

let image = null;
let cpu = null;
let paused = false;
let keyQueue = [];
let steps = 0;

function renderFull() {
  paintFull(cpu, image, imgData, ctx);
}

function renderDirty() {
  paintDirty(cpu, image, imgData, ctx);
}

function status() {
  const phone = cpu.radio.attached ? "Demo phone connected" : "Phone disconnected";
  const run = cpu.halted ? "CPU halted" : "CPU running";
  statsEl.textContent = `${run} · ${phone} · ${steps} steps`;
}

function pumpKeys() {
  while (keyQueue.length > 0 && !cpu.kbReady) {
    cpu.key(keyQueue.shift());
  }
  if (keyQueue.length > 32) keyQueue.splice(0, keyQueue.length - 32);
}

function frame() {
  requestAnimationFrame(frame);
  if (!cpu || (paused && keyQueue.length === 0)) return;
  pumpKeys();
  const start = performance.now();
  let n = 0;
  while (!cpu.halted && n < FRAME_INSTR_CAP && performance.now() - start < FRAME_BUDGET_MS) {
    const chunk = Math.min(4096, FRAME_INSTR_CAP - n);
    cpu.step(chunk);
    n += chunk;
  }
  steps += n;
  pumpKeys();
  renderDirty();
  status();
}

const KEYMAP = { ArrowUp: 30, ArrowDown: 31, ArrowLeft: 17, ArrowRight: 16, Enter: 13 };

function bind() {
  document.addEventListener("keydown", (e) => {
    const tag = e.target && e.target.tagName;
    if (tag === "INPUT" || tag === "SELECT" || tag === "BUTTON" || tag === "TEXTAREA") return;
    if (KEYMAP[e.key] !== undefined) {
      e.preventDefault();
      if (!e.repeat) keyQueue.push(KEYMAP[e.key]);
    }
  });
  document.querySelectorAll("[data-key]").forEach((b) => {
    b.addEventListener("pointerdown", (e) => {
      if (e.pointerType === "mouse" && e.button !== 0) return;
      e.preventDefault();
      keyQueue.push(Number(b.dataset.key));
      canvas.focus();
    });
  });
  document.querySelector(".vt-pad")?.addEventListener("dblclick", (e) => e.preventDefault());
  document.querySelector("#vt-pause").addEventListener("click", (e) => {
    paused = !paused;
    e.target.textContent = paused ? "Resume" : "Pause";
    canvas.focus();
  });
  document.querySelector("#vt-reset").addEventListener("click", () => {
    keyQueue = [];
    cpu.reset();
    cpu.step(BOOT_INSTR);
    steps += BOOT_INSTR;
    renderFull();
    status();
    canvas.focus();
  });
  document.querySelector("#vt-demo").addEventListener("click", () => {
    cpu.demo();
    canvas.focus();
  });
  document.querySelector("#vt-disconnect").addEventListener("click", () => {
    cpu.disconnect();
    canvas.focus();
  });
  document.querySelector("#vt-add-contact").addEventListener("click", () => {
    const name = document.querySelector("#vt-contact-name").value;
    if (!cpu.contact(4, name)) {
      noticeEl.textContent = "Connect the demo phone first; names are 1–32 printable ASCII.";
    } else noticeEl.textContent = "";
    canvas.focus();
  });
  document.querySelector("#vt-send").addEventListener("click", () => {
    const route = Number(document.querySelector("#vt-route").value);
    const text = document.querySelector("#vt-message").value;
    if (!cpu.message(route, text)) {
      noticeEl.textContent = "Connect the demo phone first; messages are 1–256 printable ASCII.";
    } else noticeEl.textContent = "";
    canvas.focus();
  });
  const stage = document.querySelector("#vt-stage");
  const fullBtn = document.querySelector("#vt-fullscreen");
  const hideBtn = document.querySelector("#vt-hide");
  if (!document.fullscreenEnabled) fullBtn.disabled = true;
  fullBtn.addEventListener("click", async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await stage.requestFullscreen();
    } catch (err) {
      noticeEl.textContent = `Fullscreen unavailable: ${err.message}`;
    }
    canvas.focus();
  });
  document.addEventListener("fullscreenchange", () => {
    fullBtn.textContent = document.fullscreenElement ? "Exit fullscreen" : "Fullscreen";
  });
  hideBtn.addEventListener("click", () => {
    const hidden = stage.classList.toggle("vt-hide-ui");
    hideBtn.textContent = hidden ? "Show controls" : "Hide controls";
    canvas.focus();
  });
}

async function boot() {
  statsEl.textContent = "Loading firmware image…";
  const res = await fetch("data/tomato-os.bin");
  if (!res.ok) throw new Error(`firmware image missing (${res.status})`);
  image = loadImage(await res.arrayBuffer());
  cpu = new Tomato(image);
  fwEl.textContent = `firmware ${image.id}`;
  statsEl.textContent = "Booting Tomato OS…";
  await new Promise((r) => setTimeout(r, 30));
  cpu.step(BOOT_INSTR);
  steps += BOOT_INSTR;
  renderFull();
  status();
  canvas.focus();
  requestAnimationFrame(frame);
}

bind();
boot().catch((e) => {
  noticeEl.textContent = `Could not start the virtual board: ${e.message}`;
  statsEl.textContent = "Offline";
});
