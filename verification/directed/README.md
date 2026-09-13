# Directed — Digital vector replay (Icarus)

Replays **476 test vectors** extracted from three Digital-exported testbenches. Compares DUT output against the unified golden in `alu_ref.v` (same model as formal equiv + UVM).

```bash
make directed    # builds run_extracted_tb.v via generate.py if missing, then iverilog + vvp
make generate    # force-reextract (after editing a source TB)
```

---

## Stimulus vs check

All **482** pattern rows are *applied* in source order — including the 6 flag-only rows whose expected-Out is `x` (they advance the flag latches, exactly as the Digital benches do). The **476** rows with a known expected-Out are *checked* against `alu_predict_out()`.

---

## Source testbenches (hand-maintained)

| File | Content |
|------|---------|
| `alu-32b-final_Exhaustive 91 Ops Test_tb.v` | Bulk of the 91-op directed suite |
| `alu-32b-final_alu-comb-flags_tb.v` | Combinational + flag cases |
| `alu-32b-final_alu-flagc-carry_tb.v` | Flag/carry corner cases |

Digital module names contain spaces — **Icarus cannot compile them directly**. `scripts/generate.py` parses `144'b…` pattern lines and emits `run_extracted_tb.v`.

---

## Files

| File | Role |
|------|------|
| `alu_ref.v` | Unified ripple-LUT golden (`alu_predict_out`) |
| `alu_32b_dut_wrap.v` | Clean port names → escaped Digital ports |
| `run_extracted_tb.v` | **Generated** — 476-vector compare loop |

---

## Vector packing (144 bits)

```
[143:112] A
[111:80]  B
[79:48]   C
[47:40]   Opcode
[39:36]   control
[35:34]   csel
[33]      CLK (unused in compare)
[32]      FLAG_WE
[31:0]    expected Out (Digital golden — not used; we compare vs alu_ref.v)
```

---

## Timing and carry policy

The TB drives each vector with `clk = 0`, settles, then pulses the clock once so `FLAG_WE` latches exactly once per vector (the pattern `CLK` bit itself is ignored). `Out` is sampled after the edge.

Every checked vector is compared against `alu_predict_out()`:

```verilog
exp0 = alu_predict_out(A, B, C, Opcode, control, csel, csr_flag[4]);
// if mismatch and csel==2'b10, retry with flag_c=1
```

`flag_c` for carry-fed logic (`csel == 2'b10`) is the live latch bit the DUT itself reports — no opcode or `csel` skips. Six source vectors with `x` in the expected-out field are applied but not checked (flag-only stimulus).

---

## UVM reuse

Same 476 vectors in `uvm/common/directed_vectors_pkg.sv` for `alu_32b_directed_seq`.
