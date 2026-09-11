#!/usr/bin/env python3
"""Encode wallpaper into a synthesizable 320x240 RGB444 scanout ROM."""
from pathlib import Path
from PIL import Image, ImageOps
ROOT = Path(__file__).resolve().parents[3]
image = ImageOps.fit(Image.open(ROOT/'software/os/assets/ghana-wallpaper.png').convert('RGB'), (320,240), method=Image.Resampling.LANCZOS)
words = [(r>>4)<<8 | (g>>4)<<4 | (b>>4) for r,g,b in image.getdata()]
# readmemh at synthesis embeds the pixels in BRAM; no host/file access at runtime.
out = ROOT/'hardware/fpga/core/rtl/board/wallpaper.mem'
out.write_text(''.join(f'{w:03x}\n' for w in words))
print(f'{len(words)} RGB444 pixels -> {out}')
