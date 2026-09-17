#!/usr/bin/env python3
"""Render an actual Envelop simulation tile dump using the checked-in FPGA ROM.

No third-party packages. Output is a 640x480 PNG, with optional integer scaling.
Rejects wallpaper/large-glyph flags rather than silently approximating them.
This checks display appearance, not CPU timing, BLE signals or FPGA resources.
"""
import argparse
from pathlib import Path
import re
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
BOARD = ROOT / 'hardware/fpga/core/rtl/board'

def render(source, destination, scale=2):
    words = [int(s, 16) for s in source.read_text().split()]
    if len(words) != 4800:
        raise ValueError('Expected exactly 80x60 tile words from simulation')
    if any(w >> 16 for w in words):
        raise ValueError('Envelop preview supports plain tiles only; extended flags found')
    font = [0] * 2048
    for addr, value in re.findall(r"mem\[11'h([0-9A-F]+)\] = 8'h([0-9A-F]+)",
                                  (BOARD / 'font_rom.v').read_text()):
        font[int(addr, 16)] = int(value, 16)
    palette = [None] * 16
    pattern = r"(4'h[0-9A-Fa-f]|default): begin pr = 4'h([0-9A-Fa-f]); pg = 4'h([0-9A-Fa-f]); pb = 4'h([0-9A-Fa-f]);"
    for index, r, g, b in re.findall(pattern, (BOARD / 'videoout.v').read_text()):
        palette[15 if index == 'default' else int(index[3:], 16)] = bytes(int(c,16)*17 for c in (r,g,b))
    assert all(palette), 'Palette format changed; update renderer'
    rows = []
    for y in range(480):
        row = bytearray()
        for x in range(640):
            word = words[(y//8)*80+x//8]
            fg, bg = (word>>8)&15, (word>>12)&15
            ink = (font[(word&255)*8+y%8] >> (x%8)) & 1
            index = (word&15) if not (word&0xff00) else fg if ink else bg
            row.extend(palette[index]*scale)
        rows.extend([b'\0'+row]*scale)
    def chunk(kind, payload):
        return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB',640*scale,480*scale,8,2,0,0,0))
    png += chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b'')
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(png)
    print(destination)

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source',type=Path)
    ap.add_argument('-o','--output',type=Path,default=ROOT/'hardware/fpga/core/sim/envelop.png')
    ap.add_argument('--scale',type=int,choices=(1,2,3,4),default=2)
    args = ap.parse_args()
    render(args.source,args.output,args.scale)
