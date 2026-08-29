# Tomato — Firmware

<p align="center"><strong>Discrete-machine boot ROM — not started.</strong></p>

![Status](https://img.shields.io/badge/Status-Stub-6B7280) ![Target](https://img.shields.io/badge/Target-EEPROM%20boot-990000)

Placeholder for the discrete build's own boot image and I/O memory maps. The FPGA path already boots [Tomato OS](../software/os/tomato_os.s) from burned data memory — this tree is for the eventual 74xx machine's ROM, not a second OS.

**Project map:** [Root README](../README.md) · [Software](../software/README.md) · [Microcode](../microcode/README.md)

When this fills in: bootloader behavior, reset vectors, and peripheral MMIO as wired on the physical lots — separate from `software/os/`.
