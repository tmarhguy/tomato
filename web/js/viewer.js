/* Light 07_alu viewer: one tour, demand-render. */
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import {
  applyMaskPeel,
  collectPcbLayers,
  lightPcbScene,
  loadFittedPcb,
  studioEnv,
} from "./pcb-look.js";

const GLB = "assets/pcb/alu.glb";
const IN_S = 1;
const PATH_S = 20;
const coarse =
  (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches) ||
  navigator.maxTouchPoints > 0;

function isHand() {
  return (
    (typeof matchMedia === "function" && matchMedia("(max-width: 860px)").matches) ||
    (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches)
  );
}

const canvas = document.getElementById("viewer-canvas");
const boot = document.getElementById("boot");
const bootText = document.getElementById("boot-text");
const tourLine = document.getElementById("tour-line");
const tourKicker = document.getElementById("tour-kicker");
const tourCaption = document.getElementById("tour-caption");
const tourHint = document.getElementById("tour-hint");
const tourRail = document.getElementById("tour-rail");
const tourRailFill = document.getElementById("tour-rail-fill");

{
  const w = Math.max(1, canvas.clientWidth | 0);
  const h = Math.max(1, canvas.clientHeight | 0);
  canvas.width = w;
  canvas.height = h;
}

const _pos = new THREE.Vector3();
const _tgt = new THREE.Vector3();
const _up = new THREE.Vector3(0, 1, 0);

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x050505);

const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 200);
const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: true,
  alpha: false,
  depth: true,
  powerPreference: "high-performance",
  stencil: false,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.92;
renderer.setClearColor(0x050505, 1);
renderer.setSize(canvas.width, canvas.height, false);

const lights = lightPcbScene(scene, { hemiIntensity: 0.6 });
const keyBase = lights.key.intensity;

const controls = new OrbitControls(camera, canvas);
controls.enableDamping = false;
controls.autoRotate = !coarse;
controls.autoRotateSpeed = -1.8;
controls.rotateSpeed = 1;
controls.zoomSpeed = 1;
controls.panSpeed = 1;
controls.zoomToCursor = !coarse;
controls.screenSpacePanning = true;
controls.minPolarAngle = 0.05;
controls.maxPolarAngle = Math.PI - 0.05;
controls.mouseButtons.LEFT = THREE.MOUSE.ROTATE;
controls.mouseButtons.MIDDLE = THREE.MOUSE.DOLLY;
controls.mouseButtons.RIGHT = THREE.MOUSE.PAN;
controls.touches.ONE = THREE.TOUCH.ROTATE;
controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;
canvas.style.touchAction = "none";

function lockPageZoom() {
  const block = (e) => e.preventDefault();
  document.addEventListener("gesturestart", block, { passive: false });
  document.addEventListener("gesturechange", block, { passive: false });
  document.addEventListener("gestureend", block, { passive: false });
}
lockPageZoom();

let look = new THREE.Vector3();
let maxDim = 10;
let boardTop = 0.5;
let spanX = 10;
let spanZ = 10;
let pcbLayers = null;
let pcbRoot = null;
let anim = null;
let tour = null;
let pageVisible = true;
let dirty = true;
let raf = 0;
const clock = new THREE.Clock();

function easeInOut(u) {
  return u < 0.5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2;
}

function easeOutCubic(u) {
  return 1 - (1 - u) ** 3;
}

function smoother01(t) {
  t = THREE.MathUtils.clamp(t, 0, 1);
  return t * t * t * (t * (t * 6 - 15) + 10);
}

function speedAt(u) {
  const e = 0.12;
  const rise = u < e ? smoother01(u / e) : 1;
  const idle = 0.35;
  const fall =
    u > 1 - e ? THREE.MathUtils.lerp(1, idle, smoother01((u - (1 - e)) / e)) : 1;
  return rise * fall;
}

const CRUISE = new Float32Array(257);
{
  let acc = 0;
  CRUISE[0] = 0;
  for (let i = 1; i <= 256; i++) {
    acc += 0.5 * (speedAt((i - 1) / 256) + speedAt(i / 256));
    CRUISE[i] = acc;
  }
  const total = CRUISE[256] || 1;
  for (let i = 0; i <= 256; i++) CRUISE[i] /= total;
}

function cruise(u) {
  const x = THREE.MathUtils.clamp(u, 0, 1) * 256;
  const i = x | 0;
  const f = x - i;
  return CRUISE[i] + (CRUISE[Math.min(i + 1, 256)] - CRUISE[i]) * f;
}

function buildTourCurve() {
  const z = window.innerWidth <= 860 ? 1.35 : 1;
  const d = maxDim * z;
  const span = Math.max(spanX, spanZ) * z;
  return {
    cx: look.x,
    cz: look.z,
    th0: -0.2,
    th1: Math.PI / 4 - Math.PI / 2 - Math.PI * 2,
    yTop: look.y + d * 1.95,
    yClose: boardTop + d * 0.26,
    yHome: look.y + d * 1.45,
    rStart: span * 0.34,
    rClose: span * 0.42,
    rHome: d * Math.SQRT2,
    rLook: span * 0.32,
  };
}

function sampleTour(path, u, pos, tgt) {
  const s = cruise(u);
  const down = smoother01(THREE.MathUtils.clamp(s / 0.28, 0, 1));
  const up = smoother01(THREE.MathUtils.clamp((s - 0.78) / 0.22, 0, 1));
  const th = THREE.MathUtils.lerp(path.th0, path.th1, s);
  const y = THREE.MathUtils.lerp(THREE.MathUtils.lerp(path.yTop, path.yClose, down), path.yHome, up);
  const r = THREE.MathUtils.lerp(THREE.MathUtils.lerp(path.rStart, path.rClose, down), path.rHome, up);
  pos.set(path.cx + r * Math.cos(th), y, path.cz + r * Math.sin(th));

  const closeAmt = Math.min(down, 1 - up);
  const lead = 0.4 * closeAmt * Math.sign(path.th1 - path.th0);
  const rTgt = THREE.MathUtils.lerp(0, path.rLook, closeAmt);
  tgt.set(
    path.cx + rTgt * Math.cos(th + lead),
    THREE.MathUtils.lerp(look.y, boardTop * 0.5, closeAmt),
    path.cz + rTgt * Math.sin(th + lead)
  );
  return THREE.MathUtils.lerp(45, 46, closeAmt);
}

function applyLook(pos, tgt, fov) {
  camera.position.copy(pos);
  camera.up.copy(_up);
  camera.lookAt(tgt);
  if (fov != null && Math.abs(camera.fov - fov) > 0.01) {
    camera.fov = fov;
    camera.updateProjectionMatrix();
  }
  controls.target.copy(tgt);
}

function lockRig() {
  controls.enabled = false;
  controls.enableDamping = false;
  controls.autoRotate = false;
}

function unlockRig(spin) {
  camera.up.copy(_up);
  controls.enabled = true;
  controls.enableDamping = false;
  controls.autoRotate = spin ?? !coarse;
  controls.update();
}

function views() {
  const d = maxDim * (window.innerWidth <= 860 ? 1.5 : 1);
  return {
    reset: { pos: new THREE.Vector3(look.x + d, look.y + d * 1.45, look.z + d), fov: 45 },
    top: { pos: new THREE.Vector3(look.x, look.y + d * 2.2, look.z + d * 0.02), fov: 45 },
    iso: { pos: new THREE.Vector3(look.x + d * 1.45, look.y + d * 1.45, look.z + d * 1.45), fov: 45 },
    side: { pos: new THREE.Vector3(look.x + d * 2.1, look.y + d * 0.35, look.z), fov: 42 },
    bottom: { pos: new THREE.Vector3(look.x, look.y - d * 1.55, look.z + d * 0.35), fov: 38 },
  };
}

let currentView = "reset";

function syncViewChips() {
  document.querySelectorAll("#view-bar [data-view]").forEach((btn) => {
    const name = btn.getAttribute("data-view");
    if (name === "spin") return;
    btn.classList.toggle("is-on", name === currentView && name !== "reset");
  });
}

function dollyIn(ms = 700) {
  stopTour(false);
  lockRig();
  const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
  const dist = dir.length();
  const next = Math.max(controls.minDistance, dist * 0.62);
  if (Math.abs(next - dist) < 1e-4) {
    unlockRig(false);
    return;
  }
  dir.setLength(next);
  currentView = "";
  syncViewChips();
  anim = {
    fromP: camera.position.clone(),
    fromT: controls.target.clone(),
    fromF: camera.fov,
    toP: controls.target.clone().add(dir),
    toT: controls.target.clone(),
    toF: camera.fov,
    t0: performance.now(),
    ms,
    ease: easeOutCubic,
  };
  dirty = true;
  kick();
}

function go(name, ms = 800) {
  stopTour(false);
  lockRig();
  const v = views()[name];
  if (!v) {
    unlockRig();
    return;
  }
  currentView = name;
  syncViewChips();
  anim = {
    fromP: camera.position.clone(),
    fromT: controls.target.clone(),
    fromF: camera.fov,
    toP: v.pos,
    toT: look.clone(),
    toF: v.fov,
    t0: performance.now(),
    ms,
  };
  dirty = true;
  kick();
}

function setPlaying(on) {
  document.body.classList.toggle("is-playing", on);
  if (tourLine) tourLine.hidden = true;
  if (tourHint) tourHint.hidden = !on;
  if (tourRail) tourRail.hidden = !on;
  if (!on && tourRailFill) tourRailFill.style.width = "0%";
}

function peelLift() {
  return (0.09 * maxDim) / (pcbRoot?.scale?.x || 1);
}

function resetPeel() {
  if (pcbLayers) applyMaskPeel(pcbLayers, 0, peelLift());
  lights.key.intensity = keyBase;
}

function stopTour(resume = false) {
  if (!tour) return;
  tour = null;
  resetPeel();
  setPlaying(false);
  unlockRig(resume);
  dirty = true;
  kick();
}

function startTour() {
  anim = null;
  lockRig();
  const curve = buildTourCurve();
  const fov0 = sampleTour(curve, 0, _pos, _tgt);
  setPlaying(true);
  tour = {
    phase: "in",
    t0: performance.now() / 1000,
    curve,
    paused: false,
    fromP: camera.position.clone(),
    fromT: controls.target.clone(),
    fromF: camera.fov,
    toP: _pos.clone(),
    toT: _tgt.clone(),
    toF: fov0,
  };
  dirty = true;
  kick();
}

function stepTour(now) {
  if (tour.phase === "in") {
    const u = Math.min(1, (now - tour.t0) / IN_S);
    const e = easeInOut(u);
    _pos.lerpVectors(tour.fromP, tour.toP, e);
    _tgt.lerpVectors(tour.fromT, tour.toT, e);
    applyLook(_pos, _tgt, THREE.MathUtils.lerp(tour.fromF, tour.toF, e));
    if (u >= 1) {
      tour.phase = "path";
      tour.t0 = now;
    }
    return;
  }

  if (tour.phase === "path") {
    const u = tour.paused ? tour.u ?? 0 : Math.min(1, (now - tour.t0) / PATH_S);
    tour.u = u;
    const fov = sampleTour(tour.curve, u, _pos, _tgt);
    applyLook(_pos, _tgt, fov);
    if (tourRailFill) tourRailFill.style.width = `${(u * 100).toFixed(2)}%`;
    if (u >= 1) {
      stopTour(true);
      controls.update();
    }
  }
}

function looping() {
  return !!(anim || (tour && !tour.paused) || controls.autoRotate);
}

function kick() {
  if (raf || !pageVisible) return;
  raf = requestAnimationFrame(tick);
}

function tick() {
  raf = 0;
  if (!pageVisible) return;
  const now = performance.now();

  if (anim) {
    const u = Math.min(1, (now - anim.t0) / anim.ms);
    const e = (anim.ease || easeInOut)(u);
    _pos.lerpVectors(anim.fromP, anim.toP, e);
    _tgt.lerpVectors(anim.fromT, anim.toT, e);
    applyLook(_pos, _tgt, THREE.MathUtils.lerp(anim.fromF, anim.toF, e));
    if (u >= 1) {
      anim = null;
      unlockRig(false);
    }
    dirty = true;
  } else if (tour && !tour.paused) {
    stepTour(now / 1000);
    dirty = true;
  } else if (controls.autoRotate) {
    controls.update();
  }

  if (dirty) {
    dirty = false;
    renderer.render(scene, camera);
  }
  if (looping()) kick();
}

function abortTour() {
  if (tour) stopTour(false);
}

function resize() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (!w || !h) return;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h, false);
  dirty = true;
  kick();
}

function yieldToPointer() {
  if (tour) abortTour();
}

new ResizeObserver(resize).observe(canvas);
resize();

controls.addEventListener("change", () => {
  dirty = true;
  kick();
});
controls.addEventListener("start", () => {
  controls.autoRotate = false;
  currentView = "";
  syncViewChips();
  syncSpinChip();
});

canvas.addEventListener("pointerdown", yieldToPointer, { capture: true });
canvas.addEventListener("wheel", yieldToPointer, { capture: true, passive: true });
canvas.addEventListener("touchstart", yieldToPointer, { capture: true, passive: true });

if (tourRail) {
  tourRail.addEventListener("pointerdown", (e) => {
    if (!tour) return;
    e.stopPropagation();
    const r = tourRail.getBoundingClientRect();
    const u = THREE.MathUtils.clamp((e.clientX - r.left) / r.width, 0, 1);
    tour.phase = "path";
    tour.u = u;
    tour.t0 = performance.now() / 1000 - u * PATH_S;
    tour.paused = false;
    dirty = true;
    kick();
  });
}

document.addEventListener("visibilitychange", () => {
  pageVisible = !document.hidden;
  if (pageVisible) {
    dirty = true;
    kick();
  }
});

document.getElementById("legend-btn").addEventListener("click", () => {
  const desk = document.getElementById("legend");
  const hand = document.getElementById("legend-hand");
  const panel = isHand() ? hand : desk;
  const other = isHand() ? desk : hand;
  if (other) other.hidden = true;
  const open = panel.hidden;
  panel.hidden = !open;
  const btn = document.getElementById("legend-btn");
  btn.setAttribute("aria-expanded", String(open));
  btn.classList.toggle("is-on", open);
});

document.getElementById("immerse").addEventListener("click", startTour);

function syncSpinChip() {
  const btn = document.querySelector('[data-view="spin"]');
  if (btn) {
    btn.textContent = controls.autoRotate ? "Hold" : "Spin";
    btn.classList.toggle("is-on", controls.autoRotate);
  }
}

document.getElementById("view-bar")?.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-view]");
  if (!btn) return;
  const name = btn.getAttribute("data-view");
  if (name === "spin") {
    if (tour) {
      tour.paused = !tour.paused;
      if (!tour.paused && tour.phase === "path") {
        tour.t0 = performance.now() / 1000 - (tour.u ?? 0) * PATH_S;
      }
    } else {
      controls.autoRotate = !controls.autoRotate;
    }
    syncSpinChip();
    dirty = true;
    kick();
    return;
  }
  go(name);
});

let ptrDownX = 0;
let ptrDownY = 0;
let ptrDownT = 0;
let tapTimer = 0;
let taps = 0;
let tapReset = false;

canvas.addEventListener("pointerdown", (e) => {
  ptrDownX = e.clientX;
  ptrDownY = e.clientY;
  ptrDownT = performance.now();
}, { capture: true });

canvas.addEventListener("pointerup", (e) => {
  if (!isHand()) return;
  const dt = performance.now() - ptrDownT;
  const dx = e.clientX - ptrDownX;
  const dy = e.clientY - ptrDownY;
  if (dt > 400 || dx * dx + dy * dy > 100) {
    taps = 0;
    tapReset = false;
    return;
  }
  taps += 1;
  clearTimeout(tapTimer);
  if (taps >= 3) {
    if (tapReset && anim?.fromP) {
      applyLook(anim.fromP, anim.fromT, anim.fromF);
      anim = null;
    }
    tapReset = false;
    dollyIn();
    taps = 0;
    return;
  }
  if (taps === 2) {
    tapReset = true;
    go("reset");
    tapTimer = setTimeout(() => {
      taps = 0;
      tapReset = false;
    }, 280);
    return;
  }
  tapTimer = setTimeout(() => {
    if (taps === 1) {
      if (tour) {
        tour.paused = !tour.paused;
        if (!tour.paused && tour.phase === "path") {
          tour.t0 = performance.now() / 1000 - (tour.u ?? 0) * PATH_S;
        }
      } else {
        controls.autoRotate = !controls.autoRotate;
      }
      syncSpinChip();
      dirty = true;
      kick();
    }
    taps = 0;
  }, 280);
});

window.addEventListener("keydown", (e) => {
  if (e.target.closest("input, textarea")) return;
  const k = e.key.toLowerCase();

  if (k === "escape") {
    if (tour) {
      e.preventDefault();
      abortTour();
    }
    return;
  }

  if (k === "i") {
    e.preventDefault();
    if (tour) abortTour();
    else startTour();
    return;
  }

  if (k === " ") {
    e.preventDefault();
    if (tour) {
      tour.paused = !tour.paused;
      if (!tour.paused && tour.phase === "path") {
        tour.t0 = performance.now() / 1000 - (tour.u ?? 0) * PATH_S;
      }
    } else controls.autoRotate = !controls.autoRotate;
    dirty = true;
    kick();
    return;
  }

  if (k === "1") go("top");
  if (k === "2") go("iso");
  if (k === "3") go("side");
  if (k === "r") go("reset");
});

try {
  bootText.textContent = "Loading…";
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));

  const fitted = await loadFittedPcb(GLB, renderer, (xhr) => {
    if (xhr.total > 0) bootText.textContent = `${Math.round((xhr.loaded / xhr.total) * 100)}%`;
  });
  const model = fitted.model;
  look = fitted.look;
  maxDim = fitted.maxDim;
  boardTop = fitted.boardTop;
  spanX = fitted.spanX;
  spanZ = fitted.spanZ;
  pcbRoot = model;
  pcbLayers = collectPcbLayers(model);
  scene.add(model);

  const grid = new THREE.GridHelper(maxDim * 5, 40, 0x1a1a1a, 0x111111);
  grid.position.set(look.x, 0, look.z);
  scene.add(grid);

  scene.environment = studioEnv(renderer);
  scene.environmentIntensity = 0.4;
  renderer.setClearColor(0x050505, 1);

  controls.minDistance = maxDim * 0.35;
  controls.maxDistance = maxDim * 5;
  controls.target.copy(look);
  camera.near = maxDim * 0.003;
  camera.far = maxDim * 30;
  const home = views().reset;
  camera.position.copy(home.pos);
  camera.fov = home.fov;
  camera.updateProjectionMatrix();
  controls.update();

  renderer.render(scene, camera);
  document.body.classList.add("is-ready");
  boot.classList.add("is-gone");
  dirty = false;
  clock.getDelta();
  syncSpinChip();
  syncViewChips();
  kick();
} catch (err) {
  console.error(err);
  boot.innerHTML = `<p class="err">The GLB did not load. Serve the paper over http, not file://.</p>`;
}
