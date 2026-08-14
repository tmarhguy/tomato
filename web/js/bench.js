/* 07_alu playground — lighting and materials match the 8-bit ALU site. */
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

function thinnestAxis(size) {
  if (size.x <= size.y && size.x <= size.z) return new THREE.Vector3(1, 0, 0);
  if (size.y <= size.x && size.y <= size.z) return new THREE.Vector3(0, 1, 0);
  return new THREE.Vector3(0, 0, 1);
}

function easeInOutCubic(u) {
  return u < 0.5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2;
}

const STAGE = 0x3a3a3a;

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
    const chunk = 256;
    for (let i = 1; i < list.length; i += chunk) {
      const slice = list.slice(i, i + chunk);
      const next = mergeGeometries([acc, ...slice], false);
      acc.dispose();
      slice.forEach((g) => g.dispose());
      acc = next;
      if (!acc) break;
    }
    if (!acc) continue;
    acc.computeBoundingSphere();
    group.add(new THREE.Mesh(acc, material));
  }
  old.forEach((mesh) => {
    mesh.geometry.dispose();
    mesh.removeFromParent();
  });
  return group;
}

function dressMaterials(root) {
  root.traverse((child) => {
    if (!child.isMesh) return;
    const list = Array.isArray(child.material) ? child.material : [child.material];
    const next = list.map((material) => {
      if (!material?.isMeshStandardMaterial) return material;
      const m = material.clone();
      const h = { h: 0, s: 0, l: 0 };
      m.color.getHSL(h);
      const seeThrough = m.opacity < 0.99;
      m.transparent = seeThrough;
      m.depthWrite = !seeThrough;
      if (seeThrough) child.renderOrder = 1;
      if (h.l > 0.85 && h.s < 0.15) {
        m.polygonOffset = true;
        m.polygonOffsetFactor = -1;
        child.renderOrder = 2;
      }
      m.envMapIntensity = m.metalness > 0.5 ? 1.1 : 0.7;
      m.needsUpdate = true;
      return m;
    });
    child.material = next.length === 1 ? next[0] : next;
  });
}

async function studioEnv(renderer) {
  const pmrem = new THREE.PMREMGenerator(renderer);
  return pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
}

function isCoarsePointer() {
  return (
    (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches) ||
    (typeof navigator !== "undefined" && navigator.maxTouchPoints > 0)
  );
}

function injectHud(stage) {
  if (stage.querySelector(".bench-hud")) return;
  const mobile = isCoarsePointer();
  const hud = document.createElement("div");
  hud.className = "bench-hud";
  hud.innerHTML = mobile
    ? `
    <button type="button" class="bench-hud-toggle" data-hud="legend" aria-expanded="false">Touch</button>
    <div class="bench-legend" data-hud-panel hidden>
      <p class="bench-legend-row"><span>Orbit</span><kbd>1 finger</kbd></p>
      <p class="bench-legend-row"><span>Zoom</span><kbd>Pinch</kbd></p>
      <p class="bench-legend-row"><span>Pan</span><kbd>2 fingers</kbd></p>
      <p class="bench-legend-row"><span>Reset</span><kbd>Double-tap</kbd></p>
    </div>
  `
    : `
    <button type="button" class="bench-hud-toggle" data-hud="legend" aria-expanded="true">Controls</button>
    <div class="bench-legend" data-hud-panel>
      <p class="bench-legend-row"><span>Turn</span><kbd>Drag</kbd></p>
      <p class="bench-legend-row"><span>Slide</span><kbd>Right-drag</kbd></p>
      <p class="bench-legend-row"><span>Zoom</span><kbd>Scroll</kbd></p>
      <p class="bench-legend-row"><span>Hold</span><kbd>Space</kbd></p>
      <p class="bench-legend-row"><span>Top / Iso / Side</span><kbd>1 2 3</kbd></p>
      <p class="bench-legend-row"><span>Reset / Tour / Grid</span><kbd>R I G</kbd></p>
    </div>
  `;
  const mark = document.createElement("p");
  mark.className = "bench-mark";
  mark.innerHTML = `<span></span> KiCad model`;
  stage.append(hud, mark);
}

export async function mountBench(canvas, opts) {
  const stage = canvas.parentElement;
  if (stage) injectHud(stage);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(STAGE);

  const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 500);
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    powerPreference: "high-performance",
  });
  const mobile = isCoarsePointer();
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, mobile ? 1 : 1.25));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.05;

  scene.environment = await studioEnv(renderer);
  scene.environmentIntensity = 0.8;

  scene.add(new THREE.HemisphereLight(0xf4f4f0, 0x6a655c, 0.75));
  const key = new THREE.DirectionalLight(0xffffff, 1.35);
  key.position.set(10, 18, 8);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xffffff, 0.45);
  fill.position.set(-8, 10, -6);
  scene.add(fill);

  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = mobile ? 0.12 : 0.08;
  controls.autoRotate = !mobile;
  controls.autoRotateSpeed = mobile ? 0.7 : 1.33;
  controls.rotateSpeed = mobile ? 0.65 : 0.9;
  controls.zoomSpeed = mobile ? 0.85 : 1.05;
  controls.panSpeed = mobile ? 0.55 : 0.85;
  controls.zoomToCursor = !mobile;
  controls.enablePan = true;
  controls.screenSpacePanning = true;
  controls.minPolarAngle = 0.05;
  controls.maxPolarAngle = Math.PI - 0.05;
  controls.mouseButtons.LEFT = THREE.MOUSE.ROTATE;
  controls.mouseButtons.MIDDLE = THREE.MOUSE.DOLLY;
  controls.mouseButtons.RIGHT = THREE.MOUSE.PAN;
  controls.touches.ONE = THREE.TOUCH.ROTATE;
  controls.touches.TWO = THREE.TOUCH.DOLLY_PAN;

  if (stage) {
    stage.style.touchAction = "none";
    stage.style.userSelect = "none";
    stage.style.webkitUserSelect = "none";
  }
  canvas.style.touchAction = "none";
  canvas.style.userSelect = "none";
  canvas.style.webkitUserSelect = "none";
  canvas.style.webkitTouchCallout = "none";

  let maxDim = 10;
  const look = new THREE.Vector3();
  let anim = null;
  let tour = null;
  let hovered = false;
  let onScreen = true;
  let pageVisible = true;
  let lastInput = performance.now();
  const isLive = () => onScreen && pageVisible;

  const views = {
    reset() {
      return {
        pos: new THREE.Vector3(maxDim * 1.0, maxDim * 1.5, maxDim * 1.0),
        tgt: look.clone(),
        fov: 45,
      };
    },
    iso() {
      return {
        pos: new THREE.Vector3(maxDim * 1.6, maxDim * 1.6, maxDim * 1.6),
        tgt: look.clone(),
        fov: 45,
      };
    },
    top() {
      return {
        pos: new THREE.Vector3(look.x, look.y + maxDim * 2.4, look.z + maxDim * 0.02),
        tgt: look.clone(),
        fov: 45,
      };
    },
    side() {
      return {
        pos: new THREE.Vector3(look.x + maxDim * 2.4, look.y + maxDim * 0.08, look.z),
        tgt: look.clone(),
        fov: 45,
      };
    },
    front() {
      return {
        pos: new THREE.Vector3(look.x, look.y + maxDim * 1.9, look.z),
        tgt: look.clone(),
        fov: 38,
      };
    },
    copper() {
      return {
        pos: new THREE.Vector3(look.x, look.y - maxDim * 1.55, look.z + maxDim * 0.35),
        tgt: look.clone(),
        fov: 38,
      };
    },
  };

  function go(name, ms = 800) {
    if (tour) {
      tour = null;
      syncTour();
    }
    controls.autoRotate = false;
    syncSpin();
    const v = views[name]?.();
    if (!v) return;
    anim = {
      fromP: camera.position.clone(),
      fromT: controls.target.clone(),
      fromF: camera.fov,
      toP: v.pos,
      toT: v.tgt,
      toF: v.fov,
      t0: performance.now(),
      ms,
    };
  }

  function stopTour() {
    if (!tour) return;
    tour = null;
    syncSpin();
  }

  function startTour() {
    controls.autoRotate = false;
    syncSpin();
    const y = look.y;
    const d = maxDim;
    const curve = new THREE.CatmullRomCurve3(
      [
        new THREE.Vector3(d * 1.05, y + d * 1.7, d * 1.05),
        new THREE.Vector3(d * 0.28, y + d * 0.22, d * 0.28),
        new THREE.Vector3(d * 1.35, y + d * 0.18, 0),
        new THREE.Vector3(0, y + d * 0.12, -d * 1.25),
        new THREE.Vector3(-d * 1.15, y + d * 0.35, 0),
        new THREE.Vector3(0, y + d * 0.08, d * 1.2),
        new THREE.Vector3(d * 0.7, y + d * 1.05, d * 0.7),
        new THREE.Vector3(d * 1.05, y + d * 1.7, d * 1.05),
      ],
      false,
      "centripetal",
      0.5
    );
    tour = { curve, t0: performance.now(), ms: 32000, look: look.clone() };
    anim = null;
  }

  function resize() {
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (!w || !h) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h, false);
    lastInput = performance.now();
  }

  const ro = new ResizeObserver(resize);
  ro.observe(canvas);
  resize();

  const gltf = await new GLTFLoader().loadAsync(opts.glb);
  const model = mergeByMaterial(gltf.scene);
  dressMaterials(model);
  model.updateMatrixWorld(true);

  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  model.position.sub(center);

  maxDim = Math.max(size.x, size.y, size.z) || 1;
  model.scale.setScalar(10 / maxDim);
  model.updateMatrixWorld(true);

  const fitted = new THREE.Box3().setFromObject(model);
  const fittedSize = fitted.getSize(new THREE.Vector3());
  const n = thinnestAxis(fittedSize);
  model.quaternion.premultiply(
    new THREE.Quaternion().setFromUnitVectors(n, new THREE.Vector3(0, 1, 0))
  );
  model.updateMatrixWorld(true);

  const seated = new THREE.Box3().setFromObject(model);
  model.position.y -= seated.min.y;
  model.updateMatrixWorld(true);

  const world = new THREE.Box3().setFromObject(model);
  const worldSize = world.getSize(new THREE.Vector3());
  maxDim = Math.max(worldSize.x, worldSize.z, worldSize.y) || 10;
  look.copy(world.getCenter(new THREE.Vector3()));

  scene.add(model);

  const grid = new THREE.GridHelper(maxDim * 5, 50, 0x1a1a1a, 0x111111);
  grid.position.y = 0;
  scene.add(grid);

  controls.minDistance = maxDim * 0.08;
  controls.maxDistance = maxDim * 6;
  camera.near = maxDim * 0.01;
  camera.far = maxDim * 40;
  camera.updateProjectionMatrix();

  const home = views.reset();
  camera.position.copy(home.pos);
  controls.target.copy(home.tgt);
  camera.fov = home.fov;
  camera.updateProjectionMatrix();
  controls.update();

  stage?.classList.add("is-ready");

  function syncSpin() {
    const btn = canvas.closest(".bench")?.querySelector('[data-bench="spin"]');
    if (btn) btn.textContent = controls.autoRotate ? "Hold" : "Turn";
  }

  function syncGrid() {
    const btn = canvas.closest(".bench")?.querySelector('[data-bench="grid"]');
    if (btn) btn.classList.toggle("is-on", grid.visible);
  }

  function syncTour() {
    const btn = canvas.closest(".bench")?.querySelector('[data-bench="tour"]');
    if (btn) {
      btn.classList.toggle("is-on", Boolean(tour));
      btn.textContent = tour ? "Stop" : "Tour";
    }
  }

  let raf = 0;
  controls.addEventListener("change", () => {
    lastInput = performance.now();
  });

  function tick() {
    raf = requestAnimationFrame(tick);
    if (!isLive()) return;

    const now = performance.now();
    const busy = controls.autoRotate || tour || anim || now - lastInput < 900;
    if (!busy) return;
    if (anim) {
      const u = Math.min(1, (now - anim.t0) / anim.ms);
      const e = easeInOutCubic(u);
      camera.position.lerpVectors(anim.fromP, anim.toP, e);
      controls.target.lerpVectors(anim.fromT, anim.toT, e);
      camera.fov = THREE.MathUtils.lerp(anim.fromF, anim.toF, e);
      camera.updateProjectionMatrix();
      if (u >= 1) anim = null;
    }

    if (tour) {
      const u = Math.min(1, (now - tour.t0) / tour.ms);
      const p = tour.curve.getPoint(u);
      camera.position.copy(p);
      controls.target.copy(tour.look);
      camera.fov = THREE.MathUtils.lerp(50, 32, Math.sin(u * Math.PI));
      camera.updateProjectionMatrix();
      if (u >= 1) {
        stopTour();
        go("reset", 900);
        syncTour();
      }
    }

    controls.update();
    renderer.render(scene, camera);
  }
  tick();

  const root = canvas.closest(".bench") || document;
  const io = new IntersectionObserver(
    ([entry]) => {
      onScreen = entry.isIntersecting;
    },
    { threshold: 0.08 }
  );
  io.observe(canvas);

  function onVis() {
    pageVisible = !document.hidden;
  }
  document.addEventListener("visibilitychange", onVis);

  function haltSpin() {
    lastInput = performance.now();
    if (tour) {
      stopTour();
      syncTour();
    }
    if (!controls.autoRotate) return;
    controls.autoRotate = false;
    syncSpin();
  }

  let lastTap = 0;
  let tapX = 0;
  let tapY = 0;
  const blockScroll = (e) => {
    if (e.target.closest(".bench-hud, .bench-tools, button, a")) return;
    if (e.cancelable) e.preventDefault();
  };

  if (stage) {
    stage.addEventListener("touchstart", blockScroll, { passive: false });
    stage.addEventListener("touchmove", blockScroll, { passive: false });
  }

  canvas.addEventListener("pointerenter", () => {
    hovered = true;
    if (!mobile) canvas.focus({ preventScroll: true });
  });
  canvas.addEventListener("pointerleave", () => {
    hovered = false;
  });
  controls.addEventListener("start", haltSpin);
  canvas.addEventListener("pointerdown", (e) => {
    haltSpin();
    if (mobile) canvas.focus({ preventScroll: true });
    if (e.pointerType === "touch") {
      const now = performance.now();
      const dt = now - lastTap;
      const dx = e.clientX - tapX;
      const dy = e.clientY - tapY;
      if (dt < 320 && dx * dx + dy * dy < 900) {
        e.preventDefault();
        go("reset");
        lastTap = 0;
      } else {
        lastTap = now;
        tapX = e.clientX;
        tapY = e.clientY;
      }
    }
  });
  if (!mobile) {
    canvas.addEventListener("dblclick", (e) => {
      e.preventDefault();
      go("reset");
    });
  }

  function act(name) {
    if (name === "reset") go("reset");
    if (name === "front") go("front");
    if (name === "copper") go("copper");
    if (name === "top") go("top");
    if (name === "iso") go("iso");
    if (name === "side") go("side");
    if (name === "spin") {
      stopTour();
      controls.autoRotate = !controls.autoRotate;
      syncSpin();
      syncTour();
    }
    if (name === "grid") {
      grid.visible = !grid.visible;
      syncGrid();
    }
    if (name === "tour") {
      if (tour) stopTour();
      else startTour();
      syncTour();
    }
  }

  root.querySelectorAll("[data-bench]").forEach((btn) => {
    btn.addEventListener("click", () => act(btn.getAttribute("data-bench")));
  });

  stage?.querySelector("[data-hud=legend]")?.addEventListener("click", (e) => {
    const panel = stage.querySelector("[data-hud-panel]");
    const open = panel.hasAttribute("hidden");
    panel.toggleAttribute("hidden", !open);
    e.currentTarget.setAttribute("aria-expanded", String(open));
  });

  function onKey(e) {
    if (!hovered && document.activeElement !== canvas) return;
    if (e.target.closest("input, textarea")) return;
    const k = e.key.toLowerCase();
    if (k === " ") {
      e.preventDefault();
      act("spin");
    }
    if (k === "1") act("top");
    if (k === "2") act("iso");
    if (k === "3") act("side");
    if (k === "r") act("reset");
    if (k === "i") act("tour");
    if (k === "g") act("grid");
    if (k === "arrowleft") {
      e.preventDefault();
      controls.autoRotate = false;
      camera.position.applyAxisAngle(new THREE.Vector3(0, 1, 0), 0.18);
      syncSpin();
    }
    if (k === "arrowright") {
      e.preventDefault();
      controls.autoRotate = false;
      camera.position.applyAxisAngle(new THREE.Vector3(0, 1, 0), -0.18);
      syncSpin();
    }
    if (k === "=" || k === "+") {
      const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
      camera.position.addScaledVector(dir, -0.12);
    }
    if (k === "-" || k === "_") {
      const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
      camera.position.addScaledVector(dir, 0.12);
    }
  }
  window.addEventListener("keydown", onKey);

  canvas.tabIndex = 0;
  syncSpin();
  syncGrid();
  syncTour();

  return {
    reset: () => act("reset"),
    front: () => act("front"),
    copper: () => act("copper"),
    toggleSpin: () => {
      act("spin");
      return controls.autoRotate;
    },
    dispose() {
      cancelAnimationFrame(raf);
      ro.disconnect();
      io.disconnect();
      document.removeEventListener("visibilitychange", onVis);
      window.removeEventListener("keydown", onKey);
      if (stage) {
        stage.removeEventListener("touchstart", blockScroll);
        stage.removeEventListener("touchmove", blockScroll);
      }
      controls.dispose();
      renderer.dispose();
    },
  };
}

const canvas = document.getElementById("bench");
if (canvas) {
  const prefix = canvas.dataset.prefix || "";
  const glb = canvas.dataset.glb || `${prefix}assets/pcb/alu.glb`;
  mountBench(canvas, { glb }).catch((err) => {
    console.error(err);
    const stage = canvas.parentElement;
    if (stage) {
      stage.innerHTML = `<p class="forge-err" style="padding:1.5rem">The GLB did not load. Serve the paper over http, not file://.</p>`;
    }
  });
}
