# Exploring Beyond Vivado: The Open-Source Synthesis Pivot

With the HDMI 12-bit PMOD test successfully throwing pixels on the glass, my next hurdle was the build process itself. Up until now, I've been relying on Xilinx Vivado for synthesis and routing. 

The problem? Vivado is notoriously heavy and incredibly slow by default, especially on my laptop. Waiting for simple design changes to synthesize completely breaks my flow. I wanted to explore tools that are as fast as possible, which led me down the rabbit hole of open-source FPGA toolchains.

My research points to a completely open-source (FOSS) stack tailored for the Nexys A7-100T:
- **Yosys** for fast synthesis (converting SystemVerilog/Verilog to a JSON netlist)
- **nextpnr-xilinx** for lightning-fast place and route
- **Project X-Ray** for generating the final bitstream
- **openFPGALoader** for flashing the board via JTAG

Using the `openXC7` Nix toolchain, I can pull all of these tools into an isolated shell. 

Going forward, I will be ditching the slow Vivado environment on my laptop and doing all future synthesis natively on my Mac using this open-source stack. Once I figure out the exact `Makefile` wiring to compile the entire Tomato core, the build-to-flash loop should drop from painful minutes down to seconds!
