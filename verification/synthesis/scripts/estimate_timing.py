#!/usr/bin/env python3
"""Estimate critical-path delay (ns) from Sky130 liberty + Yosys LTP."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "reports"
LIB = ROOT / "pdk" / "sky130_fd_sc_hd__tt_025C_1v80.lib"
LOG = REPORTS / "synth.log"


def parse_liberty_typical_delay_ns(lib_text: str, cell_type: str) -> float | None:
    pat = rf"cell\s*\(\s*\"?{re.escape(cell_type)}\"?\s*\)"
    m = re.search(pat, lib_text)
    if not m:
        return None

    rest = lib_text[m.end():]
    end = re.search(r"\n\s*cell\s*\(", rest)
    block = rest[: end.start()] if end else rest[:80000]

    samples: list[float] = []
    for arc in re.finditer(r"cell_(rise|fall)\s*\([^)]*\)\s*\{", block):
        i = arc.end()
        brace = 1
        while i < len(block) and brace > 0:
            if block[i] == "{":
                brace += 1
            elif block[i] == "}":
                brace -= 1
            i += 1
        arc_body = block[arc.end(): i]
        for vals in re.findall(r"values\s*\(\s*\"([^\"]+)\"", arc_body):
            row = [
                float(x.strip())
                for x in vals.replace("\\\n", "").split(",")
                if x.strip()
            ]
            if row:
                samples.append(row[len(row) // 2])

    return max(samples) if samples else None


def extract_top_stat_block(text: str) -> str:
    m = re.search(
        r"^\s+512\s+[\d.E+-]+\s+cells\s*$.*?Chip area for top module '\\alu-32b-final'",
        text,
        re.MULTILINE | re.DOTALL,
    )
    return m.group(0) if m else text


def parse_synth_log(text: str) -> dict:
    info: dict = {}
    block = extract_top_stat_block(text)

    m = re.search(
        r"Chip area for top module '\\alu-32b-final': ([\d.]+)", text
    )
    info["chip_area_um2"] = float(m.group(1)) if m else None

    m = re.search(
        r"of which used for sequential elements: [\d.]+ \(([\d.]+)%\)",
        text[text.rfind("Chip area for top module") :],
    )
    info["sequential_area_pct"] = float(m.group(1)) if m else None

    cm = re.search(r"^\s+(\d+)\s+[\d.E+-]+\s+cells\s*$", block, re.MULTILINE)
    info["cell_count"] = int(cm.group(1)) if cm else None

    m = re.search(
        r"Longest topological path in alu-32b-final \(length=(\d+)\):",
        text,
    )
    info["ltp_depth"] = int(m.group(1)) if m else None

    path: list[str] = []
    if m:
        section = text[m.end() : m.end() + 600]
        for line in section.splitlines():
            pm = re.match(r"\s*\d+:\s*(.+)", line)
            if pm:
                path.append(pm.group(1).strip())
            elif path and line.strip().startswith("Warning"):
                break
    info["ltp_path"] = path

    hier_idx = text.rfind("=== design hierarchy ===")
    if hier_idx >= 0:
        hier_block = text[hier_idx : text.rfind("Chip area for top module")]
        for pat, key in [
            (r"^\s+(\d+)\s+-\s+wires\s*$", "wires"),
            (r"^\s+(\d+)\s+-\s+wire bits\s*$", "wire_bits"),
            (r"^\s+(\d+)\s+-\s+ports\s*$", "ports"),
            (r"^\s+(\d+)\s+-\s+port bits\s*$", "port_bits"),
        ]:
            m = re.search(pat, hier_block, re.MULTILINE)
            if m:
                info[key] = int(m.group(1))

    return info


def estimate_carry_chain_delay_ns(lib_text: str, ltp_depth: int) -> float | None:
    maj3 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__maj3_1")
    mux2 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__mux2_1")
    xnor2 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__xnor2_1")
    if not maj3 or not mux2:
        return None

    per_slice = maj3 + mux2 + (xnor2 or mux2)
    lut_mux = (
        parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__mux4_2") or mux2
    )
    if ltp_depth and ltp_depth > 0:
        return lut_mux + ltp_depth * per_slice
    return per_slice


def main() -> int:
    if not LOG.exists():
        print(f"error: {LOG} not found", file=sys.stderr)
        return 1
    if not LIB.exists():
        print(f"error: {LIB} not found — run scripts/fetch_lib.ps1", file=sys.stderr)
        return 1

    log_text = LOG.read_text(encoding="utf-8", errors="replace")
    lib_text = LIB.read_text(encoding="utf-8", errors="replace")
    info = parse_synth_log(log_text)

    delay_ns = estimate_carry_chain_delay_ns(
        lib_text, info.get("ltp_depth") or 0
    )

    dff_delay = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__dfxtp_1")
    reg_overhead_ns = (dff_delay or 0.15) * 2

    comb_fmax = (1000.0 / delay_ns) if delay_ns and delay_ns > 0 else None
    reg_cycle_ns = (delay_ns + reg_overhead_ns) if delay_ns else None
    reg_fmax = (1000.0 / reg_cycle_ns) if reg_cycle_ns and reg_cycle_ns > 0 else None

    lines = [
        f"critical_path_delay_ns_comb: {delay_ns:.3f}" if delay_ns else "critical_path_delay_ns_comb: n/a",
        f"fmax_mhz_comb: {comb_fmax:.1f}" if comb_fmax else "fmax_mhz_comb: n/a",
        f"reg_overhead_ns: {reg_overhead_ns:.3f}",
        f"critical_path_delay_ns_registered: {reg_cycle_ns:.3f}" if reg_cycle_ns else "critical_path_delay_ns_registered: n/a",
        f"fmax_mhz_registered: {reg_fmax:.1f}" if reg_fmax else "fmax_mhz_registered: n/a",
        f"chip_area_um2: {info.get('chip_area_um2', 'n/a')}",
        f"sequential_area_pct: {info.get('sequential_area_pct', 'n/a')}",
        f"cell_count: {info.get('cell_count', 'n/a')}",
        f"wires: {info.get('wires', 'n/a')}",
        f"wire_bits: {info.get('wire_bits', 'n/a')}",
        f"ports: {info.get('ports', 'n/a')}",
        f"port_bits: {info.get('port_bits', 'n/a')}",
        f"ltp_depth: {info.get('ltp_depth', 'n/a')}",
        f"ltp_path: {' -> '.join(info.get('ltp_path', []))}",
    ]

    out_path = REPORTS / "timing_est.txt"
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out_path.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
