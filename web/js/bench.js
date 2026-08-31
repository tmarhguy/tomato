/* 07_alu playground — lighting and materials match the 8-bit ALU site. */
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { lightPcbScene, loadFittedPcb, studioEnv } from "./pcb-look.js";

function easeInOutCubic(u) {
  return u < 0.5 ? 4 * u * u * u : 1 - (-2 * u + 2) ** 3 / 2;
}

function easeOutCubic(u) {
  return 1 - (1 - u) ** 3;
}

const STAGE_DARK = 0x050505;
const STAGE_LIGHT = 0xf4f0e6; /* Paper stock — same as mast PAPER */

function stageHex() {
  const theme = document.documentElement.getAttribute("data-theme");
  if (theme === "light") return STAGE_LIGHT;
  if (theme === "dark") return STAGE_DARK;

  const root = document.querySelector(".landing-hero__viewer, .page--landing, .page") || document.documentElement;
  const css =
    getComputedStyle(root).getPropertyValue("--landing-viewer-bg").trim() ||
    getComputedStyle(root).getPropertyValue("--landing-bg").trim() ||
    getComputedStyle(document.documentElement).getPropertyValue("--bg").trim();
  if (css) {
    try {
      return new THREE.Color(css).getHex();
    } catch {}
  }
  return STAGE_DARK;
}

function syncStageBackground(scene, renderer) {
  const hex = stageHex();
  scene.background = new THREE.Color(hex);
  renderer.setClearColor(hex, 1);
  const stage = renderer.domElement && renderer.domElement.closest(".bench-stage");
  if (stage) stage.style.background = `#${hex.toString(16).padStart(6, "0")}`;
}

function isHand() {
  return (
    (typeof matchMedia === "function" && matchMedia("(max-width: 860px)").matches) ||
    (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches)
  );
}

function isCoarsePointer() {
  return (
    (typeof matchMedia === "function" && matchMedia("(pointer: coarse)").matches) ||
    (typeof navigator !== "undefined" && navigator.maxTouchPoints > 0)
  );
}

function injectHud(stage) {
  if (stage.querySelector(".bench-hud")) return;
  const hud = document.createElement("div");
  hud.className = "bench-hud";
  hud.innerHTML = `
    <button type="button" class="bench-hud-toggle" data-hud="legend" aria-expanded="false">
      <span class="hud-desk">Controls</span><span class="hud-hand">Controls</span>
    </button>
    <div class="bench-legend-wrap" hidden>
      <div class="bench-legend bench-legend--desk">
        <p class="bench-legend-row"><span>Turn</span><kbd>Drag</kbd></p>
        <p class="bench-legend-row"><span>Slide</span><kbd>Right-drag</kbd></p>
        <p class="bench-legend-row"><span>Zoom</span><kbd>Scroll</kbd></p>
        <p class="bench-legend-row"><span>Hold</span><kbd>Space</kbd></p>
        <p class="bench-legend-row"><span>Top / Iso / Side</span><kbd>1 2 3</kbd></p>
        <p class="bench-legend-row"><span>Reset / Tour / Grid</span><kbd>R I G</kbd></p>
      </div>
      <div class="bench-legend bench-legend--hand">
        <p class="bench-legend-row"><span>Orbit</span><kbd>1 finger</kbd></p>
        <p class="bench-legend-row"><span>Zoom</span><kbd>Pinch</kbd></p>
        <p class="bench-legend-row"><span>Pan</span><kbd>2 fingers</kbd></p>
        <p class="bench-legend-row"><span>Spin</span><kbd>Tap</kbd></p>
        <p class="bench-legend-row"><span>Reset</span><kbd>Double-tap</kbd></p>
        <p class="bench-legend-row"><span>Zoom in</span><kbd>Triple-tap</kbd></p>
      </div>
    </div>
  `;
  const markWrap = document.createElement("div");
  markWrap.className = "bench-mark-wrap";
  markWrap.innerHTML = `
    <button type="button" class="bench-mark" data-hud="model" aria-expanded="false" aria-label="KiCad PCB model">
      KiCad
    </button>
    <div class="bench-model-wrap" hidden>
      <div class="bench-model-info">
        <p class="bench-model-kicker">07_alu · KiCad 10 export</p>
        <p>This is the real PCB model — soldermask, copper, pads, and 74ACT footprints straight from KiCad. The lighting is studio; the geometry is not restyled.</p>
        <p class="bench-model-stat"><span>Shipped GLB</span><span>1.26 MB · 9 meshes</span></p>
        <p class="bench-model-stat"><span>Raw export</span><span>~31 MB · ~41k primitives</span></p>
        <p class="bench-model-note">We join footprints by material and Draco-compress so copper stays on its own layer. <a href="journal/web-optimization.html">How we shrunk the GLB</a></p>
      </div>
    </div>
  `;
  stage.append(hud, markWrap);
}

export async function mountBench(canvas, opts) {
  const stage = canvas.parentElement;
  if (stage) injectHud(stage);

  const scene = new THREE.Scene();

  const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 500);
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    powerPreference: "high-performance",
  });
  syncStageBackground(scene, renderer);
  const mobile = isCoarsePointer();
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.92;

  scene.environment = studioEnv(renderer);
  scene.environmentIntensity = 0.4;

  lightPcbScene(scene, { hemiIntensity: 0.6 });

  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = mobile ? 0.12 : 0.08;
  controls.autoRotate = true;
  controls.autoRotateSpeed = mobile ? -1.4 : -2.66;
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
  let hovered = false;
  let onScreen = false;
  let pageVisible = true;
  let lastInput = performance.now();
  const isLive = () => onScreen && pageVisible;

  const compact = isHand();
  const pull = compact ? 1.32 : 1;

  const views = {
    reset() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x + d, look.y + d * 1.45, look.z + d),
        tgt: look.clone(),
        fov: 45,
      };
    },
    iso() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x + d * 1.45, look.y + d * 1.45, look.z + d * 1.45),
        tgt: look.clone(),
        fov: 45,
      };
    },
    top() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x, look.y + d * 2.4, look.z + d * 0.02),
        tgt: look.clone(),
        fov: 45,
      };
    },
    side() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x + d * 2.4, look.y + d * 0.08, look.z),
        tgt: look.clone(),
        fov: 45,
      };
    },
    front() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x, look.y + d * 1.9, look.z),
        tgt: look.clone(),
        fov: 38,
      };
    },
    copper() {
      const d = maxDim * pull;
      return {
        pos: new THREE.Vector3(look.x, look.y - d * 1.55, look.z + d * 0.35),
        tgt: look.clone(),
        fov: 38,
      };
    },
  };

  function go(name, ms = 800) {
    controls.autoRotate = false;
    syncSpin();
    const v = views[name]?.();
    if (!v) return;
    currentView = name;
    syncViewBtns();
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

  function openTour() {
    const href = canvas.dataset.tour || "viewer.html";
    window.location.href = new URL(href, document.baseURI).href;
  }

  let viewW = 0;
  let viewH = 0;
  function resize() {
    const w = canvas.clientWidth | 0;
    const h = canvas.clientHeight | 0;
    if (!w || !h || (w === viewW && h === viewH)) return;
    viewW = w;
    viewH = h;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h, false);
    lastInput = performance.now();
  }

  const ro = new ResizeObserver(resize);
  ro.observe(canvas);
  resize();

  const fitted = await loadFittedPcb(opts.glb, renderer);
  const model = fitted.model;
  maxDim = fitted.maxDim;
  look.copy(fitted.look);
  scene.add(model);

  const grid = new THREE.GridHelper(maxDim * 5, 50, 0x1a1a1a, 0x111111);
  grid.position.set(look.x, 0, look.z);
  scene.add(grid);

  controls.minDistance = maxDim * 0.08;
  controls.maxDistance = maxDim * 6;
  camera.near = maxDim * 0.003;
  camera.far = maxDim * 40;
  camera.updateProjectionMatrix();

  const home = views.reset();
  camera.up.set(0, 1, 0);
  camera.position.copy(home.pos);
  controls.target.copy(home.tgt);
  camera.fov = home.fov;
  camera.updateProjectionMatrix();
  camera.lookAt(home.tgt);
  controls.update();
  renderer.render(scene, camera);

  stage?.classList.add("is-ready");

  let currentView = "reset";

  function syncSpin() {
    const btn = canvas.closest(".bench")?.querySelector('[data-bench="spin"]');
    if (btn) {
      btn.textContent = controls.autoRotate ? "Hold" : "Turn";
      btn.classList.toggle("is-on", controls.autoRotate);
    }
  }

  function syncViewBtns() {
    root.querySelectorAll("[data-bench]").forEach((btn) => {
      const name = btn.getAttribute("data-bench");
      if (name === "spin" || name === "grid") return;
      if (name === "flip") {
        const onCopper = currentView === "copper";
        btn.textContent = onCopper ? "Top" : "Bottom";
        btn.setAttribute("aria-label", onCopper ? "Switch to top view" : "Switch to bottom copper view");
        btn.classList.toggle("is-on", currentView === "top" || currentView === "copper");
        return;
      }
      btn.classList.toggle("is-on", name === currentView && name !== "reset");
    });
  }

  function dollyIn(ms = 700) {
    controls.autoRotate = false;
    syncSpin();
    const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
    const dist = dir.length();
    const next = Math.max(controls.minDistance, dist * 0.62);
    if (Math.abs(next - dist) < 1e-4) return;
    dir.setLength(next);
    currentView = "";
    syncViewBtns();
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
    lastInput = performance.now();
  }

  function syncGrid() {
    const btn = canvas.closest(".bench")?.querySelector('[data-bench="grid"]');
    if (btn) btn.classList.toggle("is-on", grid.visible);
  }

  let raf = 0;
  controls.addEventListener("change", () => {
    lastInput = performance.now();
  });

  function tick() {
    raf = requestAnimationFrame(tick);
    if (!isLive()) return;

    const now = performance.now();
    const busy = controls.autoRotate || anim || now - lastInput < 900;
    if (!busy) return;
    if (anim) {
      const u = Math.min(1, (now - anim.t0) / anim.ms);
      const e = (anim.ease || easeInOutCubic)(u);
      camera.position.lerpVectors(anim.fromP, anim.toP, e);
      controls.target.lerpVectors(anim.fromT, anim.toT, e);
      camera.fov = THREE.MathUtils.lerp(anim.fromF, anim.toF, e);
      camera.updateProjectionMatrix();
      if (u >= 1) anim = null;
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
    currentView = "";
    syncViewBtns();
    if (!controls.autoRotate) return;
    controls.autoRotate = false;
    syncSpin();
  }

  const blockScroll = (e) => {
    if (e.target.closest(".bench-hud, .bench-mark-wrap, .bench-tools, button, a")) return;
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
  let ptrDownX = 0, ptrDownY = 0, ptrDownTime = 0;
  let wasSpinning = false;
  let tapTimer = 0;
  let taps = 0;
  let tapReset = false;

  canvas.addEventListener("pointerdown", (e) => {
    wasSpinning = controls.autoRotate;
    haltSpin();
    ptrDownX = e.clientX;
    ptrDownY = e.clientY;
    ptrDownTime = performance.now();
    if (mobile) canvas.focus({ preventScroll: true });
  }, { capture: true });

  canvas.addEventListener("pointerup", (e) => {
    const dt = performance.now() - ptrDownTime;
    const dx = e.clientX - ptrDownX;
    const dy = e.clientY - ptrDownY;
    if (dt <= 0 || dt >= 400 || dx * dx + dy * dy >= 100) {
      taps = 0;
      tapReset = false;
      return;
    }
    if (!isHand()) {
      controls.autoRotate = !wasSpinning;
      syncSpin();
      return;
    }
    taps += 1;
    clearTimeout(tapTimer);
    if (taps >= 3) {
      if (tapReset && anim?.fromP) {
        camera.position.copy(anim.fromP);
        controls.target.copy(anim.fromT);
        camera.fov = anim.fromF;
        camera.updateProjectionMatrix();
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
        controls.autoRotate = !wasSpinning;
        syncSpin();
      }
      taps = 0;
    }, 280);
  });
  if (!mobile) {
    canvas.addEventListener("click", (e) => {
      if (e.detail === 2 || e.detail === 3) {
        e.preventDefault();
        const dir = new THREE.Vector3().subVectors(camera.position, controls.target);
        if (e.detail === 2) camera.position.addScaledVector(dir, -0.35);
        if (e.detail === 3) camera.position.addScaledVector(dir, 0.55);
      }
    });
  }

  function act(name) {
    if (name === "reset") go("reset");
    if (name === "front") go("front");
    if (name === "copper") go("copper");
    if (name === "top") go("top");
    if (name === "iso") go("iso");
    if (name === "side") go("side");
    if (name === "flip") {
      go(currentView === "copper" ? "top" : "copper");
      return;
    }
    if (name === "spin") {
      controls.autoRotate = !controls.autoRotate;
      syncSpin();
    }
    if (name === "grid") {
      grid.visible = !grid.visible;
      syncGrid();
    }
    if (name === "tour") openTour();
  }

  root.querySelectorAll("[data-bench]").forEach((btn) => {
    btn.addEventListener("click", () => act(btn.getAttribute("data-bench")));
  });

  stage?.querySelector("[data-hud=legend]")?.addEventListener("click", (e) => {
    const wrap = stage.querySelector(".bench-legend-wrap");
    const modelWrap = stage.querySelector(".bench-model-wrap");
    const modelBtn = stage.querySelector("[data-hud=model]");
    if (!wrap) return;
    const open = wrap.hasAttribute("hidden");
    wrap.toggleAttribute("hidden", !open);
    e.currentTarget.setAttribute("aria-expanded", String(open));
    e.currentTarget.classList.toggle("is-on", open);
    if (open && modelWrap && modelBtn) {
      modelWrap.setAttribute("hidden", "");
      modelBtn.setAttribute("aria-expanded", "false");
      modelBtn.classList.remove("is-on");
    }
  });

  stage?.querySelector("[data-hud=model]")?.addEventListener("click", (e) => {
    const wrap = stage.querySelector(".bench-model-wrap");
    const legendWrap = stage.querySelector(".bench-legend-wrap");
    const legendBtn = stage.querySelector("[data-hud=legend]");
    if (!wrap) return;
    const open = wrap.hasAttribute("hidden");
    wrap.toggleAttribute("hidden", !open);
    e.currentTarget.setAttribute("aria-expanded", String(open));
    e.currentTarget.classList.toggle("is-on", open);
    if (open && legendWrap && legendBtn) {
      legendWrap.setAttribute("hidden", "");
      legendBtn.setAttribute("aria-expanded", "false");
      legendBtn.classList.remove("is-on");
    }
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
    if (k === "i") openTour();
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
  syncViewBtns();

  const themeObs = new MutationObserver(() => {
    requestAnimationFrame(() => {
      syncStageBackground(scene, renderer);
      controls.update();
      renderer.render(scene, camera);
    });
  });
  themeObs.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  document.addEventListener("tomato:theme", () => {
    syncStageBackground(scene, renderer);
    controls.update();
    renderer.render(scene, camera);
  });

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
      themeObs.disconnect();
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
