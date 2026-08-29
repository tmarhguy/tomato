The PMOD 12-bit DVI V1.1b module finally arrived today, and I went straight to work soldering the pins. This interface from my research is designed to make VGA and HDMI output straightforward directly from the FPGA, bypassing those passive adapters that were giving me trouble earlier. 

After soldering, I flashed a quick test pattern. Oh man, it immediately worked—throwing pure red, green, blue, and gray bars right up on the screen via HDMI!

<video src="../../web/assets/assembly/hdmi-test.mp4" poster="../../web/assets/assembly/hdmi-test.webp" controls playsinline style="display: block; margin: 0 auto; width: 70%;"></video>

With the video peripheral working properly, I can finally resume full HDMI testing. Next up is getting it to display TomatoOS and a few of the other graphical features I’ve already built into the architecture. Seeing actual pixels on the glass makes all the abstract logic suddenly feel very real!