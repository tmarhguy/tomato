#!/usr/bin/env python3
"""Inject generated Testcase blocks into alu-32b-final.dig (removes broken empty 'arith' block)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIG = ROOT / "modules" / "alu-32b-final.dig"
GEN = Path(__file__).resolve().parent / "gen_alu32_tests.py"


def main() -> None:
    import subprocess
    import sys

    xml = subprocess.check_output([sys.executable, str(GEN)], text=True)
    # Drop legacy testcase blocks (empty arith or prior generated suites).
    import re

    text = DIG.read_text(encoding="utf-8")
    text = re.sub(
        r'    <visualElement>\n      <elementName>Testcase</elementName>.*?</visualElement>\n',
        "",
        text,
        flags=re.S,
    )
    insert_at = text.index("  </visualElements>")
    text = text[:insert_at] + xml.rstrip() + "\n" + text[insert_at:]

    DIG.write_text(text, encoding="utf-8", newline="\n")
    print(f"Updated {DIG} ({DIG.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
