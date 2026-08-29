# Tomato — ALU gauntlet

<p align="center"><strong>Verilator + SymbiYosys on the FPGA dual-LUT ALU.</strong></p>

![Formal](https://img.shields.io/badge/SymbiYosys-1b%20%2B%208b%20%2B%2032b-2ea043) ![Verilator](https://img.shields.io/badge/Verilator-10B%20%2B%20130B-DC2626)

What ran on the working machine ALU (`hardware/fpga/core/rtl/alu.v`):

- **SymbiYosys** proved `alu1b`, `alu8b`, and the 32-bit datapath against `out = fa + fb + cin`
- **Verilator** drove **10 billion** vectors on the 8-bit slice and **130 billion** on the 32-bit ALU; every vector checks DUT against golden and exits on mismatch

This directory is the source for those runs. It keeps a **copy** of `alu.v` — refresh with `make sync`; do not edit `core/` from here.

```bash
cd verification/gauntlet
make sync            # pull alu.v from core
make formal          # SymbiYosys 1b + 8b + 32b
make smoke           # quick Verilator (1e6)
make core10b         # 10e9 on alu8b
make slice130b       # 130e9 on alu
make claim           # formal + core10b + slice130b
```

Needs the FPGA OSS CAD Suite on `PATH` (`make setup` in `hardware/fpga/core`, or the Makefile prepends `hardware/fpga/.tools/oss-cad-suite/bin`).

| Target | Does |
|--------|------|
| `formal` | Prove 1b / 8b / 32b Out ≡ golden |
| `smoke` | 1e6 vectors, 8b + 32b |
| `core10b` | 10,000,000,000 on `alu8b` |
| `slice130b` | 130,000,000,000 on `alu` |
| `claim` | All of the above → `results/CLAIM.txt` |

Directed warmup is baked in (lut×minterm×cin on 8b; PASS_A+PASS_B low-byte on 32b), then random fill to the count. Measured on Apple Silicon: ~25 Mvec/s (8b), ~13–16 Mvec/s (32b) → about **7 minutes** for 10B and **~2–3 hours** for 130B.

```
gauntlet/
├── rtl/alu.v           copy of fpga/core (make sync)
├── formal/             .sby jobs + alu_ref.v
├── verilator/          C++ benches
├── obj/                build (gitignored)
└── results/            PASS logs (gitignored)
```

Also: Digital-export ALU harness in [verification/README.md](../README.md) · machine in [hardware/fpga/core/README.md](../../hardware/fpga/core/README.md).
