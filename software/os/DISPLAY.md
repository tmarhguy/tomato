# Tomato Display — MMIO contract

Engineer reference for the display window at **`0x300000`** (`mem_addr[21:19] == 3'b110`).

Two modes share one bus decode; **MODE** selects which backing store answers CPU traffic in the low 64 KiB.

## Mode register

| Byte address | Name | Access | Description |
|--------------|------|--------|-------------|
| `0x310000` | `MODE` | R/W | bit 0: **0** = text (default), **1** = bitmap |

Reads return `{31:1}=0, mode}`. Writes with `mem_wr` set bit 0.

## Mode 0 — Text (80×60 cells)

| Byte range | Access | Format |
|------------|--------|--------|
| `0x300000` … `0x307FFF` | R/W word | Tile word per 13-bit index `mem_addr[12:0]` |

Tile word (unchanged from Tomato v1):

```
[ 7: 0] glyph   CP437-ish code → font_rom
[11: 8] fg      palette index (ink)
[15:12] bg      palette index (paper)
```

Legacy solid: `[15:8]==0` → flat colour `palette[3:0]`.

Scanout: **640×480@60**, **80×60** grid of **8×8** glyphs (`rtl/board/videoout.v`).

## Mode 1 — Bitmap (320×200 indexed)

| Byte range | Access | Format |
|------------|--------|--------|
| `0x300000` … `0x30FFFF` | R/W byte | One palette index per pixel, row-major `y*320+x` |

- **320×200** logical pixels, **2×** nearest-neighbour upscale to **640×400**, centred on **640×480** (40-row letterbox).
- CPU may use **`SW`/`LW`** (four bytes per word, little-endian within the word). **`SB`/`LB`** work in simulation; on the **FPGA** bitmap stores must be **word-aligned `SW`** until byte-lane merge is added to the framebuffer BRAM path.
- Palette: **256×12-bit RGB** (4:4:4), programmed through the palette port below. On reset, indices **0–15** match the arcade text palette; **16–255** default to grey ramp.

## Palette port (both modes)

| Byte address | Name | Write | Read |
|--------------|------|-------|------|
| `0x310004` | `PAL_IDX` | `[7:0]` = index 0–255 | current index |
| `0x310008` | `PAL_RGB` | `[11:0]` = `{R4,G4,B4}` for `PAL_IDX` | colour at index |

Write order: set `PAL_IDX`, then write `PAL_RGB`. Scanout uses the table on the pixel clock domain.

## Software notes

- **Tomato OS** desktop stays in **mode 0**.
- **Doom / games** should switch to **mode 1**, paint pixels with `SB`, then restore mode 0 on exit.
- Full-screen clear in bitmap mode: 64 000 byte stores — budget ~10 ms at 6.25 MHz if naïve; prefer dirty rectangles.

## Hardware map (FPGA → discrete)

| Block | Role |
|-------|------|
| `rtl/display.v` | Dual-port tile RAM + 64 KiB framebuffer (reuses tile BRAM for low 32 KiB) + registers |
| `rtl/disp_fb_bank.v` | Upper 32 KiB framebuffer bank (BRAM pair) |
| `rtl/board/videoout.v` | Text or bitmap scanout + palette |
| Lot 08 (future) | Same register map on copper |

## Constants (assembly)

```asm
            LUI     r8, 0x300           ; display window base
            ; MODE  = 0x310000  →  LA r11, mode_reg  with .word 0x310000
            ; PAL   = 0x310004 / 0x310008
```

Pointers above `0x1000` must use `.word` tables — `LA` cannot reach them.
