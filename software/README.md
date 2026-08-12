# Software

Tomato assembly → hex/mem pipeline for FPGA sim (and later board load).

## Assemble

```bash
python3 software/assembler.py software/asm/counter.s -o hardware/fpga/tomato/tb/mem/counter.mem --list
```

From `hardware/fpga/tomato`: `make asm`.

## Syntax (v1)

| Form | Example |
|------|---------|
| RRR | `ADD r4, r1, r2` |
| MOV | `MOV r1, r2` (rd ← rB) |
| unary | `ZERO r0` / `INC r1` / `NOT r9` |
| ADDI/LW | `ADDI r1, r0, 10` / `LW r6, r5, 0` |
| SW | `SW r1, r5, 0` (data, base, imm8) |
| branch | `BNE loop` / `BEQ done` (PC-relative) |
| jump | `JMP loop` (absolute word addr) |
| system | `NOP` / `HALT` / `RET` |

Comments: `;` or `#`. Labels: `name:`.

ISA: [`docs/isa/tomato.v1.csv`](../docs/isa/tomato.v1.csv).

## Samples

| Program | Check |
|---------|--------|
| `asm/counter.s` | r1 = disp = 10 |
