# UVM — 8-bit ALU slice

Combinational environment for `\alu-8b-final`. Scoreboard checks full 8-bit `out`, `G`, and `P` vectors against the 1b-composed ref model.

```bash
make uvm_8b_smoke     # CLA boundary + logic sweep
make uvm_8b_full      # sign-off: boundary + sweep + 5000 random
```

---

## Files

| File | Contents |
|------|----------|
| `alu_8b_pkg.sv` | Full env + sequences + tests (single package file) |
| `tb/tb_alu_8b.sv` | DUT + interface |

Tests and sequences are included at the bottom of `alu_8b_pkg.sv`:

- `alu_8b_smoke_test` — CLA boundary + logic sweep
- `alu_8b_full_test` — above + 5000 random
- `alu_8b_random_seq`, `alu_8b_cla_boundary_seq`, `alu_8b_logic_sweep_seq`

---

## Scoreboard checks (every transaction)

| Signal | Reference |
|--------|-----------|
| `out[7:0]` | `predict_out_8b()` — per-bit LUT3 with shared opcode/control |
| `G[7:0]` | per-bit `A_eff & B_eff` |
| `P[7:0]` | per-bit `A_eff ^ B_eff` |

No skip conditions at 8b — illegal modes are a 32b integration concern.

---

## Sequences

### `alu_8b_random_seq`

Constrained-random opcode, control, and data.

### `alu_8b_cla_boundary_seq`

Stimulus aimed at carry propagate/generate boundaries (0xFF/0x01 style patterns).

### `alu_8b_logic_sweep_seq`

Walks carry-independent 2-variable logic encodings at canonical `control`.

---

## Relation to formal

`make formal_8b` proves per-bit LUT3 + G/P on the exported 8b netlist. UVM adds stimulus diversity and cross coverage (`opcode_cp` × `ctrl_cp`).
