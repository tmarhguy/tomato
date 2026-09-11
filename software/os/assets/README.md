# OS wallpaper

`ghana-wallpaper.png` was generated with OpenAI image generation on September 9,
2026 for the Tomato OS interface. It is an illustration inspired by Accra's
Black Star Gate and coastline. It is not a photograph or an exact architectural
record.

`../tools/build_wallpaper.py` converts it to 320×240 RGB444 pixels. The generated
`hardware/fpga/core/rtl/board/wallpaper.mem` contains 76,800 12-bit words. Synthesis
embeds them in FPGA block RAM. Runtime scanout scales each pixel to 2×2 pixels.
The conversion requires Pillow and does not call an image service.
