#!/usr/bin/env python3
"""Estimate critical-path delay from Sky130 liberty + Yosys LTP (Kogge-Stone benchmark)."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "reports"
LIB = ROOT.parent / "verification" / "synthesis" / "pdk" / "sky130_fd_sc_hd__tt_025C_1v80.lib"
LOG = REPORTS / "synth.log"
TOP = "kogge_stone_32"


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
            row = [float(x.strip()) for x in vals.replace("\\\n", "").split(",") if x.strip()]
            if row:
                samples.append(row[len(row) // 2])
    return max(samples) if samples else None


def parse_synth_log(text: str) -> dict:
    info: dict = {}
    m = re.search(
        rf"Chip area for (?:top )?module '\\?{TOP}': ([\d.]+)", text
    )
    info["chip_area_um2"] = float(m.group(1)) if m else None

    m = re.search(r"of which used for sequential elements: [\d.]+ \(([\d.]+)%\)", text)
    info["sequential_area_pct"] = float(m.group(1)) if m else 0.0

    m = re.search(rf"Longest topological path in {TOP} \(length=(\d+)\):", text)
    info["ltp_depth"] = int(m.group(1)) if m else None

    path: list[str] = []
    if m:
        for line in text[m.end() : m.end() + 800].splitlines():
            pm = re.match(r"\s*\d+:\s*(.+)", line)
            if pm:
                path.append(pm.group(1).strip())
            elif path and not line.strip().startswith("Warning"):
                break
    info["ltp_path"] = path

    idx = text.rfind(f"Chip area for module '\\{TOP}'")
    if idx < 0:
        idx = text.rfind(f"Chip area for top module '\\{TOP}'")
    if idx >= 0:
        chunk = text[max(0, idx - 2500) : idx]
        cm = re.search(r"^\s+(\d+)\s+[\d.E+-]+\s+cells\s*$", chunk, re.MULTILINE)
        if cm:
            info["cell_count"] = int(cm.group(1))

    hier_idx = text.rfind("=== design hierarchy ===")
    if hier_idx >= 0:
        hier_block = text[hier_idx : text.rfind("Chip area for")]
        for pat, key in [
            (r"^\s+(\d+)\s+-\s+wires\s*$", "wires"),
            (r"^\s+(\d+)\s+-\s+wire bits\s*$", "wire_bits"),
            (r"^\s+(\d+)\s+-\s+ports\s*$", "ports"),
            (r"^\s+(\d+)\s+-\s+port bits\s*$", "port_bits"),
        ]:
            mm = re.search(pat, hier_block, re.MULTILINE)
            if mm:
                info[key] = int(mm.group(1))

    return info


def estimate_prefix_delay_ns(lib_text: str, ltp_depth: int) -> float | None:
    """Kogge-Stone: ~log2(N) prefix levels of and + or (+ xor at sum)."""
    and2 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__and2_1")
    or2 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__or2_1")
    xor2 = parse_liberty_typical_delay_ns(lib_text, "sky130_fd_sc_hd__xor2_1")
    if not and2 or not or2:
        return None
    per_level = and2 + or2
    depth = ltp_depth if ltp_depth and ltp_depth > 0 else 5
    return depth * per_level + (xor2 or and2)


def main() -> int:
    if not LOG.exists():
        print(f"error: {LOG} not found", file=sys.stderr)
        return 1
    if not LIB.exists():
        print(f"error: {LIB} not found", file=sys.stderr)
        return 1

    log_text = LOG.read_text(encoding="utf-8", errors="replace")
    lib_text = LIB.read_text(encoding="utf-8", errors="replace")
    info = parse_synth_log(log_text)

    delay_ns = estimate_prefix_delay_ns(lib_text, info.get("ltp_depth") or 0)
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
