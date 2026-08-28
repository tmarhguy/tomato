# Software

Tomato assembly → hex/mem pipeline for FPGA sim (and later board load).

## Assemble

```bash
python3 software/assembler.py software/asm/counter.s -o hardware/fpga/core/tb/mem/counter.mem --list
```

From `hardware/fpga/core`: `make asm`.

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
| `asm/fib.s` | fib(8) → r1 = r6 = 21 |
| `asm/collatz.s` | n=27 → 111 steps in r1/disp |
| `asm/call.s` | JAL/RET → r1=99 r2=42 |
| `asm/bytes.s` | SB/LB signed byte |
| `asm/ecall.s` | trap + RET → r1=42 |
| `asm/softops.s` | ROR/LBU → r1=r6=129 |
| `asm/io.s` | IN/OUT keyboard echo |
| `asm/kb_mmio.s` | LW MMIO kb data/status |
