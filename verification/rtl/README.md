# RTL — Digital-exported DUT

Read-only netlists copied from Digital. **Do not edit** verification logic into these files; bind wrappers, UVM, and directed TBs live in sibling folders.

Files in this directory (except this README) are **local-only and gitignored** — every sign-off target checks for them first (`make …` tells you exactly which export is missing).

## Provisioning (one-time)

1. Install [Digital](https://github.com/hneemann/Digital) and open `hardware/digital/modules/`.
2. For each of `alu-1b-final.dig`, `alu-8b-final.dig`, `alu-32b-final.dig`: **Export → Verilog**, save here as `alu-1b-final.v`, `alu-8b-final.v`, `alu-32b-final.v`.
3. Re-run `make -C verification signoff`.

## Files

| File | Top module | Role |
|------|------------|------|
| `alu-1b-final.v` | `\alu-1b-final` | 1-bit programmable LUT cell + G/P propagate/generate |
| `alu-8b-final.v` | `\alu-8b-final` | 8-bit slice (8× 1b + CLA glue) |
| `alu-32b-final.v` | `\alu-32b-final` | Full 32-bit ALU: opcode LUT, control decode, CLA, flag latches |

## Port naming

Digital exports use escaped identifiers (e.g. `\~flag_a_is_zero`). Wrappers in `directed/alu_32b_dut_wrap.v` and formal bind modules map these to simulation-friendly names.

## How each layer uses RTL

| Consumer | File used |
|----------|-----------|
| Formal 1b | `alu-1b-final.v` |
| Formal 8b | `alu-8b-final.v` |
| Formal 32b / flags | `alu-32b-final.v` |
| Directed (Icarus) | `alu-32b-final.v` |
| UVM 1b | `alu-1b-final.v` |
| UVM 8b | `alu-8b-final.v` |
| UVM 32b | `alu-32b-final.v` + `alu_32b_assertions.sv` (bind) |
| Lint | All three (Verilator reports `MODDUP` for shared submodules — expected) |

## Source of truth

Regenerate from Digital when the schematic changes, then re-run `make signoff`. The behavioral contract is defined in `docs/alu/alu-1b/alu_control_map.tex` and checked by formal bind properties + `uvm/common/alu_ref_model_pkg.sv`.

Do **not** substitute `synthesis/rtl/alu-32b-final.v` here: it is a genuine Digital export but its top-level port map (`lutA`/`lutB`, 3-bit `csel`, 8-bit `csr`) differs from what the directed wrapper and formal binds expect (`Opcode`, `control`, 2-bit `csel`, 13-bit `CSR_FLAG`). Export all three netlists fresh from the current `.dig` sources.
