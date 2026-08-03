#!/usr/bin/env python3
"""Parse Yosys synth.log and write reports/metrics.txt."""

import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "reports"
LOG = REPORTS / "synth.log"
OUT = REPORTS / "metrics.txt"
LIB = "sky130_fd_sc_hd__tt_025C_1v80"
NETLIST = "rtl/alu-32b-final.v"
TOP = "alu-32b-final"


def parse_timing_est() -> dict[str, str]:
    est_path = REPORTS / "timing_est.txt"
    if not est_path.exists():
        return {}
    data: dict[str, str] = {}
    for line in est_path.read_text(encoding="utf-8").splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip()
    return data


def cell_breakdown_from_log(text: str) -> list[str]:
    block_m = re.search(
        r"^\s+512\s+[\d.E+-]+\s+cells\s*$.*?Chip area for top module '\\alu-32b-final'",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not block_m:
        return []
    lines: list[str] = []
    for line in block_m.group(0).splitlines():
        cm = re.match(r"\s+(\d+)\s+([\d.E+-]+)\s+(sky130_fd_sc_hd__\S+)", line)
        if cm:
            lines.append(f"  {cm.group(3)}: {cm.group(1)} ({cm.group(2)} um^2)")
    return lines


def main() -> int:
    if not LOG.exists():
        print(f"error: {LOG} not found — run synthesis first", file=sys.stderr)
        return 1

    subprocess.run(
        [sys.executable, str(Path(__file__).resolve().parent / "estimate_timing.py")],
        check=False,
    )
    timing = parse_timing_est()

    text = LOG.read_text(encoding="utf-8", errors="replace")

    yosys_ver = ""
    m = re.search(r"Yosys (0\.\d+[^\n|]*)", text)
    if m:
        yosys_ver = m.group(1).strip()

    cell_lines = cell_breakdown_from_log(text)

    lines = [
        f"# ALU synthesis metrics — {date.today().isoformat()}",
        f"netlist: {NETLIST}",
        f"top: {TOP}",
        f"pdk: SkyWater 130nm HD ({LIB})",
        f"corner: TT 25C 1.8V",
        f"yosys: {yosys_ver or 'unknown'}",
        "",
        "## Area",
        f"chip_area_um2: {timing.get('chip_area_um2', 'n/a')}",
        f"sequential_area_pct: {timing.get('sequential_area_pct', 'n/a')}",
        "",
        "## Cells",
        f"cell_count: {timing.get('cell_count', 'n/a')}",
    ]
    if cell_lines:
        lines.append("cell_breakdown:")
        lines.extend(cell_lines[:15])
    lines.extend(
        [
            "",
            "## Connectivity",
            f"wires: {timing.get('wires', 'n/a')}",
            f"wire_bits: {timing.get('wire_bits', 'n/a')}",
            f"ports: {timing.get('ports', 'n/a')}",
            f"port_bits: {timing.get('port_bits', 'n/a')}",
            "",
            "## Critical path (LTP)",
            f"ltp_depth: {timing.get('ltp_depth', 'n/a')}",
            f"ltp_path: {timing.get('ltp_path', 'n/a')}",
            "",
            "## Timing (liberty arc estimate on LTP carry chain)",
            f"critical_path_delay_ns_comb: {timing.get('critical_path_delay_ns_comb', 'n/a')}",
            f"fmax_mhz_comb: {timing.get('fmax_mhz_comb', 'n/a')}",
            f"reg_overhead_ns: {timing.get('reg_overhead_ns', 'n/a')}",
            f"critical_path_delay_ns_registered: {timing.get('critical_path_delay_ns_registered', 'n/a')}",
            f"fmax_mhz_registered: {timing.get('fmax_mhz_registered', 'n/a')}",
        ]
    )

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
