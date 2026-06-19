# UVM — 1-bit ALU slice

Combinational environment for `\alu-1b-final`. No clock agent — driver applies inputs, monitor samples on input changes.

```bash
make uvm_1b_smoke        # 128-row 0x96 exhaustive only
make uvm_1b_exhaustive   # sign-off: exhaustive + LUT256 + G/P
```

---

## Files

| File | Contents |
|------|----------|
| `alu_1b_pkg.sv` | seq_item, driver, monitor, agent, scoreboard, coverage sub, env |
| `alu_1b_seq_lib.sv` | `exhaustive`, `lut256`, `random`, `gp` sequences |
| `alu_1b_tests.sv` | `alu_1b_smoke_test`, `alu_1b_exhaustive_test` |
| `tb/tb_alu_1b.sv` | DUT hookup, `uvm_config_db` for `alu_1b_if` |

---

## Scoreboard checks (every transaction)

| Signal | Reference |
|--------|-----------|
| `MUX_OUT` | `predict_mux_1b()` — LUT3 with A_eff/B_eff |
| `G` | `A_eff & B_eff` |
| `P` | `A_eff ^ B_eff` |

No skip conditions — full input space is legal at 1b.

---

## Sequences

### `alu_1b_exhaustive_seq`

128 rows: `opcode=0x96`, all combinations of `{asel, ainv, bsel, binv, a, b, c}` (Digital arithmetic test table).

### `alu_1b_lut256_seq`

For each `opcode` in `0..255`, sends `n_per_opcode` randomized control/data vectors (default 1 in exhaustive test, 4 if run standalone).

### `alu_1b_gp_seq`

Four corner patterns on `0x96` for G/P sanity (all-1, all-0, alternating).

### `alu_1b_random_seq`

Default 1000 constrained-random transactions (smoke base test uses 500).

---

## Relation to formal

`make formal_1b` proves the same MUX/G/P equations for all inputs. UVM provides independent dynamic confirmation and opcode/control coverage collection.
