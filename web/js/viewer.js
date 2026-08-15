/* Light 07_alu viewer: merge KiCad's 40k primitives, demand-render, stay off the copper. */
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { dressPcbMaterials, lightPcbScene } from "./pcb-look.js";

const GLB = "assets/pcb/alu.glb";
const IN_S = 1;
const PATH_S = 20;

function smoother01(t) {
  t = THREE.MathUtils.clamp(t, 0, 1);
  return t * t * t * (t * (t * 6 - 15) + 10);
}

function speedAt(u) {
  const e = 0.12;
  const rise = u < e ? smoother01(u / e) : 1;
  // Hand off into idle spin: ease toward ~autoRotate rate, never to a stop.
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

const coarse =
  (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches) ||
  navigator.maxTouchPoints > 0;

function thinnestAxis(size) {
  if (size.x <= size.y && size.x <= size.z) return new THREE.Vector3(1, 0, 0);
  if (size.y <= size.x && size.y <= size.z) return new THREE.Vector3(0, 1, 0);
  return new THREE.Vector3(0, 0, 1);
}

function easeInOut(u) {
  return u < 0.5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2;
}

function bakeGeo(mesh) {
  const src = mesh.geometry.clone();
  src.applyMatrix4(mesh.matrixWorld);
  for (const name of Object.keys(src.attributes)) {
    if (name !== "position" && name !== "normal") src.deleteAttribute(name);
  }
  src.morphAttributes = {};
  if (!src.getAttribute("position")?.count) {
    src.dispose();
    return null;
  }
  if (!src.attributes.normal) src.computeVertexNormals();
  return src;
}

function mergeByMaterial(root) {
  root.updateMatrixWorld(true);
  const buckets = new Map();
  const old = [];
  root.traverse((child) => {
    if (!child.isMesh) return;
    old.push(child);
    const mat = Array.isArray(child.material) ? child.material[0] : child.material;
    if (!mat) return;
    const geo = bakeGeo(child);
    if (!geo) return;
    const key = mat.uuid;
    if (!buckets.has(key)) buckets.set(key, { material: mat, geos: [] });
    buckets.get(key).geos.push(geo);
  });

  const group = new THREE.Group();
  for (const { material, geos } of buckets.values()) {
    if (!geos.length) continue;
    const mixed = geos.some((g) => g.index) && geos.some((g) => !g.index);
    const list = mixed
      ? geos.map((g) => {
          if (!g.index) return g;
          const n = g.toNonIndexed();
          g.dispose();
          return n;
        })
      : geos;
    let acc = list[0];
    for (let i = 1; i < list.length; i += 256) {
      const slice = list.slice(i, i + 256);
      const next = mergeGeometries([acc, ...slice], false);
      acc.dispose();
      slice.forEach((g) => g.dispose());
      acc = next;
      if (!acc) break;
    }
    if (!acc) continue;
    acc.computeBoundingSphere();
    const mesh = new THREE.Mesh(acc, material);
    mesh.frustumCulled = true;
    group.add(mesh);
  }
  old.forEach((mesh) => {
    mesh.geometry.dispose();
    mesh.removeFromParent();
  });
  return group;
}

function fitBoard(model) {
  model.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  model.position.sub(center);

  const maxDim = Math.max(size.x, size.y, size.z) || 1;
  model.scale.setScalar(10 / maxDim);
  model.updateMatrixWorld(true);

  const fitted = new THREE.Box3().setFromObject(model);
  const n = thinnestAxis(fitted.getSize(new THREE.Vector3()));
  model.quaternion.premultiply(new THREE.Quaternion().setFromUnitVectors(n, new THREE.Vector3(0, 1, 0)));
  model.updateMatrixWorld(true);

  const seated = new THREE.Box3().setFromObject(model);
  model.position.y -= seated.min.y;
  model.updateMatrixWorld(true);

  const world = new THREE.Box3().setFromObject(model);
  const worldSize = world.getSize(new THREE.Vector3());
  return {
    look: world.getCenter(new THREE.Vector3()),
    maxDim: Math.max(worldSize.x, worldSize.z, worldSize.y) || 10,
    boardTop: world.max.y,
    spanX: worldSize.x,
    spanZ: worldSize.z,
  };
}

function studioEnv(renderer) {
  const pmrem = new THREE.PMREMGenerator(renderer);
  return pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
}

const _pos = new THREE.Vector3();
const _tgt = new THREE.Vector3();
const _up = new THREE.Vector3(0, 1, 0);

function buildTourCurve() {
  const d = maxDim;
  const span = Math.max(spanX, spanZ);
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
  controls.enableDamping = true;
  controls.autoRotate = spin ?? !coarse;
  controls.update();
}

const canvas = document.getElementById("viewer-canvas");
const boot = document.getElementById("boot");
const bootText = document.getElementById("boot-text");
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x050505);

const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 200);
const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: !coarse,
  alpha: false,
  stencil: false,
  depth: true,
  logarithmicDepthBuffer: !coarse,
  powerPreference: "high-performance",
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, coarse ? 1 : 1.15));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.92;

const { hemi } = lightPcbScene(scene, { hemiIntensity: 0.12 });

const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = coarse ? 0.14 : 0.08;
controls.autoRotate = !coarse;
controls.autoRotateSpeed = -0.9;
controls.rotateSpeed = coarse ? 0.65 : 0.9;
controls.zoomSpeed = coarse ? 0.8 : 1;
controls.panSpeed = coarse ? 0.5 : 0.8;
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

let look = new THREE.Vector3();
let maxDim = 10;
let boardTop = 0.5;
let spanX = 10;
let spanZ = 10;
let grid = null;
let anim = null;
let tour = null;
let lastInput = 0;
let pageVisible = true;
let dirty = true;
const clock = new THREE.Clock();

function views() {
  const d = maxDim;
  return {
    reset: { pos: new THREE.Vector3(look.x + d, look.y + d * 1.45, look.z + d), fov: 45 },
    top: { pos: new THREE.Vector3(look.x, look.y + d * 2.2, look.z + d * 0.02), fov: 45 },
    iso: { pos: new THREE.Vector3(d * 1.45, d * 1.45, d * 1.45), fov: 45 },
    side: { pos: new THREE.Vector3(look.x + d * 2.1, look.y + d * 0.35, look.z), fov: 42 },
  };
}

function go(name, ms = 800) {
  stopTour(false);
  lockRig();
  const v = views()[name];
  if (!v) {
    unlockRig();
    return;
  }
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
}

function setPlaying(on) {
  document.body.classList.toggle("is-playing", on);
}

function stopTour(resume = true) {
  if (!tour) return;
  tour = null;
  setPlaying(false);
  unlockRig(resume ? !coarse : false);
  dirty = true;
}

function startTour(fromTop = false) {
  anim = null;
  lockRig();
  const curve = buildTourCurve();
  const fov0 = sampleTour(curve, 0, _pos, _tgt);
  setPlaying(true);
  dirty = true;

  if (fromTop) {
    applyLook(_pos, _tgt, fov0);
    tour = { phase: "path", t0: performance.now() / 1000, curve };
    return;
  }

  tour = {
    phase: "in",
    t0: performance.now() / 1000,
    curve,
    fromP: camera.position.clone(),
    fromT: controls.target.clone(),
    fromF: camera.fov,
    toP: _pos.clone(),
    toT: _tgt.clone(),
    toF: fov0,
  };
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
    const u = Math.min(1, (now - tour.t0) / PATH_S);
    const fov = sampleTour(tour.curve, u, _pos, _tgt);
    applyLook(_pos, _tgt, fov);
    if (u >= 1) {
      stopTour(true);
      controls.update();
    }
  }
}

function resize() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (!w || !h) return;
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  renderer.setSize(w, h, false);
  dirty = true;
}

new ResizeObserver(resize).observe(canvas);
resize();

function tick() {
  requestAnimationFrame(tick);
  if (!pageVisible) return;
  const dt = Math.min(clock.getDelta(), 0.05);
  const now = performance.now();
  const busy = controls.autoRotate || tour || anim || now - lastInput < 420;
  if (!busy && !dirty) return;
  dirty = false;

  if (anim) {
    const u = Math.min(1, (now - anim.t0) / anim.ms);
    const e = easeInOut(u);
    _pos.lerpVectors(anim.fromP, anim.toP, e);
    _tgt.lerpVectors(anim.fromT, anim.toT, e);
    applyLook(_pos, _tgt, THREE.MathUtils.lerp(anim.fromF, anim.toF, e));
    if (u >= 1) {
      anim = null;
      unlockRig(false);
    }
  } else if (tour) {
    stepTour(now / 1000);
  } else {
    controls.update();
  }

  renderer.render(scene, camera);
}

function abortTour() {
  if (tour) stopTour(false);
}

controls.addEventListener("change", () => {
  lastInput = performance.now();
  dirty = true;
});
controls.addEventListener("start", () => {
  lastInput = performance.now();
  abortTour();
  controls.autoRotate = false;
});
canvas.addEventListener("pointerdown", abortTour);
canvas.addEventListener("wheel", abortTour, { passive: true });
canvas.addEventListener("touchstart", abortTour, { passive: true });

document.addEventListener("visibilitychange", () => {
  pageVisible = !document.hidden;
  if (pageVisible) dirty = true;
});

document.getElementById("legend-btn").addEventListener("click", () => {
  const panel = document.getElementById("legend");
  const open = panel.hidden;
  panel.hidden = !open;
  document.getElementById("legend-btn").setAttribute("aria-expanded", String(open));
});

const HEMI_KEY = "tomato.viewer.hemi.v2";
const hemiSlider = document.getElementById("hemi");
const hemiVal = document.getElementById("hemi-val");

function setHemi(v) {
  const n = THREE.MathUtils.clamp(Number(v), 0, 4);
  hemi.intensity = n;
  hemiSlider.value = String(n);
  hemiVal.textContent = n.toFixed(2);
  try { localStorage.setItem(HEMI_KEY, String(n)); } catch {}
  dirty = true;
}

{
  let start = 0.12;
  try {
    const saved = localStorage.getItem(HEMI_KEY);
    if (saved != null) start = Number(saved);
  } catch {}
  setHemi(Number.isFinite(start) ? start : 0.12);
}
hemiSlider.addEventListener("input", () => setHemi(hemiSlider.value));

document.getElementById("immerse").addEventListener("click", startTour);

window.addEventListener("keydown", (e) => {
  if (e.target.closest("input, textarea")) return;
  const k = e.key.toLowerCase();
  if (tour && k !== "i") {
    abortTour();
    if (k === "escape" || k === " ") e.preventDefault();
  }
  if (e.key === "[" || e.key === "]") {
    e.preventDefault();
    setHemi(hemi.intensity + (e.key === "]" ? 0.1 : -0.1));
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
    controls.autoRotate = !controls.autoRotate;
    dirty = true;
  }
  if (k === "1") go("top");
  if (k === "2") go("iso");
  if (k === "3") go("side");
  if (k === "r") go("reset");
});

try {
  scene.environment = studioEnv(renderer);
  scene.environmentIntensity = 0.4;
  bootText.textContent = "Brewing ALU…";
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  const gltf = await new GLTFLoader().loadAsync(GLB);
  const model = mergeByMaterial(gltf.scene);
  gltf.scene.traverse((child) => {
    if (child.geometry) child.geometry.dispose?.();
  });
  dressPcbMaterials(model);
  const fitted = fitBoard(model);
  look = fitted.look;
  maxDim = fitted.maxDim;
  boardTop = fitted.boardTop;
  spanX = fitted.spanX;
  spanZ = fitted.spanZ;
  scene.add(model);

  grid = new THREE.GridHelper(maxDim * 5, 40, 0x1a1a1a, 0x111111);
  grid.position.y = 0;
  scene.add(grid);

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

  boot.classList.add("is-gone");
  lastInput = performance.now();
  dirty = true;
  clock.getDelta();
  tick();
} catch (err) {
  console.error(err);
  boot.innerHTML = `<p class="err">The GLB did not load. Serve the paper over http, not file://.</p>`;
}
