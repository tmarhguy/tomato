# Load/Store Pipeline Analysis — Tomato32

## 1. Microcode Bit Field Map

Every opcode indexes a **48-bit word** in the microcode ROM (`DIG_ROM_256X48_microcodeeeprom`). The fields, confirmed from `main.v:2087–2106`:

| Bits | Field | Notes |
|------|-------|-------|
| [7:0] | `alu-op` | 8-bit truth-table opcode for the ALU |
| [12:8] | `alu-pre` | 5-bit operand-source & inversion control (see §3) |
| [13] | `cin-sel` | Carry-in select (0=FLAG_C, 1=constant 1) |
| [15:14] | `shift-op` | LSL/LSR/ASR/ROR |
| [19:16] | `ir-imm-sel` | Selects one of 16 immediate encodings from IR |
| [20] | `addr-csel` | Selects C-port register address source |
| **[23:21]** | **`wb-sel`** | **Writeback source: 0=ALU, 1=Shift, 2=PC+1, 3=mem_din, 4=I/O, 5=RegA, 6=IR-imm, 7=MUL** |
| **[24]** | **`reg-we`** | **Register file write enable** |
| [25] | `flags-we` | ALU flags write enable |
| **[26]** | **`mem-rd`** | **Memory read enable** |
| **[27]** | **`mem-wr`** | **Memory write enable** |
| **[29:28]** | **`mem-sel`** | **Byte-lane mode: 0=word, 1=byte_signed, 2=byte_unsigned, 3=half** |
| [30] | `branch-en` | Enable conditional branch |
| [31] | `jump-type` | Unconditional jump |
| [33:32] | `sp-op` | SP delta: 0=hold, 1=+1(pop), 2=−1(push), 3=load |
| [34] | `pc-rel` | PC-relative mode select |
| **[36:35]** | **`cycles`** | **Counter reset target: 1=FETCH+EXEC (2-phase), 2=FETCH+EXEC+MEM_WAIT (3-phase)** |
| **[39:37]** | **`ctrl-bussel`** | **Address bus source: 0=IR_ADDR, 1=ALU_out, 2=Reg_B, 3=PC, 7=SP** |
| [40] | `mul-en` | Multiply enable |
| [41] | `div-en` | Divide enable |

---

## 2. Instruction Cycle Timing

The sequencer counter (74163, clocked on **falling** CLK edge) determines the phase. Data registers (IR, register file, flags) are clocked on the **rising** CLK edge.

| `cycles` value | Phases | Counter states used |
|---|---|---|
| `0b01` = 1 | FETCH + EXECUTE | Q=00, Q=01 (resets at Q=01) |
| `0b10` = 2 | FETCH + EXECUTE + MEM_WAIT | Q=00, Q=01, Q=10 (resets at Q=10) |

During **FETCH** (`Q=00`, `seq_fetch=1`): PC drives the address bus regardless of `ctrl-bussel`. IR latches the instruction from memory.  
During **EXECUTE** (`Q=01`, `seq_exec=1`): microcode controls are active, ALU runs, register writes happen.  
During **MEM_WAIT** (`Q=10`, `seq_exec=0`): no register write.

---

## 3. ALU Operand Control (`alu-pre`)

The 5-bit `control` field maps directly to operand selection:

| Bit | Name | Effect when 1 |
|-----|------|--------------|
| [0] | `Asel` | Enable A input (A_eff = A); if 0, A_eff = 0 |
| [1] | `ainv` | Invert A_eff |
| [2] | `Bsel` | Enable B input (B_eff = B); if 0, B_eff = 0 |
| [3] | `binv` | Invert B_eff |
| [4] | `csel` | Use REG_C as carry operand instead of FLAG_C |

`alu-op=0x96` with `Asel=1, Bsel=1` → standard **full adder** (A + B + cin).  
`alu-op=0x96` with `Asel=1, Bsel=0` → **pass-through A** (identity / increment depending on cin).  
**`alu-op=0x00` with `alu-pre=0x00` → `A_eff=0, B_eff=0` → ALU output is always `0x00000000`.**

---

## 4. Load Pipeline (Correct Path)

```
FETCH  (Q=00):  PC → bus_arbitration → RAM → byte_lane_decoder → IR (latches instruction)
EXECUTE(Q=01):  ctrl-bussel → address → RAM (combinatorial) → byte_lane_decoder → wb_mux(sel=3) → reg_file[ADDR_W]
```

Signal chain for `wb_mux` sel=3 (memory writeback):
```
ALU/reg_b/IR_ADDR
  → bus_arbitration (ctrl-bussel) → CPU_ADDR_OUT
    → DIG_RAMDualPort (combinatorial read when ld=1)
      → byte_lane_decoder (mem-sel determines width/sign-extension)
        → wb_mux.in_3 (wb-sel=3) → reg_w_data
          → register_file[ADDR_W]  (written at EXECUTE rising edge)
```

> **Timing note**: In `verilog-exports/main.v` the RAM output feeds byte_lane_decoder **directly** (combinatorial). The register write and the memory read settle in the same EXECUTE cycle — this is correct. In `hardware/digital/modules/main.v` there is an extra `DIG_Register_BUS_i20` latch in that path which delays memory data by one cycle and breaks writeback. **Only the exported version has correct load timing.**

---

## 5. Store Pipeline

```
EXECUTE(Q=01):  ctrl-bussel → address → DIG_RAMDualPort.A
                reg_b       →           DIG_RAMDualPort.Din
                ctrl_mem_wr (=1) fires write on rising CLK edge
```

The store data source is **hardwired** to `reg_b_temp` (`main.v:5045`). There is no path for `reg_a` to be the store data.

---

## 6. Decoded ROM Entries — Load Instructions (opcodes 0x30–0x35)

| Opcode | ROM entry | wb-sel | reg-we | mem-rd | mem-sel | `ctrl-bussel` | `alu-op` | `alu-pre` | `cycles` |
|--------|-----------|--------|--------|--------|---------|---------------|----------|-----------|---------|
| `0x30` LW  | `48'h3005630000` | 3 ✓ | 1 ✓ | 1 ✓ | 0 (word) | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x31` LH  | `48'h3035630000` | 3 ✓ | 1 ✓ | 1 ✓ | 3 (half) | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x32` LHU | `48'h3025630000` | 3 ✓ | 1 ✓ | 1 ✓ | 2 (byte_u) | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x33` LB  | `48'h3015630000` | 3 ✓ | 1 ✓ | 1 ✓ | 1 (byte_s) | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x34` LBU | `48'h3005630000` | 3 ✓ | 1 ✓ | 1 ✓ | 0 (word)  | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x35` LW  | `48'h4805600000` | 3 ✓ | 1 ✓ | 1 ✓ | 0 (word) | 2 (Reg_B) ✓ | 0x00 | 0x00 | 1 |

`0x35` works because `ctrl-bussel=2` uses `reg_b[23:0]` directly as the address — the ALU is not involved.  
`0x30–0x34` are broken (see Bug #1 below).

---

## 7. Decoded ROM Entries — Store Instructions (opcodes 0x40–0x43)

| Opcode | ROM entry | reg-we | mem-wr | mem-rd | `ctrl-bussel` | `alu-op` | `alu-pre` | `cycles` |
|--------|-----------|--------|--------|--------|---------------|----------|-----------|---------|
| `0x40` SW  | `48'h3008030000` | 0 ✓ | 1 ✓ | 0 ✓ | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x41` SH  | `48'h3038030000` | 0 ✓ | 1 ✓ | 0 ✓ | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x42` SB  | `48'h3018030000` | 0 ✓ | 1 ✓ | 0 ✓ | 1 (ALU) | **0x00 ⚠** | **0x00 ⚠** | 2 |
| `0x43` SW  | `48'h4808000000` | 0 ✓ | 1 ✓ | 0 ✓ | 2 (Reg_B) ✓ | 0x00 | 0x00 | 1 |

`0x43` works: address = `reg_b[23:0]`, data written = `reg_b` (full 32-bit). So `SW [r1], r1` stores the VALUE of r1 to the ADDRESS in r1. Both source and destination are reg_b.  
`0x40–0x42` are broken (see Bug #1 below).

---

## 8. Bugs Found

### Bug #1 — ALU not configured for address computation (opcodes 0x30–0x34, 0x40–0x42)

**What happens:** `alu-op=0x00` and `alu-pre=0x00` → both `A_eff` and `B_eff` are forced to 0 → ALU output = `0x00000000`. Since `ctrl-bussel=1` for these opcodes, the effective address is always `0x000000`.

**Effect:** Every load/store with an immediate offset silently accesses address 0 instead of the computed target.

**Fix:** The ROM entries for these opcodes need `alu-op=0x96` (full adder) and `alu-pre=0x07` (`Asel=1, Bsel=1`) to enable `reg_A + sign_extend(ir3)` address computation. The `ir-imm-sel=3` encoding is already correct.

Correct entry shape for `0x30` would be `48'h3005630796` instead of `48'h3005630000` (bits [11:0] changed from `0x000` to `0x796`).

### Bug #2 — Extra memory latch in `modules/main.v` (NOT in exported version)

`hardware/digital/modules/main.v` inserts a `DIG_Register_BUS_i20` between the RAM output and the byte_lane_decoder. This latches the memory data at the EXECUTE rising edge — the same edge that writes to the register file. The register write therefore uses the *previous* cycle's memory data (the instruction word), not the actual loaded value.

`hardware/digital/modules/verilog-exports/main.v` does **not** have this latch. The RAM output goes directly to byte_lane_decoder, so the data settles combinatorially before the EXECUTE register write. **This version is correct.**

Action: regenerate `modules/main.v` from the Digital simulator (`.dig` file), or treat the verilog-exports version as canonical.

### Design note — Store data source

All store instructions write `reg_b_temp` to memory (hardwired at `main.v:5045`). This means `SW [addr], data` must have:
- Base address register in the **ADDR_B** field (instruction[15:8])  
- Data register also sourced from **ADDR_B** (the same register)

A conventional `SW rA, [rB + imm]` (data=rA, address=rB+imm) is not directly representable with the current data path. If that ISA encoding is desired, the RAM `.Din` would need to be changed from `reg_b_temp` to `reg_a_temp`.

---

## 9. What Currently Works

| Instruction | Opcode | Status |
|-------------|--------|--------|
| LW rd, [rB] | `0x35` | ✅ Correct (reg_b address, direct combinatorial path in exported .v) |
| SW [rB], rB | `0x43` | ✅ Correct (reg_b address and data, writes value of rB to address in rB) |
| LW/LH/LHU/LB/LBU rd, [rA + imm12] | `0x30–0x34` | ❌ Bug #1: always accesses address 0 |
| SW/SH/SB [rA + imm12], rB | `0x40–0x42` | ❌ Bug #1: always writes to address 0 |
| All instructions in `modules/main.v` (non-exported) | — | ❌ Bug #2: load writeback uses wrong data |

---

## 10. Test Gap

`verilog-exports/main_tb.v` instantiates the main module but has **zero stimulus** — no clock generation, no reset, no assertions. None of the `.hex` test programs (`fib.hex`, `count.hex`, `firmware.hex`) exercise any memory load or store. A testbench covering opcode `0x35` (pass) and `0x30` (Bug #1 fail) needs to be written.
