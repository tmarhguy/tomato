/* Shared 07_alu look: soldermask coat, KiCad copper, sculpted key light. */
import * as THREE from "three";

export function dressPcbMaterials(root) {
  root.traverse((child) => {
    if (!child.isMesh) return;
    const list = Array.isArray(child.material) ? child.material : [child.material];
    const next = list.map((material) => {
      if (!material?.isMeshStandardMaterial) return material;
      const m = material.clone();
      const h = { h: 0, s: 0, l: 0 };
      m.color.getHSL(h);
      const coat = m.opacity < 0.99;

      if (coat && m.opacity > 0.95 && h.h > 0.12 && h.h < 0.28 && h.l > 0.28 && h.l < 0.55) {
        m.color.setRGB(0, 0, 0);
        m.opacity = 1;
        m.transparent = false;
        m.depthWrite = true;
        m.roughness = 0.88;
        m.metalness = 0;
        m.envMapIntensity = 0.15;
        m.needsUpdate = true;
        return m;
      }

      if (coat && m.opacity <= 0.86 && h.h > 0.28 && h.h < 0.5) {
        const p = new THREE.MeshPhysicalMaterial();
        p.color.copy(m.color).offsetHSL(0.02, 0.35, -0.11);
        p.roughness = 0.32;
        p.metalness = 0.06;
        p.opacity = 0.96;
        p.transparent = true;
        p.depthWrite = false;
        p.clearcoat = 0.7;
        p.clearcoatRoughness = 0.22;
        p.envMapIntensity = 1.05;
        p.polygonOffset = true;
        p.polygonOffsetFactor = -1;
        p.polygonOffsetUnits = -1;
        child.renderOrder = 1;
        p.needsUpdate = true;
        m.dispose();
        return p;
      }

      m.transparent = coat;
      m.depthWrite = !coat;

      if (coat && h.l > 0.85 && h.s < 0.15) {
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
      } else if (m.metalness > 0.8 && m.roughness < 0.55 && h.s > 0.55 && h.h > 0.12 && h.h < 0.2) {
        m.envMapIntensity = 1.15;
        m.roughness = 0.28;
      } else if (m.metalness > 0.8 && m.roughness < 0.55 && h.s < 0.12) {
        m.envMapIntensity = 1.2;
        m.roughness = 0.28;
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

export function lightPcbScene(scene, { hemiIntensity = 0.12, level = 1 } = {}) {
  const hemi = new THREE.HemisphereLight(0xd8e4ee, 0x1a1814, hemiIntensity);
  scene.add(hemi);
  const key = new THREE.DirectionalLight(0xfff4e6, 1.15 * level);
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
