# Tomato — ALU gauntlet

<p align="center"><strong>Verilator + SymbiYosys on the FPGA dual-LUT ALU.</strong></p>

![Formal](https://img.shields.io/badge/SymbiYosys-1b%20%2B%208b%20%2B%2032b-2ea043) ![Verilator](https://img.shields.io/badge/Verilator-10B%20%2B%20130B-DC2626)

Exhaustive-random verification of the working-machine ALU
(`hardware/fpga/core/rtl/alu.v`):

- **SymbiYosys** proves `alu1b`, `alu8b`, and the 32-bit datapath against `out = fa + fb + cin`
- **Verilator** drives **10 billion** vectors on the 8-bit slice and **130 billion** on the 32-bit ALU; every vector checks DUT against golden and exits on mismatch

This directory keeps a **committed copy** of `alu.v` — refresh with `make sync`;
do not edit `core/` from here. Every run asserts the copy matches core first
(`check-sync`), so a stale copy fails loudly instead of proving the wrong RTL.

---

## Prerequisites

| Tool | Needed for | Install |
|------|------------|---------|
| `verilator` | `smoke`, `run_10b`, `run_130b` | OSS CAD Suite (`make setup` in `hardware/fpga/core`) or `brew install verilator` |
| `sby` + solvers | `formal` | Same suite (`z3` for 1b, `bitwuzla` for 8b/32b ride along in `hardware/fpga/.tools/oss-cad-suite/bin`), or `brew install symbiyosys` |
| C++ toolchain | Verilator build | Xcode CLT / `build-essential` |

`make check-tools` asserts `sby` + `verilator` are on `PATH` with the fix.
The gauntlet Makefile prepends `hardware/fpga/.tools/oss-cad-suite/bin` to `PATH`,
so a provisioned FPGA checkout works with no extra setup.

---

## Run tiers

| Tier | Command (here or via `verification/`) | Vectors | Wall time¹ | What it proves |
|------|----------------------------------------|---------|------------|----------------|
| Smoke | `make smoke` / `make -C verification gauntlet_smoke` | 1e6 on 8b + 1e6 on 32b | ~1 min | Build works, golden matches, no gross breakage |
| 10B | `make run_10b` / `make -C verification gauntlet_10b` | 10e9 on `alu8b` (8-bit) | ~7 min | Byte-slice exhaustive-random sign-off |
| 130B | `make run_130b` / `make -C verification gauntlet_130b` | 130e9 on `alu` (32-bit) | ~2–3 h | Full-datapath exhaustive-random sign-off |
| Formal | `make formal` / `make -C verification gauntlet_formal` | exhaustive (proof) | ~minutes | 1b + 8b + 32b `Out ≡ golden` for **all** inputs |
| Claim | `make claim` / `make -C verification gauntlet_claim` | formal + 10B + 130B | ~3 h | Everything → `results/CLAIM.txt` |

¹ Measured on Apple Silicon: ~25 Mvec/s (8b), ~13–16 Mvec/s (32b).
From the repo root: `make gauntlet-smoke`, `make gauntlet-10b`,
`make gauntlet-130b`, `make gauntlet-claim`.

```bash
cd verification/gauntlet
make sync            # refresh rtl/alu.v from core (after editing the FPGA ALU)

make formal          # SymbiYosys 1b + 8b + 32b
make smoke           # quick Verilator check, 1e6 vectors each
make run_10b         # 10,000,000,000 vectors on alu8b
make run_130b        # 130,000,000,000 vectors on alu
make claim           # formal + run_10b + run_130b → results/CLAIM.txt
```

Legacy aliases `make core10b` (= `run_10b`) and `make slice130b` (= `run_130b`)
still work; new docs and CI use the `run_*` names.

---

## Custom counts and seeds (pilots, repro)

All counts and the RNG seed are overridable. The seed is fixed by default,
so a re-run with the same seed replays the same stream.

```bash
make smoke VECTORS_SMOKE=100000                    # short smoke
make run_130b VECTORS_130B=100000000 SEED=7         # 1e8 pilot before the full run
make -C verification gauntlet_130b VECTORS_130B=100000000 SEED=7
```

| Variable | Default | Meaning |
|----------|---------|---------|
| `VECTORS_SMOKE` | `1000000` | Vectors per DUT in `smoke` |
| `VECTORS_10B` | `10000000000` | Vectors in `run_10b` |
| `VECTORS_130B` | `130000000000` | Vectors in `run_130b` |
| `SEED` | `1` | xorshift64 seed (`0` → fallback stream) |
| `GAUNTLET_PROGRESS_EVERY` | `1000000000` | Vectors between `progress` status lines |

---

## Watching a long run

Every run already tees to a log file — open a second terminal and follow it:

```bash
tail -f verification/gauntlet/results/slice_130b.txt   # 130B run
tail -f verification/gauntlet/results/core_10b.txt     # 10B run
```

Log shape: one `alu32 start: target=… directed=… seed=…` banner line up front
(no more silent startup), then `progress N / TOTAL (x.xxx Gvec/s)` status lines,
then a final `PASS alu32 vectors=…` line. Default cadence is one status line per
1e9 vectors (minutes apart on some machines) — turn it up for a live run:

```bash
GAUNTLET_PROGRESS_EVERY=100000000 make run_130b   # status ~10x more often
```

`FAIL @N: …` on stderr with the exact vector means mismatch — the run exits
non-zero immediately, so any `PASS` line at the end means every vector matched.

---

## Stimulus, checking, logs

- **Directed warmup is baked in**, then random fill to the count:
  - 8b: full `lutA × lutB × {A,B,C} × cin` sweep (1,048,576 vectors), then random.
  - 32b: `PASS_A`+`PASS_B` low-byte sweep + `lutA` minterm sweep, then random
    (including periodic `flag_we` pulses so latched-carry paths are exercised).
- **Every vector is checked** against the shared golden (`verilator/golden.h`,
  mirroring `formal/alu_ref.v`). First mismatch prints the vector and exits non-zero —
  a passing run always ends with a `PASS alu8b …` / `PASS alu32 …` line stating
  vectors, directed count, seed, time, and rate. The long targets `grep` that line,
  so a truncated run fails instead of looking green.
- **Progress** prints every `GAUNTLET_PROGRESS_EVERY` vectors (default 1e9;
  `progress N / TOTAL (x.xxx Gvec/s)`), with a `… start: …` banner up front.
- **Logs** land in `results/` (gitignored): `smoke_8b.txt`, `smoke_32b.txt`,
  `core_10b.txt`, `slice_130b.txt`, and `CLAIM.txt` (claim only — records date,
  `dut_sha256`, `git_rev`, seed, and vector counts for reproducibility).

---

## Layout

```
gauntlet/
├── rtl/alu.v           committed copy of fpga/core (make sync)
├── formal/             .sby jobs + alu_ref.v + binds
├── verilator/          C++ benches + golden.h
├── obj/                build (gitignored)
└── results/            PASS logs + CLAIM.txt (gitignored)
```

Also: Digital-export ALU harness in [verification/README.md](../README.md) ·
machine in [hardware/fpga/core/README.md](../../hardware/fpga/core/README.md).
