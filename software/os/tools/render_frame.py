#!/usr/bin/env python3
"""Render an os_tb +FRAME tile dump with the FPGA font and palette (Pillow)."""
import argparse
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BOARD = ROOT / 'hardware/fpga/core/rtl/board'


def render(source, output, scale=2):
    tiles = [int(word, 16) for word in source.read_text().split()]
    if len(tiles) != 80 * 60:
        raise ValueError('expected exactly 4,800 framebuffer tiles')
    font = [0] * 2048
    for address, value in re.findall(r"mem\[11'h([0-9A-F]+)\] = 8'h([0-9A-F]+)",
                                     (BOARD / 'font_rom.v').read_text(), re.I):
        font[int(address, 16)] = int(value, 16)
    palette = [(255, 255, 255)] * 16
    pattern = r"4'h([0-9A-F]): begin pr = 4'h([0-9A-F]); pg = 4'h([0-9A-F]); pb = 4'h([0-9A-F]);"
    for index, r, g, b in re.findall(pattern, (BOARD / 'videoout.v').read_text(), re.I):
        palette[int(index, 16)] = tuple(int(v, 16) * 17 for v in (r, g, b))
    paper = [int(w,16) for w in (BOARD/'wallpaper.mem').read_text().split()]
    result = Image.new('RGB', (640, 480))
    pixels = result.load()
    for cell, tile in enumerate(tiles):
        glyph, fg, bg = tile & 255, (tile >> 8) & 15, (tile >> 12) & 15
        x, y = (cell % 80) * 8, (cell // 80) * 8
        for row in range(8):
            for col in range(8):
                fr = ((tile >> 20) & 1) * 4 + row // 2 if tile & (1<<18) else row
                fc = ((tile >> 19) & 1) * 4 + col // 2 if tile & (1<<18) else col
                ink = bool(font[glyph * 8 + fr] & (1 << fc))
                color = fg if ink else bg
                if tile & 0xff00 == 0:
                    color = tile & 15  # Legacy solid-tile path in videoout.v.
                rgb = palette[color]
                if tile & (1<<16) and (tile & 0xff00 == 0 or not ink):
                    w = paper[((y+row)//2)*320+(x+col)//2]
                    channels = [(w>>8)&15,(w>>4)&15,w&15]
                    if tile & (1<<17): channels = [v>>2 for v in channels]
                    rgb = tuple(v*17 for v in channels)
                pixels[x + col, y + row] = rgb
    result.resize((640 * scale, 480 * scale), Image.Resampling.NEAREST).save(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--scale', type=int, choices=range(1, 5), default=2)
    args = parser.parse_args()
    render(args.source, args.output, args.scale)
