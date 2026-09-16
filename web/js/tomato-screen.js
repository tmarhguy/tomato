/* Shared Tomato screen renderer: tile words -> canvas pixels.
 *
 * Same algorithm as tools/virtual_tomato.html. Pure w.r.t. the machine
 * (reads tile/font/palette/paper arrays); the only DOM it touches is the
 * ImageData + context handed in, so both virtual.html and the homepage
 * embed paint identical pixels.
 */
export function renderTile(tiles, font, pal, paper, data, ti) {
  const w = tiles[ti] >>> 0;
  const tx = (ti % 80) * 8, ty = ((ti / 80) | 0) * 8;
  const large = (w >> 18) & 1;
  for (let py = 0; py < 8; py++) {
    const y = ty + py;
    if (y >= 480) break;
    const row = large ? (((w >> 20) & 1) * 4 + (py >> 1)) : py;
    for (let px = 0; px < 8; px++) {
      const x = tx + px;
      const col = large ? (((w >> 19) & 1) * 4 + ((px) >> 1)) : px;
      const ink = (font[((w & 255) * 8 + row) & 2047] >> col) & 1;
      let r, g, b;
      if ((w & 65536) && !ink) {
        const p = paper[((y >> 1) * 320 + (x >> 1)) | 0];
        const shift = (w & 131072) ? 2 : 0;
        r = (((p >> 8) & 15) >> shift) * 17;
        g = (((p >> 4) & 15) >> shift) * 17;
        b = ((p & 15) >> shift) * 17;
      } else {
        const index = (w & 65280) ? (ink ? (w >> 8) & 15 : (w >> 12) & 15) : (w & 15);
        r = pal[index * 3]; g = pal[index * 3 + 1]; b = pal[index * 3 + 2];
      }
      const o = (y * 640 + x) * 4;
      data[o] = r; data[o + 1] = g; data[o + 2] = b; data[o + 3] = 255;
    }
  }
}

export function paintFull(cpu, image, imgData, ctx) {
  for (let ti = 0; ti < 4800; ti++) {
    renderTile(cpu.tiles, image.font, image.pal, image.paper, imgData.data, ti);
  }
  ctx.putImageData(imgData, 0, 0);
  cpu.dirty.clear();
}

export function paintDirty(cpu, image, imgData, ctx) {
  if (cpu.dirty.size === 0) return false;
  for (const ti of cpu.dirty) {
    if (ti < 4800) renderTile(cpu.tiles, image.font, image.pal, image.paper, imgData.data, ti);
  }
  ctx.putImageData(imgData, 0, 0);
  cpu.dirty.clear();
  return true;
}
