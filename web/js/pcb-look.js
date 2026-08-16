/* Shared 07_alu look: soldermask coat, KiCad copper, sculpted key light. */
import * as THREE from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { DRACOLoader } from "three/addons/loaders/DRACOLoader.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { mergeGeometries } from "three/addons/utils/BufferGeometryUtils.js";

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

/* KiCad ships ~41k pad/trace meshes. Merge by material so copper stays
   a separate draw from the translucent soldermask that sits over it.
   Optimized GLBs are already joined (~10 meshes); leave those alone. */
export function mergePcbByMaterial(root) {
  let meshes = 0;
  root.traverse((child) => {
    if (child.isMesh) meshes++;
  });
  if (meshes < 32) return root;

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
    if (!buckets.has(key)) buckets.set(key, { material: mat, geos: [], name: child.name || "" });
    buckets.get(key).geos.push(geo);
  });

  const group = new THREE.Group();
  for (const { material, geos, name } of buckets.values()) {
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
    mesh.name = name || "";
    mesh.frustumCulled = true;
    group.add(mesh);
  }
  old.forEach((mesh) => {
    mesh.geometry.dispose();
    mesh.removeFromParent();
  });
  return group;
}

function layerOf(child) {
  const n = `${child.name || ""} ${child.parent?.name || ""}`.toLowerCase();
  if (n.includes("soldermask")) return "mask";
  if (n.includes("silkscreen")) return "silk";
  if (n.includes("copper") || n.includes("_via")) return "copper";
  if (n.includes("_pad") || n.endsWith("pad")) return "pad";
  if (n.includes("_pcb") || /(^|[^a-z])pcb([^a-z]|$)/.test(n)) return "fr4";
  return null;
}

function premiumMask() {
  const p = new THREE.MeshPhysicalMaterial();
  p.color.setHex(0x0e5f34);
  p.roughness = 0.34;
  p.metalness = 0.04;
  p.opacity = 0.9;
  p.transparent = true;
  p.depthWrite = false;
  p.clearcoat = 0.65;
  p.clearcoatRoughness = 0.28;
  p.envMapIntensity = 0.78;
  p.polygonOffset = true;
  p.polygonOffsetFactor = -1;
  p.polygonOffsetUnits = -1;
  p.needsUpdate = true;
  return p;
}

export function dressPcbMaterials(root, renderer) {
  const maxAnisotropy = renderer ? renderer.capabilities.getMaxAnisotropy() : 1;
  root.traverse((child) => {
    if (!child.isMesh) return;
    const layer = layerOf(child);
    const list = Array.isArray(child.material) ? child.material : [child.material];
    const next = list.map((material) => {
      if (!material?.isMeshStandardMaterial) return material;
      const m = material.clone();
      const h = { h: 0, s: 0, l: 0 };
      m.color.getHSL(h);
      const coat = m.opacity < 0.99;

      if (maxAnisotropy > 1) {
        if (m.map) m.map.anisotropy = maxAnisotropy;
        if (m.roughnessMap) m.roughnessMap.anisotropy = maxAnisotropy;
        if (m.metalnessMap) m.metalnessMap.anisotropy = maxAnisotropy;
        if (m.normalMap) m.normalMap.anisotropy = maxAnisotropy;
      }

      if (layer === "mask" || (coat && m.opacity <= 0.86 && h.h > 0.28 && h.h < 0.5)) {
        child.renderOrder = 1;
        m.dispose();
        return premiumMask();
      }

      if (layer === "fr4" || (coat && m.opacity > 0.95 && h.h > 0.12 && h.h < 0.28 && h.l > 0.28 && h.l < 0.55)) {
        m.color.setHex(0x0a281c);
        m.opacity = 1;
        m.transparent = false;
        m.depthWrite = true;
        m.roughness = 0.82;
        m.metalness = 0;
        m.envMapIntensity = 0.22;
        m.needsUpdate = true;
        return m;
      }

      m.transparent = coat;
      m.depthWrite = !coat;

      if (layer === "silk" || (coat && h.l > 0.85 && h.s < 0.15)) {
        m.color.setRGB(1, 1, 1);
        m.opacity = 1;
        m.transparent = false;
        m.depthWrite = true;
        m.roughness = 1;
        m.metalness = 0;
        m.polygonOffset = true;
        m.polygonOffsetFactor = -2;
        m.polygonOffsetUnits = -2;
        child.renderOrder = 2;
        m.envMapIntensity = 0.12;
      } else if (layer === "copper" || (m.metalness > 0.8 && m.roughness < 0.55 && h.s > 0.55 && h.h > 0.12 && h.h < 0.2)) {
        m.color.setHex(0xc4a020);
        m.envMapIntensity = 1.2;
        m.roughness = 0.26;
        m.metalness = 1;
      } else if (layer === "pad" || (m.metalness > 0.8 && m.roughness < 0.55 && h.s < 0.12)) {
        m.color.setHex(0xd4b45a);
        m.envMapIntensity = 1.25;
        m.roughness = 0.24;
        m.metalness = 1;
      } else if (m.metalness > 0.8 && m.roughness > 0.8) {
        m.metalness = 0;
        if (h.l < 0.18) m.color.setRGB(0.03, 0.03, 0.03);
        m.roughness = h.l < 0.15 ? 0.45 : 0.6;
        m.envMapIntensity = 0.3;
      } else {
        m.envMapIntensity = m.metalness > 0.5 ? 0.85 : 0.45;
      }
      m.needsUpdate = true;
      return m;
    });
    child.material = next.length === 1 ? next[0] : next;
  });
}

export function collectPcbLayers(root) {
  const layers = { mask: [], silk: [], copper: [], pad: [], fr4: [], other: [] };
  root.traverse((child) => {
    if (!child.isMesh) return;
    const layer = layerOf(child);
    const bucket = layer && layers[layer] ? layer : "other";
    layers[bucket].push(child);
    if (bucket === "mask" || bucket === "silk") {
      child.userData.peelY0 = child.position.y;
      const mats = Array.isArray(child.material) ? child.material : [child.material];
      child.userData.peelOp0 = mats.map((m) => (m && "opacity" in m ? m.opacity : 1));
    }
  });
  return layers;
}

/* amount 0 = seated mask, 1 = lid off. Silk rides with the mask. */
export function applyMaskPeel(layers, amount, lift = 0.85) {
  const a = Math.min(1, Math.max(0, amount));
  const y = lift * a;
  const fade = 1 - a * 0.82;
  for (const mesh of layers.mask) {
    mesh.position.y = (mesh.userData.peelY0 ?? 0) + y;
    const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    const ops = mesh.userData.peelOp0 || [];
    mats.forEach((m, i) => {
      if (!m || !("opacity" in m)) return;
      m.opacity = (ops[i] ?? 0.9) * fade;
    });
  }
  for (const mesh of layers.silk) {
    mesh.position.y = (mesh.userData.peelY0 ?? 0) + y;
  }
  const glow = 1 + a * 0.4;
  for (const mesh of layers.copper) {
    const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    for (const m of mats) {
      if (!m || m.envMapIntensity == null) continue;
      if (m.userData.env0 == null) m.userData.env0 = m.envMapIntensity;
      m.envMapIntensity = m.userData.env0 * glow;
    }
  }
}

export function lightPcbScene(scene, { hemiIntensity = 0.12, level = 1 } = {}) {
  const hemi = new THREE.HemisphereLight(0xd8e4ee, 0x1a1814, hemiIntensity);
  scene.add(hemi);
  const key = new THREE.DirectionalLight(0xfff4e6, 0.85 * level);
  key.position.set(9, 16, 7);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0x9aa8b8, 0.12 * level);
  fill.position.set(-10, 5, -8);
  scene.add(fill);
  const rim = new THREE.DirectionalLight(0xcfe0ff, 0.22 * level);
  rim.position.set(-6, 8, 14);
  scene.add(rim);
  return { hemi, key, fill, rim };
}

function thinnestAxis(size) {
  if (size.x <= size.y && size.x <= size.z) return new THREE.Vector3(1, 0, 0);
  if (size.y <= size.x && size.y <= size.z) return new THREE.Vector3(0, 1, 0);
  return new THREE.Vector3(0, 0, 1);
}

/* Scale to 10, stand the thin axis up, seat on y=0, center on XZ. */
export function fitBoard(model) {
  model.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(model);
  const size = box.getSize(new THREE.Vector3());
  model.position.sub(box.getCenter(new THREE.Vector3()));

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
  const mid = world.getCenter(new THREE.Vector3());
  model.position.x -= mid.x;
  model.position.z -= mid.z;
  model.updateMatrixWorld(true);

  const aligned = new THREE.Box3().setFromObject(model);
  const worldSize = aligned.getSize(new THREE.Vector3());
  return {
    look: aligned.getCenter(new THREE.Vector3()),
    maxDim: Math.max(worldSize.x, worldSize.z, worldSize.y) || 10,
    boardTop: aligned.max.y,
    spanX: worldSize.x,
    spanZ: worldSize.z,
  };
}

export function studioEnv(renderer) {
  const pmrem = new THREE.PMREMGenerator(renderer);
  return pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
}

export async function loadFittedPcb(url, renderer, onProgress) {
  const draco = new DRACOLoader();
  draco.setDecoderPath("https://cdn.jsdelivr.net/npm/three@0.169.0/examples/jsm/libs/draco/gltf/");
  const loader = new GLTFLoader();
  loader.setDRACOLoader(draco);
  const gltf = await loader.loadAsync(url, onProgress);
  const model = mergePcbByMaterial(gltf.scene);
  dressPcbMaterials(model, renderer);
  return { model, ...fitBoard(model) };
}
