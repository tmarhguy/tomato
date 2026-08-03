#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f pdk/sky130_fd_sc_hd__tt_025C_1v80.lib ]; then
    echo "Liberty file missing. Run scripts/fetch_lib.sh"
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

echo "=== Yosys synthesis: rtl/alu-32b-final.v ==="
yosys scripts/synth.ys > reports/synth.log 2>&1

echo "=== Extract metrics ==="
python3 scripts/extract_metrics.py

echo "Done. See reports/metrics.txt"
