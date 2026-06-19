# UVM — 32-bit ALU

Clock-driven environment for `\alu-32b-final` with combinational output checking, sequential flag checking, SVA bind, and Digital vector replay.

```bash
make uvm_32b_smoke       # 12 directed vectors
make uvm_32b_directed    # 476 directed + ops91
make uvm_32b_ops91       # 91-op coverage closure
make uvm_32b_flag        # CSR_FLAG with FLAG_WE
make uvm_32b_regression  # full suite (sign-off)
```

---

## Files

| File | Contents |
|------|----------|
| `alu_32b_pkg.sv` | seq_item, driver, monitor, agents, scoreboard, env |
| `alu_32b_seq_lib.sv` | ops91, random, edge, flag, directed sequences |
| `alu_32b_tests.sv` | Seven tests + `alu_32b_full_regression_test` |
| `alu_32b_assertions.sv` | `bind` module — `FLAG_WE |-> !$isunknown(CSR_FLAG)` |
| `tb/tb_alu_32b.sv` | DUT, clock, config_db |

---

## Environment structure

| Component | Role |
|-----------|------|
| `alu_32b_agent` | Active driver + monitor on `alu_32b_if` |
| `alu_32b_clk_agent` | 10 ns period clock (`#5` toggle) |
| `alu_32b_scoreboard` | `Out` + optional `CSR_FLAG` check |
| `alu_32b_coverage` | Mode/opcode/op91/flag bins |

Driver applies stimulus, waits `@(posedge clk)`, samples `Out`/`CSR_FLAG` one cycle later.

---

## Scoreboard

**Combinational `Out`:** `predict_out_dut()` — full golden; tries `flag_c` 0 and 1 when `csel==2'b10`.

**Flags:** when `flag_we`, lower 12 bits of `CSR_FLAG` vs `predict_csr_flag()`.

---

## Tests

| Test | Sequences run |
|------|---------------|
| `alu_32b_smoke_test` | `alu_32b_smoke_directed_seq` (12 vectors) |
| `alu_32b_directed_test` | full 476 directed + ops91 |
| `alu_32b_ops91_test` | ops91 only |
| `alu_32b_random_test` | 5000 random (`+COUNT=N` plusarg) |
| `alu_32b_edge_test` | 8 data patterns × ADD + SUB with `FLAG_WE` |
| `alu_32b_flag_test` | 500 random SUB + `flag_we` |
| `alu_32b_full_regression_test` | directed + ops91 + edge + 200 flag + 10k random |

---

## Sequences (detail)

### `alu_32b_directed_seq`

Unpacks `VECTORS[i]` from `directed_vectors_pkg` — same 476 vectors as Icarus `make directed`.

### `alu_32b_ops91_seq`

For `i = 0..NUM_OPS-1`, randomizes `A/B/C` with `opcode/control/csel` locked to `OP_TABLE[i]`; applies fixed `cin` when `cin_fixed >= 0`.

### `alu_32b_edge_seq`

Patterns: `0, ~0, MAX_INT, MIN_INT, DEADBEEF, AAA…, 555…, 1` — exercised as ADD (`csel=0, ctrl=5`) and SUB (`csel=1, ctrl=D, cin=1`) with optional `FLAG_WE`.

### `alu_32b_flag_seq`

Random SUB with `flag_we=1` to stress dual-rail flag latches.

---

## SVA (`alu_32b_assertions.sv`)

Bound into `\alu-32b-final`:

```systemverilog
assert property (@(posedge CLK) FLAG_WE |-> !$isunknown(CSR_FLAG));
```

Combinational stability assertion is documented but not enabled (input changes make `$stable(Out)` too noisy — timing check lives in scoreboard).

---

## Relation to formal

| Formal job | UVM counterpart |
|------------|-----------------|
| `formal_32b_equiv` (full comb) | directed + ops91 + random — same golden |
| `formal_32b` (12 spot) | fast smoke subset |
| `formal_32b_flags` (cover) | `alu_32b_flag_test` proves exact flag values |

Formal proves spot properties; UVM proves end-to-end behavior under clocked flag writes and 476 Digital goldens (via ref model, not embedded expected values).
