#!/usr/bin/env python3
"""Tomato assembler: .s → 32-bit word images (.mem / .hex).

ISA authority: docs/isa/tomato.v1.csv

Encodings:
  R-type:  {op[8:0], rd[4:0], rA[4:0], rB[4:0], rC[4:0], bank[2:0]}
  I13:     {op, rd, rA, imm13}           ADDI / LW / JALR
  Store:   {op, 0, rA_data, rB_base, imm8}
  Branch:  {op, 0, off[21:0]}            PC-relative (target - pc_exec)
  JMP:     {op, 0, abs[21:0]}
  LUI:     {op, imm20[19:0], 3'b0}  — imm20 shares rd; asm LUI rd,imm15
  JAL:     {op, rd, abs[17:0]} with abs[21:18]==rd[3:0]
  Imm16:   {op, rd, rA, imm16[12:0]} with imm[15:13]==rA[2:0] (overlap)

Directives:
  .org addr        — set next word address (sparse image; holes = NOP/0)
  .word n, n, ...  — emit raw 32-bit data words (glyphs / tables)

Pseudos:
  LA rd, label     — ADDI rd, r0, addr (label must fit signed imm13)

Usage:
  python3 software/assembler.py software/asm/counter.s -o hardware/fpga/tomato/tb/mem/counter.mem
"""
from __future__ import annotations

import argparse
import csv
import io
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V1 = ROOT / "docs/isa/tomato.v1.csv"

REG = re.compile(r"^r(\d+)$", re.I)
IDENT = re.compile(r"^[A-Za-z_.][A-Za-z0-9_.]*$")


def load_opcodes():
    body = "\n".join(l for l in V1.read_text().splitlines() if not l.startswith("#"))
    rows = list(csv.DictReader(io.StringIO(body)))
    ops = {}
    for r in rows:
        m = r["mnemonic"].upper()
        if m in ops:
            continue  # first wins (burn before growth aliases)
        ops[m] = {
            "op": int(r["rom_addr"], 16),
            "imm_sel": int(r["ir_imm_sel"] or 0),
            "group": r.get("group", ""),
            "status": r.get("status", ""),
        }
    return ops


def parse_reg(tok: str) -> int:
    m = REG.match(tok.strip())
    if not m:
        raise ValueError(f"register expected, got {tok!r}")
    n = int(m.group(1))
    if not 0 <= n <= 31:
        raise ValueError(f"register out of range: {tok}")
    return n


def parse_imm(tok: str, bits: int, signed: bool = True) -> int:
    tok = tok.strip().lower().replace("_", "")
    if tok.startswith("0x"):
        v = int(tok, 16)
    elif tok.startswith("-0x"):
        v = -int(tok[3:], 16)
    else:
        v = int(tok, 0)
    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
        if not lo <= v <= hi:
            raise ValueError(f"imm {v} does not fit signed {bits}-bit")
        return v & ((1 << bits) - 1)
    if not 0 <= v < (1 << bits):
        raise ValueError(f"imm {v} does not fit unsigned {bits}-bit")
    return v


def enc_r(op: int, rd: int, ra: int, rb: int, rc: int = 0, bank: int = 0) -> int:
    return ((op & 0x1FF) << 23) | ((rd & 31) << 18) | ((ra & 31) << 13) | ((rb & 31) << 8) | ((rc & 31) << 3) | (bank & 7)


def enc_i13(op: int, rd: int, ra: int, imm13: int) -> int:
    return ((op & 0x1FF) << 23) | ((rd & 31) << 18) | ((ra & 31) << 13) | (imm13 & 0x1FFF)


def enc_sw(op: int, ra: int, rb: int, imm8: int) -> int:
    return ((op & 0x1FF) << 23) | ((ra & 31) << 13) | ((rb & 31) << 8) | (imm8 & 0xFF)


def enc_br(op: int, off22: int) -> int:
    return ((op & 0x1FF) << 23) | (off22 & 0x3FFFFF)


def enc_lui(op: int, rd: int, imm15: int) -> int:
    """LUI rd, imm15 → rd = (rd<<27) | (imm15<<12). ir[22:3] shares rd with imm."""
    field = ((rd & 31) << 15) | (imm15 & 0x7FFF)
    return ((op & 0x1FF) << 23) | ((field & 0xFFFFF) << 3)


def enc_jal(op: int, rd: int, abs22: int) -> int:
    """JAL rd, abs — ir[22:18]=rd overlaps abs[21:18]; require match."""
    if ((abs22 >> 18) & 0xF) != (rd & 0xF):
        raise ValueError(
            f"JAL: target[21:18]={((abs22 >> 18) & 0xF)} must equal rd[3:0]={rd & 0xF} "
            f"(use rd=0 for targets below 0x40000)"
        )
    return ((op & 0x1FF) << 23) | ((rd & 31) << 18) | (abs22 & 0x3FFFF)


def enc_i16(op: int, rd: int, ra: int, imm16: int) -> int:
    """Imm16 in IR[15:0]; requires imm[15:13] == rA[2:0]."""
    if ((imm16 >> 13) & 7) != (ra & 7):
        raise ValueError(
            f"ANDI/ORI/XORI overlap: imm16 top3={((imm16 >> 13) & 7)} must equal rA[2:0]={ra & 7}"
        )
    return ((op & 0x1FF) << 23) | ((rd & 31) << 18) | ((ra & 31) << 13) | (imm16 & 0x1FFF)


class AsmError(Exception):
    def __init__(self, line_no: int, msg: str):
        super().__init__(f"line {line_no}: {msg}")


def tokenize_line(line: str):
    """Strip comments; return (label|None, mnemonic|None, ops list)."""
    if ";" in line:
        line = line[: line.index(";")]
    line = line.strip()
    if not line:
        return None, None, []
    label = None
    if ":" in line:
        before, after = line.split(":", 1)
        before = before.strip()
        if not IDENT.match(before):
            raise ValueError(f"bad label {before!r}")
        label = before
        line = after.strip()
        if not line:
            return label, None, []
    parts = re.split(r"[\s,]+", line)
    parts = [p for p in parts if p]
    return label, parts[0].upper(), parts[1:]


def assemble(src: str, ops: dict) -> list[int]:
    """Assemble to a dense word image (NOP-filled holes from .org)."""
    lines = src.splitlines()
    labels: dict[str, int] = {}
    items = []  # (line_no, mnem, operands, addr)
    pc = 0
    for i, raw in enumerate(lines, 1):
        s = raw.strip()
        if not s or s.startswith(";") or s.startswith("#"):
            continue
        try:
            label, mnem, operands = tokenize_line(raw)
        except ValueError as e:
            raise AsmError(i, str(e)) from e
        if label is not None:
            if label in labels:
                raise AsmError(i, f"duplicate label {label}")
            labels[label] = pc
        if mnem is None:
            continue
        if mnem in (".ORG", "ORG"):
            if len(operands) != 1:
                raise AsmError(i, ".org addr")
            try:
                pc = parse_imm(operands[0], 24, signed=False)
            except ValueError as e:
                raise AsmError(i, str(e)) from e
            continue
        if mnem in (".WORD", "WORD", ".DW", "DW"):
            if not operands:
                raise AsmError(i, ".word needs at least one value")
            for tok in operands:
                items.append((i, ".WORD", [tok], pc))
                pc += 1
            continue
        items.append((i, mnem, operands, pc))
        pc += 1

    RRR = {
        "ADD", "SUB", "AND", "OR", "XOR", "CMP", "LSL", "LSR", "ASR", "ROR",
        "MUL", "MULH", "MULHU", "DIV", "DIVU", "REM", "REMU",
        "NAND", "NOR", "XNOR", "ADC", "SBC",
    }
    RR_MOV = {"MOV", "MVN"}
    R_UNARY = {"ZERO", "ONE", "ALLONES", "INC", "DEC", "NOT", "NEG", "MOVA"}
    I13 = {"ADDI", "LW", "LB", "LBU", "LH", "LHU"}
    I16 = {"ANDI", "ORI", "XORI"}
    ST = {"SW", "SB", "SH"}
    BR = {"BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU", "BMI", "BCS", "BNZ", "BZ"}
    ABS = {"JMP", "JMPABS", "JMPI"}
    NONE = {"NOP", "HALT", "RET", "FENCE", "EBREAK", "ECALL"}

    if not items:
        return []
    words = [0] * (max(a for *_, a in items) + 1)

    for line_no, mnem, operands, addr in items:
        try:
            if mnem == ".WORD":
                # allow full unsigned 32-bit (signed parse then mask)
                tok = operands[0].strip().lower().replace("_", "")
                if tok.startswith("0x"):
                    words[addr] = int(tok, 16) & 0xFFFFFFFF
                else:
                    words[addr] = int(tok, 0) & 0xFFFFFFFF
                continue

            if mnem == "LA":
                if len(operands) != 2:
                    raise ValueError("LA rd, label")
                rd = parse_reg(operands[0])
                lab = operands[1]
                if lab not in labels:
                    raise ValueError(f"unknown label {lab}")
                dest = labels[lab]
                if not 0 <= dest < (1 << 12):
                    raise ValueError(f"LA target {dest} out of unsigned 12-bit ADDI range")
                op = ops["ADDI"]["op"]
                words[addr] = enc_i13(op, rd, 0, dest & 0x1FFF)
                continue

            if mnem not in ops:
                raise ValueError(f"unknown mnemonic {mnem}")
            op = ops[mnem]["op"]

            if mnem in NONE:
                if operands:
                    raise ValueError(f"{mnem} takes no operands")
                if mnem in ("HALT", "EBREAK", "ECALL"):
                    words[addr] = (op & 0x1FF) << 23
                else:
                    words[addr] = enc_r(op, 0, 0, 0)

            elif mnem in R_UNARY:
                if len(operands) != 1:
                    raise ValueError(f"{mnem} rd")
                rd = parse_reg(operands[0])
                words[addr] = enc_r(
                    op, rd, rd if mnem in ("INC", "DEC", "NOT", "NEG", "MOVA") else 0, 0
                )

            elif mnem in RR_MOV:
                if len(operands) != 2:
                    raise ValueError(f"{mnem} rd, rB")
                rd, rb = parse_reg(operands[0]), parse_reg(operands[1])
                words[addr] = enc_r(op, rd, 0, rb)

            elif mnem in RRR:
                if mnem == "CMP":
                    if len(operands) == 2:
                        ra, rb = map(parse_reg, operands)
                    elif len(operands) == 3:
                        _, ra, rb = map(parse_reg, operands)
                    else:
                        raise ValueError("CMP rA, rB")
                    words[addr] = enc_r(op, 0, ra, rb)
                else:
                    if len(operands) != 3:
                        raise ValueError(f"{mnem} rd, rA, rB")
                    rd, ra, rb = map(parse_reg, operands)
                    words[addr] = enc_r(op, rd, ra, rb)

            elif mnem in I13:
                if len(operands) != 3:
                    raise ValueError(f"{mnem} rd, rA, imm")
                rd, ra = parse_reg(operands[0]), parse_reg(operands[1])
                imm = parse_imm(operands[2], 13, signed=True)
                words[addr] = enc_i13(op, rd, ra, imm)

            elif mnem in I16:
                if len(operands) != 3:
                    raise ValueError(f"{mnem} rd, rA, imm")
                rd, ra = parse_reg(operands[0]), parse_reg(operands[1])
                imm = parse_imm(operands[2], 16, signed=False)
                words[addr] = enc_i16(op, rd, ra, imm)

            elif mnem in ST:
                if len(operands) != 3:
                    raise ValueError(f"{mnem} rData, rBase, imm8")
                ra, rb = parse_reg(operands[0]), parse_reg(operands[1])
                imm = parse_imm(operands[2], 8, signed=True)
                words[addr] = enc_sw(op, ra, rb, imm)

            elif mnem == "LUI":
                if len(operands) != 2:
                    raise ValueError("LUI rd, imm15  (rd = (rd<<27)|(imm15<<12))")
                rd = parse_reg(operands[0])
                imm = parse_imm(operands[1], 15, signed=False)
                words[addr] = enc_lui(op, rd, imm)

            elif mnem == "JAL":
                if len(operands) != 2:
                    raise ValueError("JAL rd, label")
                rd = parse_reg(operands[0])
                lab = operands[1]
                if lab not in labels:
                    raise ValueError(f"unknown label {lab}")
                words[addr] = enc_jal(op, rd, labels[lab] & 0x3FFFFF)

            elif mnem == "JALR":
                if len(operands) != 3:
                    raise ValueError("JALR rd, rA, imm")
                rd, ra = parse_reg(operands[0]), parse_reg(operands[1])
                imm = parse_imm(operands[2], 13, signed=True)
                words[addr] = enc_i13(op, rd, ra, imm)

            elif mnem in BR:
                if len(operands) != 1:
                    raise ValueError(f"{mnem} label")
                lab = operands[0]
                if lab not in labels:
                    raise ValueError(f"unknown label {lab}")
                off = labels[lab] - (addr + 1)
                if not -(1 << 21) <= off < (1 << 21):
                    raise ValueError(f"branch out of range ({off})")
                words[addr] = enc_br(op, off & 0x3FFFFF)

            elif mnem in ABS:
                if len(operands) != 1:
                    raise ValueError(f"{mnem} label")
                lab = operands[0]
                if lab not in labels:
                    raise ValueError(f"unknown label {lab}")
                words[addr] = enc_br(op, labels[lab] & 0x3FFFFF)

            elif mnem == "JR":
                if len(operands) != 1:
                    raise ValueError("JR rB")
                rb = parse_reg(operands[0])
                words[addr] = enc_r(op, 0, 0, rb)

            elif mnem in ("PUSH", "OUT"):
                if len(operands) != 1:
                    raise ValueError(f"{mnem} rA")
                ra = parse_reg(operands[0])
                words[addr] = enc_r(op, 0, ra, 0)

            elif mnem in ("POP", "IN"):
                if len(operands) != 1:
                    raise ValueError(f"{mnem} rd")
                rd = parse_reg(operands[0])
                words[addr] = enc_r(op, rd, 0, 0)

            else:
                raise ValueError(f"unsupported form for {mnem} (add to assembler)")
        except ValueError as e:
            raise AsmError(line_no, str(e)) from e

    return words


def write_mem(path: Path, words: list[int], fmt: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        if fmt == "hex":
            f.write("v2.0 raw\n")
        for w in words:
            f.write(f"{w:08x}\n")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("source", type=Path, help=".s assembly file")
    ap.add_argument("-o", "--output", type=Path, help="output .mem or .hex")
    ap.add_argument("--list", action="store_true", help="print listing to stdout")
    args = ap.parse_args()

    ops = load_opcodes()
    src = args.source.read_text()
    try:
        words = assemble(src, ops)
    except AsmError as e:
        print(f"asm: {e}", file=sys.stderr)
        return 1

    out = args.output
    if out is None:
        out = args.source.with_suffix(".mem")
    fmt = "hex" if out.suffix == ".hex" else "mem"
    write_mem(out, words, fmt)

    if args.list:
        for i, w in enumerate(words):
            if w != 0:
                print(f"{i:04x}: {w:08x}")

    print(f"wrote {out} ({len(words)} words)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
