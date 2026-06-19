# UVM common — shared packages

Imported by all three ALU UVM environments. No DUT instantiation here.

## Files

| File | Package / module | Role |
|------|------------------|------|
| `alu_types_pkg.sv` | `alu_types_pkg` | `alu_1b_txn_t`, `alu_8b_txn_t`, `alu_32b_txn_t` structs |
| `alu_op_table_pkg.sv` | `alu_op_table_pkg` | **Generated** — `OP_TABLE[91]` with `lut`, `ctrl`, `csel`, `cin_fixed`, `is_logic` |
| `directed_vectors_pkg.sv` | `directed_vectors_pkg` | **Generated** — `VECTORS[476]` 144-bit packed stimulus |
| `alu_ref_model_pkg.sv` | `alu_ref_model_pkg` | Behavioral golden: `predict_out`, `predict_mux_1b`, `predict_gp_*`, `predict_csr_flag` |
| `alu_if.sv` | `alu_1b_if`, `alu_8b_if`, `alu_32b_if` | Virtual interfaces wired in each TB |
| `alu_cov_pkg.sv` | `alu_cov_pkg` | Per-slice covergroups + 32b `op91_cp` cross to `OP_TABLE` |

Regenerate op table and vectors: `make generate` (see [../scripts/README.md](../scripts/README.md)).

---

## Reference model (`alu_ref_model`)

### Effective operands

```
eff1(sel, inv, val) = (sel & val) ^ inv

A_eff[i] from control[0], control[1]
B_eff[i] from control[2], control[3]
```

### Combinational `Out` (unified ripple-LUT model)

Per bit `i`:
```
out[i] = opcode[{cin[i], B_eff[i], A_eff[i]}]
carry[i] = G | (P & cin[i])   where G = A_eff[i]&B_eff[i], P = A_eff[i]^B_eff[i]
cin[0] = 0 (csel=00), 1 (csel=01), flag_c (csel=10), C[0] (csel=11)
cin[i>0] = carry[i-1] unless csel=11 → C[i]
```

`predict_out_dut()` accepts `flag_c` 0 or 1 when `csel==10` for scoreboard (matches latched carry uncertainty in sim).

### Flags (`predict_csr_flag`)

Dual-rail encoding when `FLAG_WE` (checked in 32b scoreboard on lower 12 bits):

```
[1]=~Z (1 when Out==0), [0]=Z, [2]=N, [3]=~N, carry/overflow/compare rails ...
```

Uses signed compare on raw `A`/`B` for LT/GT/LTE/GTE bits.

---

## Coverage highlights

- **1b:** all 256 opcodes, all 16 control tuples, ABC data
- **8b:** opcode × control cross, walk/zero/ones data bins
- **32b:** `csel` mode bins, opcode×control×csel cross, `op91_cp` matched against `OP_TABLE`, `flag_we_cp`

`alu_32b_coverage.sample()` sets `matched_op` by matching `(opcode, control, csel)` to `OP_TABLE[i]` for ops91 coverage closure.
