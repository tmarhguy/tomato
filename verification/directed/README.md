# Directed — Digital vector replay (Icarus)

Replays **476 test vectors** extracted from three Digital-exported testbenches. Compares DUT output against the unified golden in `alu_ref.v` (same model as formal equiv + UVM).

```bash
make directed    # runs generate first, then iverilog + vvp
```

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

## Compare policy

Every vector is checked against `alu_predict_out()`:

```verilog
exp0 = alu_predict_out(A, B, C, Opcode, control, csel, 1'b0);
// if mismatch and csel==2'b10, retry with flag_c=1
```

No opcode or `csel` skips. Six source vectors with `x` in the expected-out field are omitted at extract time (flag-only stimulus).

---

## UVM reuse

Same 476 vectors in `uvm/common/directed_vectors_pkg.sv` for `alu_32b_directed_seq`.
