#!/usr/bin/env python3
"""Build the static web image for the in-browser Tomato emulator.

The OS assembly stays the single source of truth. This script only repacks
*derived artifacts* into the lightest shippable form -- it never translates
semantics:

  software/os/*.s  --(software/assembler.py)--> mem words
  rtl/burn/mc_*.vh (same files the RTL includes) --> microcode planes
  rtl/board/{font_rom.v,videoout.v,wallpaper.mem} --> display assets

Output is one binary, web/data/tomato-os.bin:

  magic "TOM1" | u32 version=1 | u32 mem_words | 16B source id
  mem_words x u32LE assembled image (dense, word-addressed)
  8 x 512B microcode planes (alu_shift, alu_a, alu_b, ir_reg,
    mem_io, mem_bus, pc, pc_sp_mul)
  2048B font ROM | 48B palette (16 x RGB) | 38400B wallpaper (12-bit, packed)

The source id is the first 16 hex chars of sha256(mem + planes), so the page
can name the exact firmware build it runs. With --check, regenerates in
memory and fails if web/data/tomato-os.bin is stale (npm test uses this).
"""
import argparse
import hashlib
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "software"))
import assembler

CORE = ROOT / "hardware/fpga/core"
BURN = CORE / "rtl/burn"
BOARD = CORE / "rtl/board"
OUT = ROOT / "web/data/tomato-os.bin"
MANIFEST = ROOT / "web/data/tomato-os.json"

PLANES = [
    "mc_alu_shift_control.vh",
    "mc_alu_control_1.vh",
    "mc_alu_lut_b.vh",
    "mc_ir_reg_control.vh",
    "mc_mem_io_control.vh",
    "mc_mem_bus_control.vh",
    "mc_pc_control.vh",
    "mc_pc_sp_mul_control.vh",
]
MEM_ROW = re.compile(r"mem\[(\d+)\]\s*=\s*8'h([0-9A-Fa-f]+)")
FONT_ROW = re.compile(r"mem\[11'h([0-9A-Fa-f]+)\]\s*=\s*8'h([0-9A-Fa-f]+)")
PAL_ROW = re.compile(
    r"(4'h[0-9A-Fa-f]|default): begin pr = 4'h([0-9A-Fa-f]); "
    r"pg = 4'h([0-9A-Fa-f]); pb = 4'h([0-9A-Fa-f]);"
)


def build_mem() -> list[int]:
    src = "\n".join([
        (ROOT / "software/os/tomato_os.s").read_text(),
        (ROOT / "software/os/envelop_lite.s").read_text(),
        (ROOT / "software/os/envelop_setup.s").read_text(),
        (ROOT / "software/os/remote_exec.s").read_text(),
    ])
    return assembler.assemble(src, assembler.load_opcodes())


def build_planes() -> bytes:
    out = bytearray()
    for name in PLANES:
        rows = [0] * 512
        for addr, val in MEM_ROW.findall((BURN / name).read_text()):
            rows[int(addr)] = int(val, 16)
        assert any(rows), f"{name}: no rows parsed"
        out.extend(rows)
    return bytes(out)


def build_font() -> bytes:
    font = [0] * 2048
    for addr, val in FONT_ROW.findall((BOARD / "font_rom.v").read_text()):
        font[int(addr, 16)] = int(val, 16)
    assert any(font), "font_rom.v: no rows parsed"
    return bytes(font)


def build_palette() -> bytes:
    pal = [None] * 16
    for idx, r, g, b in PAL_ROW.findall((BOARD / "videoout.v").read_text()):
        pal[15 if idx == "default" else int(idx[3:], 16)] = (
            int(r, 16) * 17, int(g, 16) * 17, int(b, 16) * 17)
    assert all(p is not None for p in pal), "videoout.v: palette changed"
    return bytes(c for rgb in pal for c in rgb)


def build_wallpaper() -> bytes:
    vals = [int(v, 16) for v in (BOARD / "wallpaper.mem").read_text().split()]
    assert len(vals) == 320 * 240, f"wallpaper: {len(vals)} pixels"
    assert all(0 <= v < 4096 for v in vals), "wallpaper: not 12-bit"
    packed = bytearray()
    for i in range(0, len(vals), 2):
        a, b = vals[i], vals[i + 1]
        packed.extend((a >> 4, ((a & 15) << 4) | (b >> 8), b & 255))
    return bytes(packed)


def build_image() -> bytes:
    mem = build_mem()
    planes = build_planes()
    mem_bytes = struct.pack(f"<{len(mem)}I", *mem)
    source_id = hashlib.sha256(mem_bytes + planes).hexdigest()[:16].encode()
    return b"".join([
        b"TOM1", struct.pack("<II", 1, len(mem)), source_id,
        mem_bytes, planes,
        build_font(), build_palette(), build_wallpaper(),
    ])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="fail if web/data/tomato-os.bin is stale")
    args = ap.parse_args()
    import json
    sources = [
        ROOT / "software/os/tomato_os.s",
        ROOT / "software/os/envelop_lite.s",
        ROOT / "software/os/envelop_setup.s",
        ROOT / "software/os/remote_exec.s",
        ROOT / "docs/isa/tomato.v1.csv",
        BOARD / "font_rom.v",
        BOARD / "videoout.v",
        BOARD / "wallpaper.mem",
    ] + [BURN / name for name in PLANES]
    manifest = {
        "image": "data/tomato-os.bin",
        "bytes": None,
        "files": {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sources
        },
    }
    image = build_image()
    manifest["bytes"] = len(image)
    if args.check:
        if not OUT.exists() or OUT.read_bytes() != image:
            print("FAIL: web/data/tomato-os.bin is stale "
                  "(run python3 tools/build_web_image.py)", file=sys.stderr)
            return 1
        if not MANIFEST.exists() or json.loads(MANIFEST.read_text()) != manifest:
            print("FAIL: web/data/tomato-os.json is stale "
                  "(run python3 tools/build_web_image.py)", file=sys.stderr)
            return 1
        print(f"PASS: web image fresh ({len(image)} bytes)")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(image)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {OUT} ({len(image)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
