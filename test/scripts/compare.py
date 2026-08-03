#!/usr/bin/env python3
"""Three-way comparison: ripple ALU vs KS adder-only vs dual-LUT ALU + Kogge-Stone."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALU_METRICS = ROOT.parent / "verification" / "synthesis" / "reports" / "metrics.txt"
KS_METRICS = ROOT / "reports" / "metrics.txt"
ALU_KS_METRICS = ROOT / "reports" / "alu_ks_metrics.txt"
OUT = ROOT / "reports" / "comparison.txt"


def parse_metrics(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or ":" not in line:
            continue
        k, v = line.split(":", 1)
        data[k.strip()] = v.strip()
    return data


def fnum(s: str) -> float | None:
    try:
        return float(s)
    except (ValueError, TypeError):
        return None


def ratio_note(key: str, ripple: float, other: float, other_name: str) -> str:
    if ripple <= 0 or other <= 0:
        return ""
    if key == "chip_area_um2":
        return f"  ({other_name} is {other/ripple:.2f}x area of ripple ALU)"
    if key == "cell_count":
        return f"  ({other_name} is {other/ripple:.2f}x cells of ripple ALU)"
    if key.startswith("fmax"):
        return f"  ({other_name} is {other/ripple:.2f}x faster than ripple ALU)"
    if "delay" in key:
        return f"  ({other_name} is {ripple/other:.2f}x faster than ripple ALU)"
    return ""


def main() -> int:
    ripple = parse_metrics(ALU_METRICS)
    ks = parse_metrics(KS_METRICS)
    alu_ks = parse_metrics(ALU_KS_METRICS)

    if not ripple:
        print(f"warning: missing {ALU_METRICS} — run verification/synthesis/run.bat first")
    if not ks:
        print(f"warning: missing {KS_METRICS} — run test/run.bat (KS adder step)")
    if not alu_ks:
        print(f"warning: missing {ALU_KS_METRICS} — run test/run.bat (ALU+KS step)")

    def row(key: str, label: str) -> str:
        r = ripple.get(key, "n/a")
        k = ks.get(key, "n/a")
        a = alu_ks.get(key, "n/a")
        notes = []
        fr, fk, fa = fnum(r), fnum(k), fnum(a)
        if fr and fk:
            notes.append(ratio_note(key, fr, fk, "KS adder"))
        if fr and fa:
            notes.append(ratio_note(key, fr, fa, "ALU+KS"))
        note_str = "".join(notes)
        return f"{label:28} | Ripple ALU: {r:>10} | KS adder: {k:>10} | ALU+KS: {a:>10}{note_str}"

    lines = [
        "# Sky130 HD — Tomato ALU variants vs Kogge-Stone adder-only benchmark",
        "",
        row("chip_area_um2", "Chip area (um^2)"),
        row("cell_count", "Cell count"),
        row("sequential_area_pct", "Sequential area %"),
        row("ltp_depth", "LTP depth"),
        row("critical_path_delay_ns_comb", "Comb delay (ns)"),
        row("fmax_mhz_comb", "Fmax comb (MHz)"),
        row("critical_path_delay_ns_registered", "Reg cycle (ns)"),
        row("fmax_mhz_registered", "Fmax reg (MHz)"),
        "",
        "Ripple ALU: dual-LUT + ripple 4b/8b carry (verification/synthesis/alu-32b-final.v)",
        "KS adder:  Kogge-Stone 32b prefix add only (test/rtl/kogge_stone_32.v)",
        "ALU+KS:    same dual-LUT planes + Kogge-Stone 32b sum (test/rtl/alu-32b-koggestone.v)",
        "",
        "Awareness: the programmable datapath (mux3 LUT per plane) is the same; replacing ripple",
        "carry with Kogge-Stone closes most of the speed gap vs a hardened adder while keeping LUT",
        "flexibility. Production Tomato uses ripple for simpler physical design and flag integration.",
        "",
        "Timing: pre-route liberty arc estimates on Yosys LTP — same methodology as synthesis README",
    ]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
