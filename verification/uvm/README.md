# UVM — dynamic simulation

Three self-contained UVM environments (1b, 8b, 32b) sharing packages in `common/`. All scoreboards use `alu_ref_model_pkg` — the same behavioral equations as formal bind modules.

**Requires Questa** (`vlog` + `vsim` on `PATH`). Not executed in GitHub CI today.

```bash
make uvm_1b_exhaustive      # 1b sign-off test
make uvm_8b_full            # 8b sign-off test
make uvm_32b_regression     # 32b full suite
make uvm_regression         # all three above
```

Override test: `make uvm_32b_random UVM_TEST=alu_32b_edge_test SEED=42`

---

## Architecture

```
uvm/
├── common/          Shared types, ref model, op table, directed vectors, coverage, interfaces
├── alu_1b/          Combinational 1b env (no clock)
├── alu_8b/          Combinational 8b env (no clock)
└── alu_32b/         Clocked 32b env + SVA bind + flag checking
```

Each slice package contains: `seq_item`, driver, monitor, sequencer, agent, scoreboard, coverage subscriber, env, sequences, tests, and `tb/tb_alu_*.sv`.

---

## Makefile targets

### 1-bit

| Target | Test class | Sequences |
|--------|------------|-----------|
| `uvm_1b_smoke` | `alu_1b_smoke_test` | 128-row exhaustive (`0x96` only) |
| `uvm_1b_exhaustive` | `alu_1b_exhaustive_test` | exhaustive + LUT256 (1 vec/opcode) + G/P corners |

### 8-bit

| Target | Test class | Sequences |
|--------|------------|-----------|
| `uvm_8b_smoke` | `alu_8b_smoke_test` | CLA boundary + logic sweep |
| `uvm_8b_full` | `alu_8b_full_test` | CLA boundary + logic sweep + 5000 random |

### 32-bit

| Target | Test class | What runs |
|--------|------------|-----------|
| `uvm_32b_smoke` | `alu_32b_smoke_test` | First 12 directed vectors |
| `uvm_32b_directed` | `alu_32b_directed_test` | 476 directed + ops91 |
| `uvm_32b_ops91` | `alu_32b_ops91_test` | One randomized stimulus per `OP_TABLE` entry |
| `uvm_32b_random` | `alu_32b_random_test` | 5000 random (override: `+COUNT=N`) |
| `uvm_32b_edge` | `alu_32b_edge_test` | Overflow/wrap patterns on ADD/SUB |
| `uvm_32b_flag` | `alu_32b_flag_test` | 500 SUB + `FLAG_WE` flag checks |
| `uvm_32b_regression` | `alu_32b_full_regression_test` | directed + ops91 + edge + 200 flag + 10k random |

---

## 32b scoreboard

Uses `predict_out_dut()` — full unified golden; accepts `flag_c` 0 or 1 when `csel==2'b10`. No opcode/`csel` skips.

---

## Compile file lists

Defined in `Makefile`:

- **Common:** `alu_types_pkg`, `alu_op_table_pkg`, `directed_vectors_pkg`, `alu_ref_model_pkg`, `alu_if`, `alu_cov_pkg`
- **32b adds:** `alu_32b_pkg`, `alu_32b_assertions.sv`, `rtl/alu-32b-final.v`, `tb/tb_alu_32b.sv`

Work libraries: `work/alu_1b`, `work/alu_8b`, `work/alu_32b`.

---

## Subfolder docs

| Folder | Doc |
|--------|-----|
| Shared packages | [common/README.md](common/README.md) |
| 1-bit env | [alu_1b/README.md](alu_1b/README.md) |
| 8-bit env | [alu_8b/README.md](alu_8b/README.md) |
| 32-bit env | [alu_32b/README.md](alu_32b/README.md) |
