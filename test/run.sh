#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

LIB="../verification/synthesis/pdk/sky130_fd_sc_hd__tt_025C_1v80.lib"
if [ ! -f "$LIB" ]; then
    echo "Liberty missing. Run verification/synthesis/scripts/fetch_lib.sh first."
    exit 1
fi

if [ -f /opt/oss-cad-suite/environment.sh ]; then
    # shellcheck source=/dev/null
    source /opt/oss-cad-suite/environment.sh
elif [ -n "${OSS_CAD_SUITE_ROOT:-}" ] && [ -f "$OSS_CAD_SUITE_ROOT/environment.sh" ]; then
    # shellcheck source=/dev/null
    source "$OSS_CAD_SUITE_ROOT/environment.sh"
fi

mkdir -p reports

echo "=== Yosys synthesis: kogge_stone_32 (benchmark) ==="
yosys scripts/synth.ys > reports/synth.log 2>&1

echo "=== Extract metrics ==="
python3 scripts/extract_metrics.py

echo "=== Yosys synthesis: alu_32b_kogge_stone (dual-LUT + KS carry) ==="
yosys scripts/synth_alu_ks.ys > reports/alu_ks_synth.log 2>&1

echo "=== Extract ALU+KS metrics ==="
python3 scripts/extract_metrics_alu_ks.py

echo "=== Compare all three designs ==="
python3 scripts/compare.py

echo "Done. See reports/metrics.txt, reports/alu_ks_metrics.txt, reports/comparison.txt"
