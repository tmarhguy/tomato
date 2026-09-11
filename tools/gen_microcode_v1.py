#!/usr/bin/env python3
"""Pack Tomato ISA v1 microcode from docs/isa/tomato.v1.csv (512 rows).

Default: read the CSV → write microcode/*.hex + *.mem (+ FPGA tb/mem).
--rebuild: regenerate the CSV from burn rows already in it + growth templates
           (rare; overwrites docs/isa/tomato.v1.csv).

FPGA dual-LUT: alu_control_1 = lutA, alu_lut_b = lutB.
Packing matches hardware/fpga/core/rtl/control.v.
"""
from __future__ import annotations

import argparse
import csv
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V1 = ROOT / "docs/isa/tomato.v1.csv"
MC = ROOT / "microcode"
FPGA_MEM = ROOT / "hardware/fpga/core/tb/mem"
DEPTH = 512

ROM_FILES = {
    "alu_control_1": "alu_control_1.hex",      # Dig / lutA alias
    "alu_lut_b": "alu_lut_b.hex",              # FPGA lutB
    "alu_shift_control": "alu_shift_control.hex",
    "ir_reg_control": "ir_reg_control.hex",
    "mem_bus_control": "mem_bus_control.hex",
    "mem_io_control": "mem_io_control.hex",
    "pc_control": "pc_control.hex",
    "pc_sp_mul_control": "pc_sp_mul_control.hex",
    "shift_mul_control": "shift_mul_control.hex",
}

# Dual-LUT encoding for FPGA (docs/alu/alu-32b). Third value = csel.
DUAL = {
    "MASKADD": (0xAA, 0xC0, 0),  # A + (B & C), three register operands
    "XORAND":  (0x96, 0x80, 0),  # (A ^ B ^ C) + (A & B & C)
    "ADD":   (0xAA, 0xCC, 0),
    "ADDI":  (0xAA, 0xCC, 0),
    "ADC":   (0xAA, 0xCC, 4),   # + carry flag
    "SUB":   (0xAA, 0x33, 1),
    "SBC":   (0xAA, 0x33, 4),   # - with carry-in
    "RSB":   (0x33, 0xCC, 1),   # B - A = ~A + B + 1
    "CMP":   (0xAA, 0x33, 1),
    "CMN":   (0xAA, 0xCC, 0),   # flags from A+B
    "CMPI":  (0xAA, 0x33, 1),
    "AND":   (0x88, 0x00, 0),
    "ANDI":  (0x88, 0x00, 0),
    "ANDN":  (0x22, 0x00, 0),   # A & ~B
    "OR":    (0xEE, 0x00, 0),
    "ORI":   (0xEE, 0x00, 0),
    "ORN":   (0xBB, 0x00, 0),   # A | ~B
    "XOR":   (0x66, 0x00, 0),
    "XORI":  (0x66, 0x00, 0),
    "MOV":   (0x00, 0xCC, 0),
    "MOVA":  (0xAA, 0x00, 0),
    "MVN":   (0x33, 0x00, 0),   # ~B
    "NOT":   (0x55, 0x00, 0),   # ~A
    "NEG":   (0x55, 0x00, 1),
    "INC":   (0xAA, 0x00, 1),
    "DEC":   (0xAA, 0xFF, 0),
    "NAND":  (0x77, 0x00, 0),
    "NOR":   (0x11, 0x00, 0),
    "XNOR":  (0x99, 0x00, 0),
    "TST":   (0x88, 0x00, 0),   # flags from A&B
    "TEQ":   (0x66, 0x00, 0),
    "ZERO":  (0x00, 0x00, 0),
    "ONE":   (0x00, 0x00, 1),   # cin only → 1
    "ALLONES": (0xFF, 0x00, 0),
    "LW":    (0xAA, 0xCC, 0),
    "LB":    (0xAA, 0xCC, 0),
    "LH":    (0xAA, 0xCC, 0),
    "LBU":   (0xAA, 0xCC, 0),
    "LHU":   (0xAA, 0xCC, 0),
    "SW":    (0xAA, 0xCC, 0),
    "SB":    (0xAA, 0xCC, 0),
    "SH":    (0xAA, 0xCC, 0),
    "JR":    (0x00, 0xCC, 0),   # pass rB → ALU → PC
    "JALR":  (0xAA, 0xCC, 0),   # PC = rA + imm13
    "LWABS": (0x00, 0x00, 0),
    "SWABS": (0x00, 0x00, 0),
    "PUSH":  (0x00, 0x00, 0),
    "POP":   (0x00, 0x00, 0),
    "IN":    (0x00, 0x00, 0),
    "OUT":   (0x00, 0x00, 0),
    # Imm / alias mnemonics → same dual-LUT as base op
    "ADDI16": (0xAA, 0xCC, 0),
    "SUBI":  (0xAA, 0x33, 1),
    "CMPI16": (0xAA, 0x33, 1),
    "ANDNI": (0x22, 0x00, 0),
    "ORNI":  (0xBB, 0x00, 0),
    "NANDI": (0x77, 0x00, 0),
    "NORI":  (0x11, 0x00, 0),
    "XNORI": (0x99, 0x00, 0),
    "ADCI":  (0xAA, 0xCC, 4),
    "SBCI":  (0xAA, 0x33, 4),
    "INCI":  (0xAA, 0x00, 1),
    "DECI":  (0xAA, 0xFF, 0),
    "NOTI":  (0x55, 0x00, 0),
    "NEGI":  (0x55, 0x00, 1),
    "MOVAI": (0xAA, 0x00, 0),
    "TSTI":  (0x88, 0x00, 0),
}

# Shift family (barrel) — ALU LUTs idle
SHIFT_OPS = {
    "LSL", "LSR", "ASR", "ROR", "ROL",
    "LSLI", "LSRI", "ASRI", "RORI", "RORI8",
    "LSLR", "LSRR", "ASRR", "RORR",
    "SHLI", "SHRI", "SARI",
}


def load_v1():
    lines = V1.read_text().splitlines()
    body = "\n".join(l for l in lines if not l.startswith("#"))
    return list(csv.DictReader(io.StringIO(body)))


def i(row, k, d=0):
    v = row.get(k, "")
    if v is None or str(v).strip() == "":
        return d
    return int(v)


def base_row(**kw):
    r = {
        "rom_addr": "0x00",
        "region": "system",
        "mnemonic": "NOP",
        "group": "system",
        "seq_cycles": "1",
        "status": "nop",
        "operation": "",
        "why": "",
        "ir_imm_sel": "0",
        "alu_op": "0",
        "alu_pre": "0",
        "cin_sel": "0",
        "shift_op": "0",
        "wb_sel": "0",
        "reg_we": "0",
        "bank_en": "0",
        "flags_we": "0",
        "mem_rd": "0",
        "mem_wr": "0",
        "byte_sel": "0",
        "mem_sel": "0",
        "branch_en": "0",
        "jump_type": "0",
        "sp_op": "0",
        "pc_src": "0",
        "pc_link_we": "0",
        "pc_cond": "0",
        "cycles": "1",
        "ctrl_bussel": "0",
        "mul_en": "0",
        "div_en": "0",
        "lut3_index": "",
        "encoding": "reg_reg",
        "semantic_op": "NOP",
        "notes": "",
    }
    r.update(kw)
    return r


def burn_core_rows():
    """Solidified Tomato burn set (datapath-backed, expressive ALU/ISA).

    Full locked opcode surface — do not silently drop ops. Add new burns here
    when silicon/software needs them. Unused ROM addresses are NOP-filled by
    --pack-rom (no phantom growth mnemonics).
    """
    rows = []

    def add(row):
        rows.append(fix_burn_row(row))

    add(base_row(
        rom_addr="0x00", region="system", mnemonic="NOP", group="system",
        status="burn", semantic_op="NOP", operation="no operation",
        why="idle / padding", cycles="1", encoding="reg_reg",
    ))
    for addr, name, why in [
        (0x01, "ADD", "arith"),
        (0x02, "SUB", "arith"),
        (0x03, "AND", "logic"),
        (0x04, "OR", "logic"),
        (0x05, "XOR", "logic"),
        (0x06, "MOV", "copy"),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-reg", mnemonic=name,
            group="alu-reg", status="burn", semantic_op=name,
            operation=name, why=why, ir_imm_sel="1",
            reg_we="1", flags_we="0" if name == "MOV" else "1",
            cycles="1", encoding="reg_reg",
        ))
    for addr, name, expression in [
        (0x08, "MASKADD", "rd = rA + (rB & rC)"),
        (0x09, "XORAND", "rd = (rA ^ rB ^ rC) + (rA & rB & rC)"),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-reg", mnemonic=name,
            group="alu-reg", status="burn", semantic_op=name,
            operation=expression, why="compound three-input ALU", ir_imm_sel="1",
            reg_we="1", flags_we="1", cycles="1", encoding="reg_reg",
        ))
    add(base_row(
        rom_addr="0x07", region="alu-reg", mnemonic="CMP", group="alu-reg",
        status="burn", semantic_op="CMP", operation="flags = rA - rB",
        why="branches", ir_imm_sel="1", reg_we="0", flags_we="1",
        cycles="1", encoding="reg_reg",
    ))
    for addr, name, mul, div, wb, op in [
        (0x10, "MUL", 1, 0, 1, "rd = low(rA*rB)"),
        (0x11, "MULH", 1, 0, 7, "rd = high(rA*rB)"),
        (0x12, "DIV", 1, 1, 1, "rd = rA / rB"),
        (0x13, "REM", 1, 1, 7, "rd = rA % rB"),
        (0x14, "MULHU", 1, 0, 7, "rd = high unsigned"),
        (0x15, "DIVU", 1, 1, 1, "rd = rA / rB unsigned"),
        (0x16, "REMU", 1, 1, 7, "rd = rA % rB unsigned"),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-reg", mnemonic=name,
            group="muldiv", status="burn", semantic_op=name, operation=op,
            ir_imm_sel="1", wb_sel=str(wb), reg_we="1",
            mul_en=str(mul), div_en=str(div), cycles="1", encoding="reg_reg",
        ))
    add(base_row(
        rom_addr="0x20", region="alu-imm", mnemonic="ADDI", group="alu-imm",
        status="burn", semantic_op="ADDI", operation="rd = rA + imm13",
        why="constants", ir_imm_sel="3", reg_we="1", flags_we="1",
        cycles="1", encoding="off13s",
    ))
    for addr, name, op in [
        (0x21, "ANDI", "rd = rA & imm"),
        (0x22, "ORI", "rd = rA | imm"),
        (0x23, "XORI", "rd = rA ^ imm"),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-imm", mnemonic=name,
            group="alu-imm", status="burn", semantic_op=name, operation=op,
            ir_imm_sel="7", reg_we="1", flags_we="1", cycles="1", encoding="imm16z",
        ))
    add(base_row(
        rom_addr="0x24", region="alu-imm", mnemonic="LUI", group="alu-imm",
        status="burn", semantic_op="LUI", operation="rd = imm20 << 12",
        why="VGA/MMIO base", ir_imm_sel="11", wb_sel="5", reg_we="1",
        flags_we="0", cycles="1", encoding="imm20",
    ))
    add(base_row(
        rom_addr="0x29", region="alu-imm", mnemonic="RORI", group="alu-imm",
        status="burn", semantic_op="RORI", operation="rd = rA ror imm",
        ir_imm_sel="0", shift_op="3", wb_sel="1", reg_we="1",
        flags_we="0", cycles="1",
    ))
    add(base_row(
        rom_addr="0x30", region="alu-imm", mnemonic="ZERO", group="alu-imm",
        status="burn", semantic_op="ZERO", operation="rd = 0",
        ir_imm_sel="1", reg_we="1", flags_we="0", cycles="1", encoding="reg_reg",
    ))
    add(base_row(
        rom_addr="0x31", region="alu-imm", mnemonic="ONE", group="alu-imm",
        status="burn", semantic_op="ONE", operation="rd = 1",
        ir_imm_sel="1", reg_we="1", flags_we="0", cycles="1", encoding="reg_reg",
    ))
    for addr, name, sop in [
        (0x40, "LSL", 0), (0x41, "LSR", 1), (0x42, "ASR", 2), (0x43, "ROR", 3),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="shift", mnemonic=name,
            group="shift", status="burn", semantic_op=name,
            operation=name, ir_imm_sel="1", shift_op=str(sop),
            wb_sel="1", reg_we="1", cycles="1",
        ))
    for addr, name, rd, wr, byte, imm, msel, wb in [
        (0x60, "LW", 1, 0, 0, 3, 0, 3),
        (0x61, "LB", 1, 0, 4, 3, 0, 3),
        (0x62, "LH", 1, 0, 12, 3, 0, 3),
        (0x63, "LBU", 1, 0, 8, 3, 0, 3),
        (0x64, "LHU", 1, 0, 14, 3, 0, 3),
        (0x68, "SW", 0, 1, 0, 0, 1, 4),
        (0x69, "SB", 0, 1, 4, 0, 1, 4),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="mem", mnemonic=name,
            group="mem", status="burn", semantic_op=name, operation=name,
            ir_imm_sel=str(imm), reg_we="1" if rd else "0",
            mem_rd="1" if rd else "0", mem_wr="1" if wr else "0",
            byte_sel=str(byte), mem_sel=str(msel), wb_sel=str(wb),
            cycles="2", ctrl_bussel="1",
        ))
    for addr, name, cond in [
        (0x80, "BEQ", 0), (0x81, "BNE", 1), (0x82, "BLT", 5), (0x83, "BGE", 7),
    ]:
        add(base_row(
            rom_addr=f"0x{addr:02X}", region="branch", mnemonic=name,
            group="branch", status="burn", semantic_op=name,
            operation=name, ir_imm_sel="12", branch_en="1",
            pc_src="1", pc_cond=str(cond), cycles="1",
        ))
    add(base_row(
        rom_addr="0xA0", region="jump", mnemonic="JMP", group="jump",
        status="burn", semantic_op="JMP", operation="PC = abs",
        ir_imm_sel="13", jump_type="1", pc_src="0", cycles="1",
    ))
    add(base_row(
        rom_addr="0xA1", region="jump", mnemonic="JAL", group="jump",
        status="burn", semantic_op="JAL", operation="link; PC=abs",
        ir_imm_sel="13", jump_type="1", pc_src="0", wb_sel="2",
        reg_we="1", pc_link_we="1", cycles="1",
    ))
    add(base_row(
        rom_addr="0xA2", region="jump", mnemonic="RET", group="jump",
        status="burn", semantic_op="RET", operation="PC = link",
        jump_type="1", pc_src="2", cycles="1",
    ))
    add(base_row(
        rom_addr="0xA3", region="jump", mnemonic="JR", group="jump",
        status="burn", semantic_op="JR", operation="PC = rB",
        ir_imm_sel="1", jump_type="1", pc_src="4", cycles="1",
    ))
    add(base_row(
        rom_addr="0xA4", region="jump", mnemonic="JALR", group="jump",
        status="burn", semantic_op="JALR", operation="rd=PC+1; PC=alu",
        ir_imm_sel="3", jump_type="1", pc_src="4", wb_sel="2",
        reg_we="1", pc_link_we="1", cycles="1",
    ))
    add(base_row(
        rom_addr="0xC0", region="stack-io", mnemonic="PUSH", group="stack",
        status="burn", semantic_op="PUSH", operation="SP-=; mem[SP]=rA",
        sp_op="2", mem_wr="1", ctrl_bussel="7", wb_sel="4", cycles="2",
    ))
    add(base_row(
        rom_addr="0xC1", region="stack-io", mnemonic="POP", group="stack",
        status="burn", semantic_op="POP", operation="rd=mem[SP]; SP+=",
        sp_op="1", mem_rd="1", ctrl_bussel="7", wb_sel="3",
        reg_we="1", cycles="2",
    ))
    add(base_row(
        rom_addr="0xC8", region="stack-io", mnemonic="IN", group="stack",
        status="burn", semantic_op="IN", operation="rd = kb_data",
        byte_sel="2", wb_sel="3", reg_we="1", cycles="1",
    ))
    add(base_row(
        rom_addr="0xC9", region="stack-io", mnemonic="OUT", group="stack",
        status="burn", semantic_op="OUT", operation="io_out = rA[7:0]",
        ir_imm_sel="1", wb_sel="4", cycles="1",
    ))
    add(base_row(
        rom_addr="0xE0", region="reserved", mnemonic="FENCE", group="system",
        status="burn", semantic_op="FENCE", operation="ordering nop",
        cycles="1",
    ))
    add(base_row(
        rom_addr="0xE1", region="reserved", mnemonic="ECALL", group="system",
        status="burn", semantic_op="ECALL", operation="trap 0x100",
        cycles="1",
    ))
    add(base_row(
        rom_addr="0xE2", region="reserved", mnemonic="EBREAK", group="system",
        status="burn", semantic_op="EBREAK", operation="halt (debug)",
        cycles="1",
    ))
    add(base_row(
        rom_addr="0xFF", region="system", mnemonic="HALT", group="system",
        status="burn", semantic_op="HALT", operation="halt",
        cycles="1", encoding="reg_reg",
    ))
    return rows


def growth_templates():
    """Fill regional holes with ops the FPGA datapath can execute."""
    g = []

    def alu_reg(addr, name, **kw):
        flags = kw.pop("flags_we", "1")
        we = kw.pop("reg_we", "1")
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-reg", mnemonic=name,
            group="alu-reg", status="growth", semantic_op=name,
            ir_imm_sel="1", reg_we=we, bank_en="0",
            flags_we=flags, cycles="1",
            operation=kw.pop("operation", name), **kw,
        ))

    def alu_imm(addr, name, imm_sel, **kw):
        flags = kw.pop("flags_we", "1")
        we = kw.pop("reg_we", "1")
        wb = kw.pop("wb_sel", "0")
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-imm", mnemonic=name,
            group="alu-imm", status="growth", semantic_op=name,
            ir_imm_sel=str(imm_sel), reg_we=we, bank_en="0",
            flags_we=flags, wb_sel=str(wb), cycles="1", encoding="imm",
            operation=kw.pop("operation", name), **kw,
        ))

    def shift(addr, name, sop, imm_sel=1, **kw):
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="shift", mnemonic=name,
            group="shift", status="growth", semantic_op=name,
            ir_imm_sel=str(imm_sel), shift_op=str(sop), wb_sel="1",
            reg_we="1", bank_en="0", cycles="1",
            operation=kw.pop("operation", name), **kw,
        ))

    def mem(addr, name, rd, wr, byte, bussel=1, **kw):
        # Loads: addr = rA + imm13 (alusel=0). Stores: addr = rB + imm8 (alusel=1).
        if wr and "ir_imm_sel" not in kw:
            kw.setdefault("ir_imm_sel", "0")
            kw.setdefault("mem_sel", "1")  # ALU.A = rB
            kw.setdefault("wb_sel", 4)
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="mem", mnemonic=name,
            group="mem", status="growth", semantic_op=name,
            ir_imm_sel=kw.pop("ir_imm_sel", "3"),
            reg_we="1" if rd else "0", bank_en="0",
            mem_rd="1" if rd else "0", mem_wr="1" if wr else "0",
            byte_sel=str(byte), wb_sel=str(kw.pop("wb_sel", 3 if rd else 0)),
            cycles="2", ctrl_bussel=str(bussel),
            mem_sel=str(kw.pop("mem_sel", "0")),
            operation=kw.pop("operation", name), **kw,
        ))

    def branch(addr, name, cond, **kw):
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="branch", mnemonic=name,
            group="branch", status="growth", semantic_op=name,
            ir_imm_sel="12", branch_en="1", pc_src="1", pc_cond=str(cond),
            cycles="1", operation=kw.pop("operation", name), **kw,
        ))

    def jump(addr, name, **kw):
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="jump", mnemonic=name,
            group="jump", status="growth", semantic_op=name,
            jump_type="1", cycles="1",
            operation=kw.pop("operation", name), **kw,
        ))

    def muldiv(addr, name, mul, div, wb, **kw):
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="alu-reg", mnemonic=name,
            group="muldiv", status="growth", semantic_op=name,
            ir_imm_sel="1", wb_sel=str(wb), reg_we="1", bank_en="0",
            mul_en=str(mul), div_en=str(div), cycles="1",
            operation=kw.pop("operation", name), **kw,
        ))

    def stack(addr, name, **kw):
        sem = kw.pop("semantic_op", name)
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="stack-io", mnemonic=name,
            group="stack", status="growth", semantic_op=sem,
            cycles=kw.pop("cycles", "2"),
            operation=kw.pop("operation", name), **kw,
        ))

    def system(addr, name, **kw):
        g.append(base_row(
            rom_addr=f"0x{addr:02X}", region="reserved", mnemonic=name,
            group="system", status="growth", semantic_op=name,
            cycles="1", operation=kw.pop("operation", name), **kw,
        ))

    # --- alu-reg 0x08–0x1F ---
    alu_reg(0x08, "MOVA", operation="rd = rA", flags_we="0")
    alu_reg(0x09, "NOT", operation="rd = ~rA")
    alu_reg(0x0A, "NEG", operation="rd = -rA")
    alu_reg(0x0B, "INC", operation="rd = rA + 1")
    alu_reg(0x0C, "NAND", operation="rd = ~(rA & rB)")
    alu_reg(0x0D, "NOR", operation="rd = ~(rA | rB)")
    alu_reg(0x0E, "XNOR", operation="rd = ~(rA ^ rB)")
    alu_reg(0x0F, "DEC", operation="rd = rA - 1")
    muldiv(0x10, "MUL", 1, 0, 1, operation="rd = low(rA*rB)")
    muldiv(0x11, "MULH", 1, 0, 7, operation="rd = high(rA*rB)")
    muldiv(0x12, "DIV", 1, 1, 1, operation="rd = rA / rB")
    muldiv(0x13, "REM", 1, 1, 7, operation="rd = rA % rB")
    muldiv(0x14, "MULHU", 1, 0, 7, operation="rd = high unsigned (alias MULH)")
    muldiv(0x15, "DIVU", 1, 1, 1, operation="rd = rA / rB (alias DIV)")
    muldiv(0x16, "REMU", 1, 1, 7, operation="rd = rA % rB (alias REM)")
    alu_reg(0x17, "ADC", operation="rd = rA + rB + C")
    alu_reg(0x18, "SBC", operation="rd = rA - rB + C_in")
    alu_reg(0x19, "RSB", operation="rd = rB - rA")
    alu_reg(0x1A, "ANDN", operation="rd = rA & ~rB")
    alu_reg(0x1B, "ORN", operation="rd = rA | ~rB")
    alu_reg(0x1C, "MVN", operation="rd = ~rB")
    alu_reg(0x1D, "TST", operation="flags = rA & rB", reg_we="0")
    alu_reg(0x1E, "TEQ", operation="flags = rA ^ rB", reg_we="0")
    alu_reg(0x1F, "CMN", operation="flags = rA + rB", reg_we="0")

    # --- alu-imm 0x25–0x3F ---
    alu_imm(0x25, "CMPI", 3, operation="flags = rA - imm", reg_we="0")
    alu_imm(0x26, "LSLI", 0, shift_op="0", wb_sel="1", flags_we="0",
            operation="rd = rA << imm[4:0]")
    alu_imm(0x27, "LSRI", 0, shift_op="1", wb_sel="1", flags_we="0",
            operation="rd = rA >> imm[4:0]")
    alu_imm(0x28, "ASRI", 0, shift_op="2", wb_sel="1", flags_we="0",
            operation="rd = rA >>> imm[4:0]")
    alu_imm(0x29, "RORI", 0, shift_op="3", wb_sel="1", flags_we="0",
            operation="rd = rA ror imm[4:0]")
    alu_imm(0x2A, "ADDI16", 7, operation="rd = rA + imm16z")
    alu_imm(0x2B, "SUBI", 3, operation="rd = rA - imm")
    alu_imm(0x2C, "CMPI16", 7, operation="flags = rA - imm16", reg_we="0")
    alu_imm(0x2D, "MOVI", 7, wb_sel="5", flags_we="0",
            operation="rd = imm16z")
    alu_imm(0x2E, "MOVIL", 0, wb_sel="5", flags_we="0",
            operation="rd = imm8z")
    alu_imm(0x2F, "SEXTI", 2, wb_sel="5", flags_we="0",
            operation="rd = sext imm8")
    alu_imm(0x30, "ZERO", 1, flags_we="0", operation="rd = 0")
    alu_imm(0x31, "ONE", 1, flags_we="0", operation="rd = 1")
    alu_imm(0x32, "ALLONES", 1, flags_we="0", operation="rd = -1")
    alu_imm(0x33, "ANDNI", 7, operation="rd = rA & ~imm16")
    alu_imm(0x34, "ORNI", 7, operation="rd = rA | ~imm16")
    alu_imm(0x35, "NANDI", 7, operation="rd = ~(rA & imm16)")
    alu_imm(0x36, "NORI", 7, operation="rd = ~(rA | imm16)")
    alu_imm(0x37, "XNORI", 7, operation="rd = ~(rA ^ imm16)")
    alu_imm(0x38, "ADCI", 3, operation="rd = rA + imm + C")
    alu_imm(0x39, "SBCI", 3, operation="rd = rA - imm + C_in")
    alu_imm(0x3A, "INCI", 1, operation="rd = rA + 1")
    alu_imm(0x3B, "DECI", 1, operation="rd = rA - 1")
    alu_imm(0x3C, "NOTI", 1, operation="rd = ~rA")
    alu_imm(0x3D, "NEGI", 1, operation="rd = -rA")
    alu_imm(0x3E, "MOVAI", 1, flags_we="0", operation="rd = rA")
    alu_imm(0x3F, "TSTI", 7, operation="flags = rA & imm16", reg_we="0")

    # --- shift 0x43–0x5F ---
    shift(0x43, "ROR", 3, operation="rd = rA ror rB")
    shift(0x44, "ROL", 3, operation="rd = rA ror rB (SW: amt=32-n for rol)")
    for a, name, sop in [
        (0x45, "LSLR", 0), (0x46, "LSRR", 1), (0x47, "ASRR", 2), (0x48, "RORR", 3),
    ]:
        shift(a, name, sop, operation=f"alias {name}")
    shift(0x49, "SHLI", 0, imm_sel=0, operation="rd = rA << imm8")
    shift(0x4A, "SHRI", 1, imm_sel=0, operation="rd = rA >> imm8")
    shift(0x4B, "SARI", 2, imm_sel=0, operation="rd = rA >>> imm8")
    shift(0x4C, "RORI8", 3, imm_sel=0, operation="rd = rA ror imm8")
    for a in range(0x4D, 0x60):
        shift(a, f"SH{a:02X}", a & 3, operation="shift slot (mode=addr[1:0])")

    # --- mem 0x62–0x7F (burn owns 0x60/61/68/69) ---
    mem(0x62, "LH", 1, 0, 12, operation="rd = sext half")
    mem(0x63, "LBU", 1, 0, 8, operation="rd = zext byte")
    mem(0x64, "LHU", 1, 0, 14, operation="rd = zext half")
    mem(0x65, "LB1", 1, 0, 5, operation="rd = sext byte1")
    mem(0x66, "LB2", 1, 0, 6, operation="rd = sext byte2")
    mem(0x67, "LB3", 1, 0, 7, operation="rd = sext byte3")
    mem(0x6A, "SH", 0, 1, 12, operation="store half")
    mem(0x6B, "SB1", 0, 1, 5, operation="store byte1 lane")
    mem(0x6C, "SB2", 0, 1, 6, operation="store byte2 lane")
    mem(0x6D, "SB3", 0, 1, 7, operation="store byte3 lane")
    mem(0x6E, "LWABS", 1, 0, 0, bussel=0, ir_imm_sel="14", mem_sel="0",
        operation="rd = mem[abs22]")
    mem(0x6F, "SWABS", 0, 1, 0, bussel=0, ir_imm_sel="14", wb_sel=4, mem_sel="0",
        operation="mem[abs22] = rA")
    mem(0x70, "LWPC", 1, 0, 0, bussel=3, mem_sel="0", operation="rd = mem[PC]")
    mem(0x71, "LWRB", 1, 0, 0, bussel=2, ir_imm_sel="1", mem_sel="0",
        operation="rd = mem[rB]")
    mem(0x72, "SWRB", 0, 1, 0, bussel=2, ir_imm_sel="1", wb_sel=4, mem_sel="0",
        operation="mem[rB] = rA")
    mem(0x73, "LWALU", 1, 0, 0, bussel=1, operation="rd = mem[ALU]")
    mem(0x74, "SWALU", 0, 1, 0, bussel=1, wb_sel=4, mem_sel="1",
        operation="mem[rB+imm] = rA")
    for a, byte in [(0x75, 9), (0x76, 10), (0x77, 11)]:
        mem(a, f"LBU{a:02X}", 1, 0, byte, operation="zext byte lane")
    for a in range(0x78, 0x80):
        mem(a, f"ME{a:02X}", 1, 0, 0, operation="LW-class growth")

    # --- branch 0x83–0x9F  csr: Z ~Z N C V LT GT GTE ---
    branch(0x83, "BGE", 7, operation="branch if GTE")
    branch(0x84, "BLTU", 5, operation="branch if LT")
    branch(0x85, "BGEU", 6, operation="branch if GT")
    branch(0x86, "BMI", 2, operation="branch if N")
    branch(0x87, "BCS", 3, operation="branch if C")
    branch(0x88, "BVS", 4, operation="branch if V")
    branch(0x89, "BLT_U", 5, operation="branch if LT")
    branch(0x8A, "BGT", 6, operation="branch if GT")
    branch(0x8B, "BGE_S", 7, operation="branch if GTE")
    branch(0x8C, "BLE", 5, operation="branch if LT (approx <=)")
    branch(0x8D, "BGTU", 6, operation="branch if GT")
    branch(0x8E, "BLEU", 5, operation="branch if LT")
    branch(0x8F, "BZ", 0, operation="alias BEQ")
    branch(0x90, "BNZ", 1, operation="alias BNE (~Z)")
    for a in range(0x91, 0xA0):
        branch(a, f"B{a:02X}", a & 7, operation="cond branch slot")

    # --- jump 0xA4–0xBF ---
    jump(0xA4, "JALR", ir_imm_sel="3", wb_sel="2", reg_we="1", bank_en="0",
         pc_src="4", pc_link_we="1", operation="rd=PC+1; PC=alu")
    jump(0xA5, "JMPABS", ir_imm_sel="13", pc_src="0", operation="PC = abs")
    jump(0xA6, "JMPREL", ir_imm_sel="12", pc_src="1", operation="PC = PC+off")
    jump(0xA7, "JALABS", ir_imm_sel="13", pc_src="0", wb_sel="2", reg_we="1",
         bank_en="0", pc_link_we="1", operation="call abs")
    jump(0xA8, "JALREL", ir_imm_sel="12", pc_src="1", wb_sel="2", reg_we="1",
         bank_en="0", pc_link_we="1", operation="call rel")
    jump(0xA9, "JRAL", ir_imm_sel="1", pc_src="4", wb_sel="2", reg_we="1",
         bank_en="0", pc_link_we="1", operation="call via ALU/reg")
    jump(0xAA, "JMPI", ir_imm_sel="14", pc_src="0", operation="PC = ir_abs")
    jump(0xAB, "RETL", pc_src="2", operation="PC = link")
    for a in range(0xAC, 0xC0):
        jump(a, f"J{a:02X}", ir_imm_sel="13", pc_src="0", operation="jump slot")

    # --- stack-io 0xC0–0xDF ---
    stack(0xC0, "PUSH", sp_op="2", mem_wr="1", ctrl_bussel="7", wb_sel="4",
          operation="SP-=4; mem[SP]=rA")
    stack(0xC1, "POP", sp_op="1", mem_rd="1", ctrl_bussel="7", wb_sel="3",
          reg_we="1", bank_en="0", operation="rd=mem[SP]; SP+=4")
    stack(0xC2, "PUSHLR", sp_op="2", mem_wr="1", ctrl_bussel="7", wb_sel="2",
          operation="push link (wb=pc_save)")
    stack(0xC3, "POPLR", sp_op="1", mem_rd="1", ctrl_bussel="7",
          pc_src="5", jump_type="1", operation="PC=mem[SP]; SP+=4")
    stack(0xC4, "MOVSP", sp_op="3", ir_imm_sel="1", cycles="1",
          semantic_op="MOV", operation="SP = rB (ALU pass B)")
    stack(0xC5, "ADDSP", sp_op="1", cycles="1", operation="SP += 4")
    stack(0xC6, "SUBSP", sp_op="2", cycles="1", operation="SP -= 4")
    stack(0xC7, "BANK", bank_en="1", cycles="1", operation="latch bank from IR")
    stack(0xC8, "IN", byte_sel="2", wb_sel="3", reg_we="1", cycles="1",
          operation="rd = zext(kb_data)", semantic_op="IN")
    stack(0xC9, "OUT", ir_imm_sel="1", wb_sel="4", cycles="1",
          operation="io_out = rA[7:0]", semantic_op="OUT")
    for a in range(0xCA, 0xE0):
        stack(a, f"IO{a:02X}", cycles="1", operation="stack/io reserved slot")

    # --- system / reserved 0xE0–0xFE ---
    system(0xE0, "FENCE", operation="nop barrier")
    system(0xE1, "ECALL", operation="trap to 0x100; link=fallthrough")
    system(0xE2, "EBREAK", operation="halt (sticky debug)")
    system(0xE3, "YIELD", operation="nop yield")
    system(0xE4, "WFI", operation="nop wait")
    for a in range(0xE5, 0xFF):
        system(a, f"SYS{a:02X}", operation="system slot")

    # --- 0x100–0x1FF: LUT-plane playground ---
    for a in range(0x100, 0x200):
        kind = a & 3
        name = ("LUTADD", "LUTAND", "LUTXOR", "LUTMOV")[kind]
        sem = ("ADD", "AND", "XOR", "MOV")[kind]
        g.append(base_row(
            rom_addr=f"0x{a:03X}", region="lut-plane", mnemonic=f"{name}{a:03X}",
            group="lut", status="growth", semantic_op=sem,
            ir_imm_sel="1", reg_we="1", bank_en="0",
            flags_we="1" if kind < 3 else "0",
            cycles="1", operation=f"lut-plane {sem}",
        ))

    return g


def fix_burn_row(row):
    """FPGA B-bus: reg-reg ops must select reg_b (imm_sel=1)."""
    r = dict(row)
    sem = r.get("semantic_op") or r.get("mnemonic")
    reg_reg = {
        "ADD", "SUB", "AND", "OR", "XOR", "MOV", "CMP", "CMN",
        "LSL", "LSR", "ASR", "ROR", "ROL",
        "MUL", "MULH", "MULHU", "DIV", "DIVU", "REM", "REMU",
        "MOVA", "NOT", "NEG", "INC", "DEC", "NAND", "NOR", "XNOR",
        "ADC", "SBC", "RSB", "ANDN", "ORN", "MVN", "TST", "TEQ",
        "ZERO", "ONE", "ALLONES",
    }
    if sem in reg_reg:
        r["ir_imm_sel"] = "1"
    return r


def pack(row):
    sem = row.get("semantic_op") or row.get("mnemonic") or "NOP"
    # SH* filler slots still carry shift_op in the row
    is_shift = (
        sem in SHIFT_OPS
        or (isinstance(sem, str) and sem.startswith("SH") and len(sem) == 4)
    )
    cin = i(row, "cin_sel") & 7
    flags = i(row, "flags_we") & 1
    shift = i(row, "shift_op") & 3
    mul = i(row, "mul_en") & 1
    div = i(row, "div_en") & 1
    mul_div = 1 if (mul or div) else 0

    if sem in DUAL:
        lut_a, lut_b, dual_cin = DUAL[sem]
        cin = dual_cin
    else:
        lut_a = i(row, "alu_op") & 0xFF
        lut_b = 0x00

    if is_shift or mul or div:
        lut_a, lut_b = 0, 0

    # When mul/div: mode[0] (shift_op bit0) selects unsigned (MULHU/DIVU/REMU)
    if mul or div:
        if sem in ("MULHU", "DIVU", "REMU"):
            shift = 1
        else:
            shift = 0

    return {
        "alu_control_1": lut_a,
        "alu_lut_b": lut_b,
        "alu_shift_control": cin | (flags << 3) | (shift << 4) | (mul_div << 6) | ((1 if div else 0) << 7),
        "ir_reg_control": (i(row, "ir_imm_sel") & 0xF)
        | ((i(row, "wb_sel") & 7) << 4)
        | ((i(row, "reg_we") & 1) << 7),
        "mem_bus_control": (i(row, "ctrl_bussel") & 7) | ((i(row, "mem_sel") & 1) << 3),
        "mem_io_control": (i(row, "bank_en") & 1)
        | ((i(row, "mem_rd") & 1) << 1)
        | ((i(row, "mem_wr") & 1) << 2)
        | ((i(row, "byte_sel") & 0xF) << 3),
        "pc_control": (i(row, "branch_en") & 1)
        | ((i(row, "jump_type") & 1) << 1)
        | ((i(row, "pc_src") & 7) << 2)
        | ((i(row, "pc_link_we") & 1) << 5)
        | ((i(row, "cycles") & 3) << 6),
        # Match control.v: pc_cond[2:0], sp_op[5:4]
        "pc_sp_mul_control": (i(row, "pc_cond") & 7) | ((i(row, "sp_op") & 3) << 4),
        "shift_mul_control": shift | (mul_div << 2) | ((1 if div else 0) << 3),
    }


def build_table(rebuild: bool = False, pack_rom: bool = False):
    """Load tomato.v1.csv. With --pack-rom/--rebuild, regenerate.

    pack_rom: solidified burn_core_rows() + NOP fill (recommended)
    rebuild:  burn from CSV/core + growth templates + NOP holes (legacy bloat)
    """
    if pack_rom:
        by_addr = {int(r["rom_addr"], 16): r for r in burn_core_rows()}
        nop = fix_burn_row(next(r for r in by_addr.values() if r["mnemonic"] == "NOP"))
        for addr in range(DEPTH):
            if addr not in by_addr:
                r = dict(nop)
                r["rom_addr"] = f"0x{addr:02X}" if addr < 256 else f"0x{addr:03X}"
                r["status"] = "nop"
                r["mnemonic"] = "NOP"
                r["semantic_op"] = "NOP"
                r["notes"] = "unused-slot"
                by_addr[addr] = r
        rows = []
        for addr in range(DEPTH):
            r = dict(by_addr[addr])
            r["rom_addr"] = f"0x{addr:02X}" if addr < 256 else f"0x{addr:03X}"
            rows.append(fix_burn_row(r))
        return rows

    existing = [fix_burn_row(r) for r in load_v1()]
    by_addr = {int(r["rom_addr"], 16): r for r in existing}

    if rebuild:
        burn = {a: r for a, r in by_addr.items() if r.get("status") == "burn"}
        if len(burn) < 20:
            burn = {int(r["rom_addr"], 16): r for r in burn_core_rows()}
        by_addr = dict(burn)
        for g in growth_templates():
            a = int(g["rom_addr"], 16)
            if a not in by_addr:
                by_addr[a] = g
        nop = fix_burn_row(next(r for r in burn.values() if r["mnemonic"] == "NOP"))
        for addr in range(DEPTH):
            if addr not in by_addr:
                r = dict(nop)
                r["rom_addr"] = f"0x{addr:02X}" if addr < 256 else f"0x{addr:03X}"
                r["status"] = "nop"
                r["mnemonic"] = "NOP"
                r["semantic_op"] = "NOP"
                r["notes"] = "fill"
                by_addr[addr] = r

    if len(by_addr) != DEPTH and not rebuild:
        raise SystemExit(
            f"{V1.relative_to(ROOT)} has {len(by_addr)} rows; need {DEPTH}. "
            f"Run with --pack-rom (recommended) or --rebuild."
        )

    rows = []
    for addr in range(DEPTH):
        if addr not in by_addr:
            raise SystemExit(f"missing rom_addr 0x{addr:03X}")
        r = dict(by_addr[addr])
        r["rom_addr"] = f"0x{addr:02X}" if addr < 256 else f"0x{addr:03X}"
        rows.append(fix_burn_row(r))
    return rows


def write_v1_csv(rows):
    header = """# Tomato ISA v1 — SINGLE AUTHORITY (512 ROM rows).
# status=burn: solidified datapath-backed opcodes (add here as you need more)
# status=nop: unused ROM slot (empty — not a fake mnemonic)
# Pack ROM: python3 tools/gen_microcode_v1.py --pack-rom
# Optional growth fill (legacy): python3 tools/gen_microcode_v1.py --rebuild
#
# ENCODING:
#   R-type:  {op[8:0], rd[4:0], rA[4:0], rB[4:0], rC[4:0], bank[2:0]}
#   I-type:  {op, rd, rA, imm13}              — ADDI / LW (imm=IR[12:0])
#   Store:   {op, 0, rA_data, rB_base, imm8}  — SW/SB (ALU.A=rB via mem_sel)
#   Branch:  {op, 0, off[21:0]}               — PC-relative (pc_src=1)
#
# BURN surface: ALU/logic/imm/shift/mem/branch/jump/stack/IO/system
# (see burn_core_rows in tools/gen_microcode_v1.py — do not silently drop)
#
"""
    fields = list(rows[0].keys())
    with V1.open("w", newline="") as f:
        f.write(header)
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {V1.relative_to(ROOT)} ({len(rows)} rows)")


def verify_mem_images(images) -> int:
    """Return number of mismatches between packed images and on-disk tb/mem + microcode mem."""
    mismatches = 0
    for key, fname in ROM_FILES.items():
        mem_name = fname.replace(".hex", ".mem")
        for dest in (MC / mem_name, FPGA_MEM / mem_name):
            if not dest.exists():
                print(f"MISSING {dest.relative_to(ROOT)}")
                mismatches += 1
                continue
            lines = [ln.strip() for ln in dest.read_text().splitlines() if ln.strip()]
            if lines and lines[0].startswith("v2.0"):
                lines = lines[1:]
            if len(lines) != DEPTH:
                print(f"BAD LEN {dest.relative_to(ROOT)}: {len(lines)} != {DEPTH}")
                mismatches += 1
                continue
            for addr, (got_s, exp) in enumerate(zip(lines, images[key])):
                got = int(got_s, 16)
                if got != exp:
                    print(
                        f"MISMATCH {dest.name} @{addr:#05x}: "
                        f"file={got:02x} expected={exp:02x} ({key})"
                    )
                    mismatches += 1
                    if mismatches > 40:
                        print("… truncated")
                        return mismatches
    return mismatches


def pack_images(rows):
    nop = pack(next(r for r in rows if r["mnemonic"] == "NOP" and int(r["rom_addr"], 16) == 0))
    images = {k: [nop[k]] * DEPTH for k in ROM_FILES}
    burn_n = growth_n = nop_n = 0
    for row in rows:
        addr = int(row["rom_addr"], 16)
        p = pack(row)
        for k, v in p.items():
            images[k][addr] = v
        st = row.get("status", "")
        if st == "burn":
            burn_n += 1
        elif st == "growth":
            growth_n += 1
        else:
            nop_n += 1
    return images, burn_n, growth_n, nop_n


def write_images(images):
    FPGA_MEM.mkdir(parents=True, exist_ok=True)
    for key, fname in ROM_FILES.items():
        path = MC / fname
        with path.open("w") as f:
            f.write("v2.0 raw\n")
            for b in images[key]:
                f.write(f"{b:02x}\n")
        print(f"wrote {path.relative_to(ROOT)}")
        mem_name = fname.replace(".hex", ".mem")
        for dest in (MC / mem_name, FPGA_MEM / mem_name):
            with dest.open("w") as f:
                for b in images[key]:
                    f.write(f"{b:02x}\n")
            print(f"wrote {dest.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--rebuild",
        action="store_true",
        help="legacy: burn + growth templates + NOP holes (phantom mnemonics)",
    )
    ap.add_argument(
        "--pack-rom",
        "--lean",  # alias kept for older Makefiles
        dest="pack_rom",
        action="store_true",
        help="solidified burn_core + NOP unused slots (recommended)",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="verify on-disk .mem matches pack(tomato.v1.csv); do not rewrite",
    )
    args = ap.parse_args()

    rows = build_table(rebuild=args.rebuild, pack_rom=args.pack_rom)
    if args.rebuild or args.pack_rom:
        write_v1_csv(rows)

    images, burn_n, growth_n, nop_n = pack_images(rows)

    if args.check:
        n = verify_mem_images(images)
        if n:
            print(f"FAIL: burn check ({n} mismatches) burn={burn_n} growth={growth_n}")
            return 1
        print(
            f"PASS: burn check ({V1.relative_to(ROOT)} ↔ mem) "
            f"burn={burn_n} growth={growth_n} nop={nop_n}"
        )
        return 0

    write_images(images)
    n = verify_mem_images(images)
    if n:
        print(f"FAIL: post-write verify ({n} mismatches)")
        return 1
    print(f"packed {V1.relative_to(ROOT)} (burn={burn_n} growth={growth_n} nop={nop_n})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
