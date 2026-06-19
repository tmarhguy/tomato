# Mosaic32 ALU — Verification Harness

**How the ALU is verified here:** layered proof from the 1-bit programmable-LUT cell up through the exported 32-bit netlist — SymbiYosys formal (1b → 8b → 32b comb + sequential flag cover), Icarus directed replay of Digital test vectors, and full UVM dynamic simulation with a shared reference model.

**Harness root:** `verification/` · **RTL policy:** Digital exports in `rtl/` are read-only.

**Related (historical):** [Verification.md](../Verification.md) documents the earlier mosaic32 Verilator fuzz harness (40B 1b + 130B 32b). This tree is the current sign-off path for the repo.

---

## Table of Contents

- [Summary (latest run)](#summary-latest-run)
- [What each layer proves](#what-each-layer-proves)
- [Quick start](#quick-start)
- [Layout](#layout)
- [Sign-off criteria](#sign-off-criteria)
- [Known limits](#known-limits)
- [Related docs](#related-docs)

---

## Summary (latest run)

**Date:** 2026-06-19 · **Netlist:** `rtl/alu-32b-final.v` (Digital export)

| Step | Tool | Scope | Result | Notes |
|------|------|-------|--------|-------|
| G | `generate.py` | 91-op table + 476 directed vectors | **PASS** | Skips 6 flag-only vectors (exp=`x`) |
| F1 | SymbiYosys | `alu-1b-final` — LUT3 + G/P | **PASS** | k-induction, z3 |
| F2 | SymbiYosys | `alu-8b-final` — per-bit LUT3 + G/P | **PASS** | k-induction, z3 |
| F3 | SymbiYosys | `alu-32b-final` — 12 spot properties | **PASS** | fast regression |
| F4 | SymbiYosys | `alu-32b-final` **full comb equiv** | **PASS** | ~74 s — all inputs, `CSR_FLAG[4]` as `flag_c` |
| F5 | SymbiYosys | flags reachability | **PASS** | cover mode |
| L | Verilator | Lint all slices | **PASS** | |
| D | Icarus | **476/476** vectors vs golden | **PASS** | no skips; `flag_c` 0/1 for `csel=10` |
| U | Questa UVM | 1b + 8b + 32b | **Requires Questa** | scoreboard uses full golden |

```bash
make signoff        # fast CI (~35 s): spot formal + directed + lint
make signoff_full   # adds formal_32b_equiv end-to-end comb proof
```

---

## What each layer proves

| Layer | Proven property |
|-------|-----------------|
| **Formal 1b** | For all inputs: `MUX_OUT = OPCODE[{C,B_eff,A_eff}]`, `G = A_eff & B_eff`, `P = A_eff ^ B_eff`. Complete programmable-LUT plane for one bit. |
| **Formal 8b** | Same relations applied independently to each of 8 bit-slices (parallel 1b composition). |
| **Formal 32b equiv** | `Out === golden(..., CSR_FLAG[4])` for all inputs (`make formal_32b_equiv`) |
| **Formal 32b spot** | 12 fast regression properties — subset of equiv (`make formal_32b`) |
| **Formal 32b flags** | Cover: FLAG_WE reachability (`make formal_32b_flags`) |
| **Directed** | **476/476** vs unified golden (all `csel`, all opcodes) | `make directed` |
| **UVM 1b** | Scoreboard on every stimulus: MUX_OUT + G + P vs `alu_ref_model_pkg`. Exhaustive test: 128-row `0x96` table + 256× LUT sweep + G/P corners. |
| **UVM 8b** | Full 8b `out`, `G`, `P` vs ref model; random, CLA boundary, and logic-sweep sequences. |
| **UVM 32b** | Clock-driven env; comb `Out` check + `CSR_FLAG` when `FLAG_WE`; 91-op coverage bin; SVA `FLAG_WE → !$isunknown(CSR_FLAG)`; 7 tests + full regression. |

---

## Quick start

```bash
cd verification

# No simulator license required
make signoff              # fast CI (~35 s)
make signoff_full         # + 32b equiv prove (~3 min)
make formal_32b_equiv     # full comb proof (~74 s)
make directed             # 476 vectors (Icarus)
make generate             # regenerate op table + vectors

# Questa required (vlog/vsim on PATH)
make uvm_1b_exhaustive
make uvm_8b_full
make uvm_32b_regression   # directed + ops91 + edge + flag + 10k random
make uvm_regression       # 1b exhaustive + 8b full + 32b regression
```

**Dependencies (local sign-off):** `python3`, `yosys`, `symbiyosys` (`sby`), `z3`, `iverilog`, `verilator`.

**UVM:** [Questa Intel FPGA Starter](https://www.intel.com/content/www/us/en/software-kit/750666/intel-quartus-prime-lite-edition-design-software-version-23-1-for-windows.html) or equivalent with `vlog`/`vsim`.

---

## Layout

```
verification/
├── README.md           ← you are here
├── Makefile            ← all targets
├── rtl/                → [rtl/README.md](rtl/README.md)
├── formal/             → [formal/README.md](formal/README.md)
├── directed/           → [directed/README.md](directed/README.md)
├── uvm/                → [uvm/README.md](uvm/README.md)
│   ├── common/         → [uvm/common/README.md](uvm/common/README.md)
│   ├── alu_1b/         → [uvm/alu_1b/README.md](uvm/alu_1b/README.md)
│   ├── alu_8b/         → [uvm/alu_8b/README.md](uvm/alu_8b/README.md)
│   └── alu_32b/        → [uvm/alu_32b/README.md](uvm/alu_32b/README.md)
└── scripts/            → [scripts/README.md](scripts/README.md)
```

Generated at build time (gitignored in root `.gitignore`): `work/`, `results/`, `formal/alu_*_verify/`, `directed/run_extracted_tb.v`. RTL netlists in `rtl/*.v` are local Digital copies (`*.v` ignored globally).

---

## Sign-off criteria

| Metric | Target | Command |
|--------|--------|---------|
| Formal 1b LUT + G/P | PASS (prove) | `make formal_1b` |
| Formal 8b per-bit | PASS (prove) | `make formal_8b` |
| Formal 32b equiv | PASS (all inputs) | `make formal_32b_equiv` |
| Formal 32b spot | PASS (fast) | `make formal_32b` |
| Formal 32b flags | PASS (cover) | `make formal_32b_flags` |
| Directed vectors | 476/476 pass | `make directed` |
| Lint | 0 errors | `make lint` |
| UVM 91-op coverage | 100% `op91_cp` bins | `make uvm_32b_ops91` |
| UVM directed replay | 476 vectors | `make uvm_32b_directed` |
| UVM full regression | 0 scoreboard errors | `make uvm_32b_regression` |

---

## Known limits

| Limit | Status |
|-------|--------|
| `csel==2'b10` carry-fed logic | **Closed** — unified ripple-LUT golden; `Flag_C` primary input in formal |
| All 91 ops / 476 vectors | **Closed** — directed + UVM scoreboard (no skips) |
| Sequential `CSR_FLAG` prove | **Cover + UVM** — SMT latch prove not feasible; use `alu_32b_flag_test` |
| UVM in CI | Questa not in GitHub Actions |

---

## Related docs

| Doc | Link |
|-----|------|
| Historical Verilator report | [Verification.md](../Verification.md) |
| 91-op control map (authority) | [docs/alu/alu-1b/alu_control_map.tex](../docs/alu/alu-1b/alu_control_map.tex) |
| CI workflow | [.github/workflows/alu-verification.yml](../.github/workflows/alu-verification.yml) |
| Root test shortcut | `make test` → `make -C verification signoff` |
