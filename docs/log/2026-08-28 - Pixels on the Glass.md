# Pixels on the Glass

The PMOD 12-bit DVI V1.1b module finally arrived, and I went straight to work soldering the pins. This interface is designed to make VGA and HDMI output straightforward directly from the FPGA — bypassing those passive adapters that were giving me trouble earlier.

After soldering, I flashed a quick test pattern. It immediately worked: pure red, green, blue, and gray bars right up on the screen via HDMI.

<video src="../../web/assets/assembly/hdmi-test.mp4" poster="../../web/assets/assembly/hdmi-test.webp" controls playsinline style="display: block; margin: 0 auto; width: 70%;"></video>

<p align="center"><img src="../../web/assets/assembly/fpga-board-pmod.webp" alt="Nexys A7 with iCEBreaker 12-bit DVI PMOD on JC and JD" width="70%" /></p>

Video peripheral is working again, so I can get back to HDMI testing. Next step is TomatoOS and the other GUI stuff already in the architecture. Color bars on a monitor beat staring at waveforms.

Earlier: [the PMOD pivot](2026-08-26%20-%20The%20PMOD%20Pivot.md) when VGA adapters failed. Same day on the bench: [Successful Video / FPGA + PMOD](2026-08-28%20-%20Successful%20Video%20-%20FPGA%20+%20PMOD.md). Paper: [pixels-on-glass](https://tomato.tmarhguy.com/journal/pixels-on-glass.html).
