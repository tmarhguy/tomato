#!/usr/bin/env python3
"""Regression for overlapping emitted data, reserved RAM, and capacity limits."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'software'))
import assembler

ops = assembler.load_opcodes()
for source in (
    '.word 1\n.org 0\n.word 2',
    '.space 10\n.org 9\n.word 1',
    '.space 10\n.org 5\n.space 3',
    '.org 16380\n.space 8',
):
    try:
        assembler.assemble(source, ops, strict_layout=True, max_words=16384)
    except assembler.AsmError:
        pass
    else:
        raise AssertionError(f'Accepted invalid layout: {source}')
assembler.assemble('.space 10\n.word 1', ops, strict_layout=True, max_words=11)
print('PASS: OS layout rejects overlaps/overflow and accepts adjacent regions')
