#!/usr/bin/env python3
"""Generate Digital Testcase blocks for alu-32b-final.dig (dual-LUT ripple adder model)."""

from __future__ import annotations

import argparse
import sys

# 3-input LUT index: 4*c + 2*b + a  (matches alu_1b_final mux select {C,B,A})


def lut3(op: int, a: int, b: int, c: int) -> int:
    idx = (c << 2) | (b << 1) | a
    return (op >> idx) & 1


def predict_4b(lut_a: int, lut_b: int, a: int, b: int, c: int, cin: int) -> tuple[int, int]:
    carry = cin
    out = 0
    for i in range(4):
        ai = (a >> i) & 1
        bi = (b >> i) & 1
        ci = (c >> i) & 1
        y = lut3(lut_a, ai, bi, ci)
        x = lut3(lut_b, ai, bi, ci)
        total = y + x + carry
        out |= (total & 1) << i
        carry = total >> 1
    return out, carry


def predict_8b(lut_a: int, lut_b: int, a: int, b: int, c: int, cin: int) -> tuple[int, int]:
    lo, c1 = predict_4b(lut_a, lut_b, a & 0xF, b & 0xF, c & 0xF, cin)
    hi, cout = predict_4b(lut_a, lut_b, (a >> 4) & 0xF, (b >> 4) & 0xF, (c >> 4) & 0xF, c1)
    return lo | (hi << 4), cout


def cin_from_csel(csel: int) -> int:
    """Byte-0 carry mux (74151); flag sources treated as 0 for static tests."""
    table = {0: 0, 1: 1, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0}
    return table.get(csel & 7, 0)


def predict_32b(lut_a: int, lut_b: int, a: int, b: int, c: int, csel: int = 0) -> int:
    carry = cin_from_csel(csel)
    out = 0
    for byte in range(4):
        av = (a >> (8 * byte)) & 0xFF
        bv = (b >> (8 * byte)) & 0xFF
        cv = (c >> (8 * byte)) & 0xFF
        ov, carry = predict_8b(lut_a, lut_b, av, bv, cv, carry)
        out |= ov << (8 * byte)
    return out


LUT = {
    "ZERO": 0x00,
    "PASS_A": 0xAA,
    "PASS_B": 0xCC,
    "PASS_C": 0xF0,
    "AND": 0x80,
    "OR": 0xFE,
    "XOR": 0x96,
    "NAND": 0x7F,
    "NOR": 0x01,
    "XNOR": 0x69,
    "NOT_B": 0x33,
}


def row(lut_a: int, lut_b: int, a: int, b: int, c: int, csel: int, out: int) -> str:
    return f"0x{lut_a:02X} 0x{lut_b:02X} 0x{a:08X} 0x{b:08X} 0x{c:08X} {csel} 0 0 0x{out:08X}"


def header() -> list[str]:
    return [
        "lutA lutB A B C csel FLAG_WE CLK OUT",
        "",
        "# Dual-LUT ALU: OUT = f(a,b,c)+g(a,b,c)+cin per bit; index = 4c+2b+a",
    ]


def gen_lut_encoding_tests() -> list[str]:
    lines = ["alu-lut-encoding-tests", *header(), "# Smoke: canonical primitives via lutA, lutB=0"]
    zero_b = LUT["ZERO"]
    cases = [
        (LUT["PASS_A"], 0x00000001, 0, 0),
        (LUT["PASS_A"], 0x00000002, 0, 0),
        (LUT["PASS_B"], 0, 0x00000004, 0),
        (LUT["PASS_C"], 0, 0, 0x00000008),
        (LUT["AND"], 0x00000001, 0x00000001, 0x00000001),
        (LUT["AND"], 0x00000001, 0x00000001, 0),
        (LUT["XOR"], 0x00000001, 0, 0),
        (LUT["XOR"], 0x00000001, 0x00000001, 0),
        (LUT["OR"], 0, 0, 0),
        (LUT["OR"], 0x00000001, 0, 0x00000001),
        (LUT["NAND"], 0x00000001, 0x00000001, 0x00000001),
        (LUT["NOR"], 0, 0, 0),
    ]
    for la, a, b, c in cases:
        out = predict_32b(la, zero_b, a, b, c, 0)
        lines.append(row(la, zero_b, a, b, c, 0, out))
    return lines


def gen_add_pass_ab_tests() -> list[str]:
    lines = ["alu-add-passAB-tests", *header(), "# A+B: lutA=0xAA lutB=0xCC csel=0"]
    la, lb = LUT["PASS_A"], LUT["PASS_B"]
    pairs = [
        (0, 0),
        (5, 3),
        (0xFFFFFFFF, 1),
        (0x80000000, 0x80000000),
        (0x12345678, 0x9ABCDEF0),
        (0x0000FFFF, 1),
        (0x00FF00FF, 0x0000FF01),
    ]
    for a, b in pairs:
        lines.append(row(la, lb, a, b, 0, 0, predict_32b(la, lb, a, b, 0, 0)))
    return lines


def gen_add_cin_tests() -> list[str]:
    lines = ["alu-add-cin-tests", *header(), "# A+B+1: csel=1"]
    la, lb = LUT["PASS_A"], LUT["PASS_B"]
    for a, b in [(0, 0), (5, 3), (0xFFFFFFFF, 0)]:
        lines.append(row(la, lb, a, b, 0, 1, predict_32b(la, lb, a, b, 0, 1)))
    return lines


def gen_csel_exhaustive_tests() -> list[str]:
    lines = ["alu-csel-exhaustive", *header(), "# All 8 csel values, PASS_A+PASS_B, fixed operands"]
    la, lb = LUT["PASS_A"], LUT["PASS_B"]
    a, b = 0x12345678, 0x9ABCDEF0
    for csel in range(8):
        lines.append(row(la, lb, a, b, 0, csel, predict_32b(la, lb, a, b, 0, csel)))
    return lines


def gen_and_xor_sum_tests() -> list[str]:
    lines = ["alu-and-xor-sum-tests", *header(), "# lutA=AND3 lutB=XOR3"]
    la, lb = LUT["AND"], LUT["XOR"]
    for a, b in [(0, 0), (1, 0), (1, 1), (5, 3), (0xFF, 0xAA), (0x12345678, 0x9ABCDEF0)]:
        lines.append(row(la, lb, a, b, 0, 0, predict_32b(la, lb, a, b, 0, 0)))
    return lines


def gen_sub_smoke_tests() -> list[str]:
    lines = ["alu-sub-smoke-tests", *header(), "# A-B via lutB=NOT_B, csel=1"]
    la, lb = LUT["PASS_A"], LUT["NOT_B"]
    for a, b in [(10, 3), (3, 10), (0, 1), (0xFFFFFFFF, 1)]:
        lines.append(row(la, lb, a, b, 0, 1, predict_32b(la, lb, a, b, 0, 1)))
    return lines


def gen_add_pass_ab_exhaustive8() -> list[str]:
    lines = [
        "alu-add-passAB-exhaustive8",
        *header(),
        "# Exhaustive 256x256 low-byte A+B (PASS_A + PASS_B, csel=0).",
    ]
    la, lb = LUT["PASS_A"], LUT["PASS_B"]
    for a in range(256):
        for b in range(256):
            lines.append(row(la, lb, a, b, 0, 0, predict_32b(la, lb, a, b, 0, 0)))
    return lines


def gen_lut_exhaustive_abc_block(abc: int) -> list[str]:
    """One of 8 minterms: exhaustive all 256x256 lutA/lutB pairs on bit 0."""
    a_bit = abc & 1
    b_bit = (abc >> 1) & 1
    c_bit = (abc >> 2) & 1
    a = a_bit
    b = b_bit
    c = c_bit
    label = f"alu-lut-exhaustive-abc{abc:03b}"
    lines = [
        label,
        *header(),
        f"# Exhaustive 256x256 lutA/lutB for minterm abc={abc:03b} (a={a_bit},b={b_bit},c={c_bit}) on bit 0.",
        f"# Block {abc + 1}/8 of 524288 total LUT-pair x minterm vectors.",
    ]
    for la in range(256):
        for lb in range(256):
            lines.append(row(la, lb, a, b, c, 0, predict_32b(la, lb, a, b, c, 0)))
    return lines


def testcase_xml(label: str, lines: list[str], x: int, y: int) -> str:
    body = "\n".join(lines)
    return f"""    <visualElement>
      <elementName>Testcase</elementName>
      <elementAttributes>
        <entry>
          <string>Label</string>
          <string>{label}</string>
        </entry>
        <entry>
          <string>Testdata</string>
          <testData>
            <dataString>{body}
</dataString>
          </testData>
        </entry>
      </elementAttributes>
      <pos x="{x}" y="{y}"/>
    </visualElement>"""


def all_blocks(*, exhaustive_lut: bool, exhaustive_add8: bool) -> list[tuple[str, list[str], int, int]]:
    blocks: list[tuple[str, list[str], int, int]] = []
    y = -900
    smoke = [
        gen_lut_encoding_tests(),
        gen_add_pass_ab_tests(),
        gen_add_cin_tests(),
        gen_csel_exhaustive_tests(),
        gen_and_xor_sum_tests(),
        gen_sub_smoke_tests(),
    ]
    for lines in smoke:
        blocks.append((lines[0], lines, 3100, y))
        y += 120
    if exhaustive_add8:
        lines = gen_add_pass_ab_exhaustive8()
        blocks.append((lines[0], lines, 3100, y))
        y += 120
    if exhaustive_lut:
        for abc in range(8):
            lines = gen_lut_exhaustive_abc_block(abc)
            blocks.append((lines[0], lines, 3100, y))
            y += 120
    return blocks


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Digital ALU test XML")
    parser.add_argument("--smoke-only", action="store_true", help="Skip exhaustive suites")
    parser.add_argument("--no-add8", action="store_true", help="Skip 256x256 add exhaustive")
    args = parser.parse_args()

    blocks = all_blocks(
        exhaustive_lut=not args.smoke_only,
        exhaustive_add8=not args.smoke_only and not args.no_add8,
    )
    xml_parts = [testcase_xml(label, lines[1:], x, y) for label, lines, x, y in blocks]
    sys.stdout.write("\n".join(xml_parts))


if __name__ == "__main__":
    main()
