# Formal — SymbiYosys proofs

Five SymbiYosys jobs on the Digital-exported netlists. Engine: **`smtbmc z3`** for all jobs.

## Jobs

| Job | `.sby` | Top module | Mode | Status |
|-----|--------|------------|------|--------|
| 1b LUT + G/P | `alu_1b_verify.sby` | `alu_1b_verify` | prove | **PASS** |
| 8b per-bit | `alu_8b_verify.sby` | `alu_8b_verify` | prove | **PASS** |
| 32b spot checks | `alu_32b_verify.sby` | `alu_verify` | prove | **PASS** (~30 s) |
| **32b full equiv** | `alu_32b_equiv_verify.sby` | `alu_32b_equiv_verify` | prove | **PASS** (~74 s) |
| 32b flags | `alu_32b_flags_verify.sby` | `alu_32b_flags_verify` | cover | **PASS** |

```bash
make formal_all              # fast: 1b + 8b + 32b spot + flags cover
make formal_32b_equiv        # full comb equivalence (authoritative 32b proof)
make signoff_full            # formal_all + equiv + lint + directed
```

Build artifacts land in `formal/alu_*_verify/` (gitignored). `make clean` removes them.

Source binds live in `formal/`; golden functions in `directed/alu_ref.v` (copied into SBY `src/` at run time).

---

## 1-bit (`alu_1b_verify_bind.v`)

For **all** inputs (k-induction, depth 1):

```systemverilog
assert (MUX_OUT == OPCODE[{C, B_eff, A_eff}]);
assert (G == (A_eff & B_eff));
assert (P == (A_eff ^ B_eff));
```

---

## 8-bit (`alu_8b_verify_bind.v`)

Same relations per bit slice `i = 0..7` on `out[i]`, `G[i]`, `P[i]`.

---

## 32-bit full equivalence (`alu_32b_equiv_verify_bind.v`)

**Authoritative 32b proof** — for all inputs:

```systemverilog
assert (Out === alu_predict_out(A, B, C, Opcode, control, csel, CSR_FLAG[4]));
```

`CSR_FLAG[4]` is the latched carry (`flag_c`) used as bit-0 LUT carry-in when `csel==2'b10`.

Golden: per-bit `out[i] = opcode[{cin[i], B_eff[i], A_eff[i]}]` with ripple carry; `cin[0]` from `csel` (`0/1/flag_c/C[0]`).

---

## 32-bit spot checks (`alu_32b_verify_bind.v`)

Fast regression (~30 s) — twelve conditional properties (ADD, SUB, AND, OR, XOR, LUT3 at `csel==11`, etc.). Subsumed by `formal_32b_equiv` but kept for quick CI feedback.

---

## 32-bit flags (`alu_32b_flags_verify_bind.v`)

**Cover mode** — `FLAG_WE` reachability and dual-rail sanity. Exact latch values checked in UVM (`alu_32b_flag_test`).

Sequential flag **prove** was attempted but fails SMT (dual-rail + latch timing); not shipped.

---

## Control decode (shared with `directed/alu_ref.v`)

```
control[0] = asel    control[1] = ainv
control[2] = bsel    control[3] = binv

A_eff = (asel ? A : 0) ^ (ainv ? ~0 : 0)
B_eff = (bsel ? B : 0) ^ (binv ? ~0 : 0)
```

`csel`: `00` → cin 0, `01` → cin 1, `10` → `flag_c` at bit 0 + ripple, `11` → `C[i]` per bit.
